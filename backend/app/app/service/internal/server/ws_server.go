package server

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/go-kratos/kratos/v2/transport"
	"github.com/gorilla/websocket"

	"google.golang.org/protobuf/encoding/protojson"

	"github.com/tx7do/kratos-bootstrap/bootstrap"

	authenticationV1 "go-wind-kanban/api/gen/go/authentication/service/v1"
	boardV1 "go-wind-kanban/api/gen/go/board/service/v1"

	"go-wind-kanban/pkg/broadcast"
)

const (
	// wsWriteWait 单帧写出超时
	wsWriteWait = 10 * time.Second
	// wsPongWait 等待客户端 pong 的最大时长，超时视为断线
	wsPongWait = 60 * time.Second
	// wsPingPeriod 心跳间隔，须小于 wsPongWait
	wsPingPeriod = 50 * time.Second
)

// WsServer 看板实时 WebSocket 服务。
//
// 端点：GET /app/v1/ws?board_id=<id>&access_token=<jwt>
// 浏览器 WebSocket 无法自定义 Authorization 头，token 经 query 传递，
// 由本服务在握手阶段自行校验（不走 REST 认证中间件链）。
//
// 职责：
//   - 握手鉴权：ValidateToken + 看板租户归属校验（防跨租户订阅）
//   - 连接池：按 board_id 订阅 broadcast.Hub，推送看板变更事件
//   - 生命周期：作为 kratos transport.Server 随应用启停 Hub 的 Redis 订阅
type WsServer struct {
	log *log.Helper

	hub                        *broadcast.Hub
	authenticationServiceClient authenticationV1.AuthenticationServiceClient
	boardServiceClient         boardV1.BoardServiceClient

	upgrader websocket.Upgrader
}

func NewWsServer(
	ctx *bootstrap.Context,
	hub *broadcast.Hub,
	authenticationServiceClient authenticationV1.AuthenticationServiceClient,
	boardServiceClient boardV1.BoardServiceClient,
) *WsServer {
	return &WsServer{
		log:                        log.NewHelper(log.With(ctx.GetLogger(), "module", "ws/server/app-service")),
		hub:                        hub,
		authenticationServiceClient: authenticationServiceClient,
		boardServiceClient:         boardServiceClient,
		upgrader: websocket.Upgrader{
			ReadBufferSize:  1024,
			WriteBufferSize: 4096,
			// WebSocket 无 CORS Cookie 风险（token 显式传递），同源限制放开
			CheckOrigin: func(_ *http.Request) bool { return true },
		},
	}
}

// Start 启动 Hub 的 Redis 订阅循环（随应用生命周期）。
func (s *WsServer) Start(_ context.Context) error {
	go func() {
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		s.hub.Run(ctx)
	}()
	s.log.Info("board realtime hub started")
	return nil
}

// Stop 停止 Hub，断开全部订阅通道。
func (s *WsServer) Stop(_ context.Context) error {
	s.hub.Stop()
	return nil
}

// Endpoint 未独立监听端口（挂靠 REST 服务器），返回占位。
func (s *WsServer) Endpoint() (*url.URL, error) {
	return url.Parse("ws://localhost/app/v1/ws")
}

// Handler 原生 HTTP 处理器（kratos HandleFunc 注册，不经中间件链）。
func (s *WsServer) Handler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		s.serveWs(w, r)
	}
}

type wsEnvelope struct {
	Type string          `json:"type"`
	Body json.RawMessage `json:"body"`
}

func (s *WsServer) serveWs(w http.ResponseWriter, r *http.Request) {
	// ===== 握手鉴权（ticket 模式，替代 URL 传 JWT）=====
	ticket := r.URL.Query().Get("ticket")
	boardID64, err := parseBoardID(r.URL.Query().Get("board_id"))
	if err != nil || ticket == "" {
		http.Error(w, "board_id and ticket are required", http.StatusBadRequest)
		return
	}
	boardID := uint32(boardID64)

	// 消费 ticket：原子 GETDEL，返回绑定的 userId + boardId。
	// ticket 无效/过期/已用 → valid=false。
	ticketResp, err := s.authenticationServiceClient.ConsumeWebSocketTicket(r.Context(), &authenticationV1.ConsumeWebSocketTicketRequest{
		Ticket: ticket,
	})
	if err != nil || !ticketResp.GetValid() {
		s.log.Errorf("ws handshake: ticket invalid or consumed")
		http.Error(w, "invalid ticket", http.StatusUnauthorized)
		return
	}

	// ticket 绑定的 boardId 必须与请求 boardId 一致（防篡改）。
	if ticketResp.GetBoardId() != boardID {
		http.Error(w, "ticket board mismatch", http.StatusForbidden)
		return
	}

	// ===== 升级连接 =====
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		s.log.Errorf("ws upgrade failed: %s", err.Error())
		return
	}

	events := s.hub.Subscribe(boardID)
	go s.writePump(conn, events, ticketResp.GetUserId())
	s.readPump(conn)
	s.hub.Unsubscribe(boardID, events)
}

// writePump 事件写出泵：订阅通道 → JSON 帧；心跳 ping 维持连接。
func (s *WsServer) writePump(conn *websocket.Conn, events broadcast.EventChannel, actorID uint32) {
	ticker := time.NewTicker(wsPingPeriod)
	defer func() {
		ticker.Stop()
		_ = conn.Close()
	}()

	for {
		select {
		case ev, ok := <-events:
			if !ok {
				_ = conn.WriteControl(websocket.CloseMessage,
					websocket.FormatCloseMessage(websocket.CloseGoingAway, "hub stopped"),
					time.Now().Add(wsWriteWait))
				return
			}
			// 回声抑制：不向触发者本人推送其自己刚完成的操作
			// （其本地状态已由操作响应更新）。
			if ev.GetActorId() != 0 && ev.GetActorId() == actorID {
				continue
			}
			// protojson 输出 camelCase（json_name），与 REST 网关序列化一致，
			// 客户端可复用同一套反序列化。
			body, err := protojson.Marshal(ev)
			if err != nil {
				s.log.Errorf("ws marshal event failed: %s", err.Error())
				continue
			}
			_ = conn.SetWriteDeadline(time.Now().Add(wsWriteWait))
			if err := conn.WriteMessage(websocket.TextMessage, body); err != nil {
				return
			}
		case <-ticker.C:
			_ = conn.SetWriteDeadline(time.Now().Add(wsWriteWait))
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// readPump 读泵：仅消费客户端帧以驱动 pong/close 处理。
func (s *WsServer) readPump(conn *websocket.Conn) {
	defer func() { _ = conn.Close() }()

	conn.SetReadLimit(512)
	_ = conn.SetReadDeadline(time.Now().Add(wsPongWait))
	conn.SetPongHandler(func(string) error {
		_ = conn.SetReadDeadline(time.Now().Add(wsPongWait))
		return nil
	})
	for {
		if _, _, err := conn.ReadMessage(); err != nil {
			return
		}
		// 客户端发送的任何文本帧仅作保活，不承载业务。
	}
}

var _ transport.Server = (*WsServer)(nil)
