package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/go-utils/trans"

	appV1 "go-wind-cms/api/gen/go/app/service/v1"
	boardV1 "go-wind-cms/api/gen/go/board/service/v1"

	"go-wind-cms/pkg/middleware/auth"
)

type CardService struct {
	appV1.CardServiceHTTPServer

	log *log.Helper

	cardServiceClient boardV1.CardServiceClient
}

func NewCardService(
	ctx *bootstrap.Context,
	cardServiceClient boardV1.CardServiceClient,
) *CardService {
	l := log.NewHelper(log.With(ctx.GetLogger(), "module", "card/service/app-service"))
	return &CardService{
		log:               l,
		cardServiceClient: cardServiceClient,
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
		return nil, appV1.ErrorBadRequest("invalid parameter")
	}

	// 获取操作人信息
	operator, err := auth.FromContext(ctx)
	if err != nil {
		return nil, err
	}

	req.Data.CreatedBy = trans.Ptr(operator.UserId)

	return s.cardServiceClient.Create(ctx, req)
}

func (s *CardService) Update(ctx context.Context, req *boardV1.UpdateCardRequest) (*boardV1.Card, error) {
	if req == nil || req.Data == nil {
		return nil, appV1.ErrorBadRequest("invalid parameter")
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

	return s.cardServiceClient.Update(ctx, req)
}

func (s *CardService) Delete(ctx context.Context, req *boardV1.DeleteCardRequest) (*emptypb.Empty, error) {
	return s.cardServiceClient.Delete(ctx, req)
}

// Move 移动卡片（同列重排/跨列移动，Flutter 拖拽事件的服务端入口）
func (s *CardService) Move(ctx context.Context, req *boardV1.MoveCardRequest) (*boardV1.Card, error) {
	return s.cardServiceClient.Move(ctx, req)
}
