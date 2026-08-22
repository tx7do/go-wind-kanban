// Package broadcast 提供看板实时变更事件的发布/订阅基础设施。
//
// 架构：本地 Hub（进程内按 board_id 分发）+ Redis Pub/Sub（跨实例总线）。
//
//	app-service   : Hub 全功能 —— WebSocket 连接池订阅本地通道，
//	                写操作成功后 Publish（本地分发 + Redis 发布）。
//	admin-service : 仅 Publisher —— 写操作成功后经 Redis 发布，
//	                由 app 实例的 Hub 接收并推送给其在线客户端。
//
// 事件体为 board.service.v1.BoardChangeEvent 的 JSON 序列。
// 可靠性：本通道是尽力而为的实时推送；离线/丢包客户端的最终一致性
// 由快照拉取与后续差量同步保证，不依赖本通道。
package broadcast

import (
	"context"
	"sync"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/redis/go-redis/v9"

	"google.golang.org/protobuf/encoding/protojson"

	boardV1 "go-wind-kanban/api/gen/go/board/service/v1"
)

// DefaultChannel Redis 总线频道名（单频道、按事件内 board_id 路由）。
const DefaultChannel = "go-wind:board:events"

// EventChannel 订阅通道。约定：消费者只读（Hub 负责关闭与发送），
// 调用方不得向其写入；类型保留双向仅为作为 map 键传递。
type EventChannel chan *boardV1.BoardChangeEvent

// Hub 看板事件总线：本地按 board_id 分发 + Redis 跨实例广播。
type Hub struct {
	log     *log.Helper
	rdb     *redis.Client
	channel string

	mu     sync.RWMutex
	local  map[uint32]map[chan *boardV1.BoardChangeEvent]struct{}
	wake   chan struct{} // 惰性启动 Redis 订阅
	cancel context.CancelFunc
	once   sync.Once
}

// NewHub 创建事件总线。rdb 为 nil 时退化为纯进程内分发（单实例部署/测试）。
func NewHub(rdb *redis.Client, logger log.Logger) *Hub {
	return &Hub{
		log:    log.NewHelper(log.With(logger, "module", "board/broadcast")),
		rdb:    rdb,
		local:  make(map[uint32]map[chan *boardV1.BoardChangeEvent]struct{}),
		wake:   make(chan struct{}, 1),
	}
}

// Run 启动 Redis 订阅循环（存在 rdb 时）；阻塞直至 ctx 取消。
// 首个 Subscribe 后惰性启动亦可，显式 Run 便于生命周期管理。
func (h *Hub) Run(ctx context.Context) {
	if h.rdb == nil {
		<-ctx.Done()
		return
	}

	ctx, h.cancel = context.WithCancel(ctx)

	sub := h.rdb.Subscribe(ctx, h.channelName())
	go func() {
		<-ctx.Done()
		_ = sub.Close()
	}()

	ch := sub.Channel()
	for {
		select {
		case <-ctx.Done():
			h.closeAll()
			return
		case msg, ok := <-ch:
			if !ok {
				return
			}
			ev := &boardV1.BoardChangeEvent{}
			if err := protojson.Unmarshal([]byte(msg.Payload), ev); err != nil {
				h.log.Errorf("broadcast: unmarshal event failed: %s", err.Error())
				continue
			}
			h.dispatch(ev)
		}
	}
}

// Stop 终止总线并关闭全部本地订阅通道。
func (h *Hub) Stop() {
	h.once.Do(func() {
		if h.cancel != nil {
			h.cancel()
		}
		h.closeAll()
	})
}

// Publish 发布事件：本地分发 + Redis 广播（供其它实例的 Hub 消费）。
// 事件缺 board_id 视为协议错误，记日志丢弃。
func (h *Hub) Publish(ctx context.Context, ev *boardV1.BoardChangeEvent) {
	if ev == nil || ev.GetBoardId() == 0 {
		h.log.Warnf("broadcast: drop event without board_id (type=%v)", ev.GetType())
		return
	}

	// 本实例订阅者即时分发。
	h.dispatch(ev)

	if h.rdb == nil {
		return
	}

	body, err := protojson.Marshal(ev)
	if err != nil {
		h.log.Errorf("broadcast: marshal event failed: %s", err.Error())
		return
	}
	if err := h.rdb.Publish(ctx, h.channelName(), string(body)).Err(); err != nil {
		// Redis 抖动只影响跨实例实时性，本地分发已完成，不阻断业务。
		h.log.Errorf("broadcast: redis publish failed: %s", err.Error())
	}
}

// Subscribe 订阅指定看板的变更流；返回的通道有缓冲，消费过慢时
// 丢弃最旧事件（实时通道尽力而为，最终一致性靠同步机制）。
func (h *Hub) Subscribe(boardID uint32) EventChannel {
	ch := make(chan *boardV1.BoardChangeEvent, 64)

	h.mu.Lock()
	set, ok := h.local[boardID]
	if !ok {
		set = make(map[chan *boardV1.BoardChangeEvent]struct{})
		h.local[boardID] = set
	}
	set[ch] = struct{}{}
	h.mu.Unlock()

	// 惰性唤醒（若 Run 未显式调用，首个订阅触发一次；无消费者则静默）。
	select {
	case h.wake <- struct{}{}:
	default:
	}

	return ch
}

// Unsubscribe 退订并关闭对应通道。
func (h *Hub) Unsubscribe(boardID uint32, ch EventChannel) {
	h.mu.Lock()
	defer h.mu.Unlock()

	set, ok := h.local[boardID]
	if !ok {
		return
	}
	if _, exists := set[ch]; !exists {
		return
	}
	delete(set, ch)
	if len(set) == 0 {
		delete(h.local, boardID)
	}
	close(ch)
}

// dispatch 向本地订阅者分发；慢消费者丢最旧事件。
func (h *Hub) dispatch(ev *boardV1.BoardChangeEvent) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	set, ok := h.local[ev.GetBoardId()]
	if !ok {
		return
	}
	for ch := range set {
		select {
		case ch <- ev:
		default:
			select {
			case <-ch: // 丢弃最旧
			default:
			}
			select {
			case ch <- ev:
			default:
			}
		}
	}
}

func (h *Hub) closeAll() {
	h.mu.Lock()
	defer h.mu.Unlock()

	for boardID, set := range h.local {
		for ch := range set {
			close(ch)
			delete(set, ch)
		}
		delete(h.local, boardID)
	}
}

func (h *Hub) channelName() string {
	if h.channel != "" {
		return h.channel
	}
	return DefaultChannel
}
