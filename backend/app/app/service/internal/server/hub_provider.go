package server

import (
	"github.com/redis/go-redis/v9"

	"github.com/tx7do/kratos-bootstrap/bootstrap"

	"go-wind-kanban/pkg/broadcast"
)

// NewBoardEventHub 创建看板实时事件总线。
// Redis 客户端来自 data 层（跨实例广播）；WsServer.Start 负责运行订阅循环。
func NewBoardEventHub(ctx *bootstrap.Context, rdb *redis.Client) *broadcast.Hub {
	return broadcast.NewHub(rdb, ctx.GetLogger())
}
