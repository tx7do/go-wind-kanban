package service

import (
	"context"

	"github.com/tx7do/go-utils/trans"
	"google.golang.org/protobuf/types/known/timestamppb"

	boardV1 "go-wind-cms/api/gen/go/board/service/v1"

	"go-wind-cms/pkg/broadcast"
	"go-wind-cms/pkg/middleware/auth"
)

// publishBoardEntity 发布看板实体变更事件（board 自身的增改移）。
func publishBoardEntity(ctx context.Context, hub *broadcast.Hub, typ boardV1.BoardChangeEvent_Type, b *boardV1.Board) {
	if hub == nil || b == nil {
		return
	}
	publishEvent(ctx, hub, &boardV1.BoardChangeEvent{
		Type:       typ.Enum(),
		BoardId:    trans.Ptr(b.GetId()),
		OccurredAt: timestamppb.Now(),
		Payload:    &boardV1.BoardChangeEvent_Board{Board: b},
	})
}

// publishColumnEntity 发布列实体变更事件（board_id 取自列的归属）。
func publishColumnEntity(ctx context.Context, hub *broadcast.Hub, typ boardV1.BoardChangeEvent_Type, c *boardV1.Column) {
	if hub == nil || c == nil {
		return
	}
	publishEvent(ctx, hub, &boardV1.BoardChangeEvent{
		Type:       typ.Enum(),
		BoardId:    trans.Ptr(c.GetBoardId()),
		OccurredAt: timestamppb.Now(),
		Payload:    &boardV1.BoardChangeEvent_Column{Column: c},
	})
}

// publishCardEntity 发布卡片实体变更事件（board_id 取自卡片的冗余归属）。
func publishCardEntity(ctx context.Context, hub *broadcast.Hub, typ boardV1.BoardChangeEvent_Type, c *boardV1.Card) {
	if hub == nil || c == nil {
		return
	}
	publishEvent(ctx, hub, &boardV1.BoardChangeEvent{
		Type:       typ.Enum(),
		BoardId:    trans.Ptr(c.GetBoardId()),
		OccurredAt: timestamppb.Now(),
		Payload:    &boardV1.BoardChangeEvent_Card{Card: c},
	})
}

// publishBoardDeleted 发布删除事件（仅携带 id 的占位实体）。
func publishBoardDeleted(ctx context.Context, hub *broadcast.Hub, boardID uint32) {
	if hub == nil {
		return
	}
	publishEvent(ctx, hub, &boardV1.BoardChangeEvent{
		Type:       boardV1.BoardChangeEvent_BOARD_DELETED.Enum(),
		BoardId:    trans.Ptr(boardID),
		OccurredAt: timestamppb.Now(),
		Payload:    &boardV1.BoardChangeEvent_Board{Board: &boardV1.Board{Id: trans.Ptr(boardID)}},
	})
}

func publishColumnDeleted(ctx context.Context, hub *broadcast.Hub, boardID, columnID uint32) {
	if hub == nil {
		return
	}
	publishEvent(ctx, hub, &boardV1.BoardChangeEvent{
		Type:       boardV1.BoardChangeEvent_COLUMN_DELETED.Enum(),
		BoardId:    trans.Ptr(boardID),
		OccurredAt: timestamppb.Now(),
		Payload: &boardV1.BoardChangeEvent_Column{Column: &boardV1.Column{
			Id:      trans.Ptr(columnID),
			BoardId: trans.Ptr(boardID),
		}},
	})
}

func publishCardDeleted(ctx context.Context, hub *broadcast.Hub, boardID, cardID uint32) {
	if hub == nil {
		return
	}
	publishEvent(ctx, hub, &boardV1.BoardChangeEvent{
		Type:       boardV1.BoardChangeEvent_CARD_DELETED.Enum(),
		BoardId:    trans.Ptr(boardID),
		OccurredAt: timestamppb.Now(),
		Payload: &boardV1.BoardChangeEvent_Card{Card: &boardV1.Card{
			Id:      trans.Ptr(cardID),
			BoardId: trans.Ptr(boardID),
		}},
	})
}

// publishEvent 统一补齐 actor 并发布；hub 为 nil 或发布失败均不影响业务返回。
func publishEvent(ctx context.Context, hub *broadcast.Hub, ev *boardV1.BoardChangeEvent) {
	if operator, err := auth.FromContext(ctx); err == nil {
		ev.ActorId = trans.Ptr(operator.GetUserId())
	}
	hub.Publish(ctx, ev)
}
