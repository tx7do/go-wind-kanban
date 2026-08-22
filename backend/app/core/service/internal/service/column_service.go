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

// ColumnService 看板列服务
type ColumnService struct {
	boardV1.UnimplementedColumnServiceServer

	log *log.Helper

	columnRepo *data.ColumnRepo
}

func NewColumnService(
	ctx *bootstrap.Context,
	columnRepo *data.ColumnRepo,
) *ColumnService {
	svc := &ColumnService{
		log:        ctx.NewLoggerHelper("column/service/core-service"),
		columnRepo: columnRepo,
	}

	return svc
}

func (s *ColumnService) List(ctx context.Context, req *paginationV1.PagingRequest) (*boardV1.ListColumnResponse, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	return s.columnRepo.List(ctx, req)
}

func (s *ColumnService) Get(ctx context.Context, req *boardV1.GetColumnRequest) (*boardV1.Column, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	return s.columnRepo.Get(ctx, req)
}

func (s *ColumnService) Create(ctx context.Context, req *boardV1.CreateColumnRequest) (*boardV1.Column, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	// 列名与所属看板必须由服务端校验，避免孤儿列或空名列进入看板
	if req.Data.GetName() == "" {
		return nil, boardV1.ErrorBadRequest("name is required")
	}
	if req.Data.GetBoardId() == 0 {
		return nil, boardV1.ErrorBadRequest("board_id is required")
	}

	return s.columnRepo.Create(ctx, req)
}

func (s *ColumnService) Update(ctx context.Context, req *boardV1.UpdateColumnRequest) (*boardV1.Column, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	return s.columnRepo.Update(ctx, req)
}

func (s *ColumnService) Delete(ctx context.Context, req *boardV1.DeleteColumnRequest) (*emptypb.Empty, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid request")
	}
	if err := s.columnRepo.Delete(ctx, req); err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

// Move 移动列（看板内重排序，Lexorank 排序）
func (s *ColumnService) Move(ctx context.Context, req *boardV1.MoveColumnRequest) (*boardV1.Column, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid request")
	}
	if req.GetId() == 0 {
		return nil, boardV1.ErrorBadRequest("id is required")
	}
	return s.columnRepo.Move(ctx, req)
}
