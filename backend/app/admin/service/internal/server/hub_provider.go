package server

import (
	"github.com/redis/go-redis/v9"

	"github.com/tx7do/kratos-bootstrap/bootstrap"

	"go-wind-cms/pkg/broadcast"
)

// NewBoardEventHub 创建看板实时事件总线。
// admin 侧仅用 Publish（经 Redis 跨实例广播给 app 客户端），不运行订阅循环。
func NewBoardEventHub(ctx *bootstrap.Context, rdb *redis.Client) *broadcast.Hub {
	return broadcast.NewHub(rdb, ctx.GetLogger())
}
