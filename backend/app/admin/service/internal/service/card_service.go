package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/go-utils/trans"

	adminV1 "go-wind-cms/api/gen/go/admin/service/v1"
	boardV1 "go-wind-cms/api/gen/go/board/service/v1"

	"go-wind-cms/pkg/broadcast"
	"go-wind-cms/pkg/middleware/auth"
)

type CardService struct {
	adminV1.CardServiceHTTPServer

	log *log.Helper

	cardServiceClient boardV1.CardServiceClient
	hub             *broadcast.Hub
}

func NewCardService(
	ctx *bootstrap.Context,
	cardServiceClient boardV1.CardServiceClient,
	hub *broadcast.Hub,
) *CardService {
	l := log.NewHelper(log.With(ctx.GetLogger(), "module", "card/service/admin-service"))
	return &CardService{
		log:               l,
		cardServiceClient: cardServiceClient,
		hub:             hub,
	}
}

func (s *CardService) List(ctx context.Context, req *paginationV1.PagingRequest) (*boardV1.ListCardResponse, error) {
	return s.cardServiceClient.List(ctx, req)
}

func (s *CardService) Get(ctx context.Context, req *boardV1.GetCardRequest) (*boardV1.Card, error) {
	return s.cardServiceClient.Get(ctx, req)
}

func (s *CardService) Create(ctx context.Context, req *boardV1.CreateCardRequest) (*boardV1.Card, error) {
	if req == nil || req.Data == nil {
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}

	// 获取操作人信息
	operator, err := auth.FromContext(ctx)
	if err != nil {
		return nil, err
	}

	req.Data.CreatedBy = trans.Ptr(operator.UserId)

	resp, err := s.cardServiceClient.Create(ctx, req)
	if err == nil && resp != nil {
		publishCardEntity(ctx, s.hub, boardV1.BoardChangeEvent_CARD_CREATED, resp)
	}
	return resp, err
}

func (s *CardService) Update(ctx context.Context, req *boardV1.UpdateCardRequest) (*boardV1.Card, error) {
	if req == nil || req.Data == nil {
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}

	// 获取操作人信息
	operator, err := auth.FromContext(ctx)
	if err != nil {
		return nil, err
	}

	req.Data.Id = trans.Ptr(req.GetId())

	req.Data.UpdatedBy = trans.Ptr(operator.GetUserId())
	if req.UpdateMask != nil {
		req.UpdateMask.Paths = append(req.UpdateMask.Paths, "updated_by")
	}

	resp, err := s.cardServiceClient.Update(ctx, req)
	if err == nil && resp != nil {
		publishCardEntity(ctx, s.hub, boardV1.BoardChangeEvent_CARD_UPDATED, resp)
	}
	return resp, err
}

func (s *CardService) Delete(ctx context.Context, req *boardV1.DeleteCardRequest) (*emptypb.Empty, error) {
	c, _ := s.cardServiceClient.Get(ctx, &boardV1.GetCardRequest{
		QueryBy: &boardV1.GetCardRequest_Id{Id: req.GetId()},
	})
	resp, err := s.cardServiceClient.Delete(ctx, req)
	if err == nil {
		publishCardDeleted(ctx, s.hub, c.GetBoardId(), req.GetId())
	}
	return resp, err
}

// Move 移动卡片（同列重排/跨列移动）
func (s *CardService) Move(ctx context.Context, req *boardV1.MoveCardRequest) (*boardV1.Card, error) {
	resp, err := s.cardServiceClient.Move(ctx, req)
	if err == nil && resp != nil {
		publishCardEntity(ctx, s.hub, boardV1.BoardChangeEvent_CARD_MOVED, resp)
	}
	return resp, err
}
