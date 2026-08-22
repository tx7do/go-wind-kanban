package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	boardV1 "go-wind-cms/api/gen/go/board/service/v1"

	"go-wind-cms/app/core/service/internal/data"
)

// CardService 看板卡片服务
type CardService struct {
	boardV1.UnimplementedCardServiceServer

	log *log.Helper

	cardRepo *data.CardRepo
}

func NewCardService(
	ctx *bootstrap.Context,
	cardRepo *data.CardRepo,
) *CardService {
	svc := &CardService{
		log:      ctx.NewLoggerHelper("card/service/core-service"),
		cardRepo: cardRepo,
	}

	return svc
}

func (s *CardService) List(ctx context.Context, req *paginationV1.PagingRequest) (*boardV1.ListCardResponse, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	return s.cardRepo.List(ctx, req)
}

func (s *CardService) Get(ctx context.Context, req *boardV1.GetCardRequest) (*boardV1.Card, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	return s.cardRepo.Get(ctx, req)
}

func (s *CardService) Create(ctx context.Context, req *boardV1.CreateCardRequest) (*boardV1.Card, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	// 卡片标题与所属列必须由服务端校验，避免孤儿卡片或空标题卡片进入列
	if req.Data.GetName() == "" {
		return nil, boardV1.ErrorBadRequest("name is required")
	}
	if req.Data.GetColumnId() == 0 {
		return nil, boardV1.ErrorBadRequest("column_id is required")
	}

	return s.cardRepo.Create(ctx, req)
}

func (s *CardService) Update(ctx context.Context, req *boardV1.UpdateCardRequest) (*boardV1.Card, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	return s.cardRepo.Update(ctx, req)
}

func (s *CardService) Delete(ctx context.Context, req *boardV1.DeleteCardRequest) (*emptypb.Empty, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid request")
	}
	if err := s.cardRepo.Delete(ctx, req); err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

// Move 移动卡片（同列重排/跨列移动，Lexorank 排序，拖拽事件的服务端入口）
func (s *CardService) Move(ctx context.Context, req *boardV1.MoveCardRequest) (*boardV1.Card, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid request")
	}
	if req.GetId() == 0 {
		return nil, boardV1.ErrorBadRequest("id is required")
	}
	return s.cardRepo.Move(ctx, req)
}
