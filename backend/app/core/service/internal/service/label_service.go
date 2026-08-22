package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	boardV1 "go-wind-kanban/api/gen/go/board/service/v1"

	"go-wind-kanban/app/core/service/internal/data"
)

// LabelService 看板标签服务
type LabelService struct {
	boardV1.UnimplementedLabelServiceServer

	log *log.Helper

	labelRepo *data.LabelRepo
}

func NewLabelService(
	ctx *bootstrap.Context,
	labelRepo *data.LabelRepo,
) *LabelService {
	return &LabelService{
		log:       ctx.NewLoggerHelper("label/service/core-service"),
		labelRepo: labelRepo,
	}
}

func (s *LabelService) List(ctx context.Context, req *paginationV1.PagingRequest) (*boardV1.ListLabelResponse, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	return s.labelRepo.List(ctx, req)
}

func (s *LabelService) Get(ctx context.Context, req *boardV1.GetLabelRequest) (*boardV1.Label, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	return s.labelRepo.Get(ctx, req)
}

func (s *LabelService) Create(ctx context.Context, req *boardV1.CreateLabelRequest) (*boardV1.Label, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	if req.Data.GetName() == "" || req.Data.GetColor() == "" {
		return nil, boardV1.ErrorBadRequest("name and color are required")
	}
	if req.Data.GetBoardId() == 0 {
		return nil, boardV1.ErrorBadRequest("board_id is required")
	}
	return s.labelRepo.Create(ctx, req)
}

func (s *LabelService) Update(ctx context.Context, req *boardV1.UpdateLabelRequest) (*boardV1.Label, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	return s.labelRepo.Update(ctx, req)
}

func (s *LabelService) Delete(ctx context.Context, req *boardV1.DeleteLabelRequest) (*emptypb.Empty, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid request")
	}
	if err := s.labelRepo.Delete(ctx, req); err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

// SetCardLabels 全量替换卡片标签集合（差量增删）
func (s *LabelService) SetCardLabels(ctx context.Context, req *boardV1.SetCardLabelsRequest) (*emptypb.Empty, error) {
	if req == nil || req.GetCardId() == 0 {
		return nil, boardV1.ErrorBadRequest("invalid request")
	}
	if err := s.labelRepo.SetCardLabels(ctx, req); err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

// GetCardLabels 查询卡片标签集合
func (s *LabelService) GetCardLabels(ctx context.Context, req *boardV1.GetCardLabelsRequest) (*boardV1.ListLabelResponse, error) {
	if req == nil || req.GetCardId() == 0 {
		return nil, boardV1.ErrorBadRequest("invalid request")
	}
	return s.labelRepo.GetCardLabels(ctx, req)
}
