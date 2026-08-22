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

	"go-wind-cms/pkg/broadcast"
	"go-wind-cms/pkg/middleware/auth"
)

type ColumnService struct {
	appV1.ColumnServiceHTTPServer

	log *log.Helper

	columnServiceClient boardV1.ColumnServiceClient
	hub             *broadcast.Hub
}

func NewColumnService(
	ctx *bootstrap.Context,
	columnServiceClient boardV1.ColumnServiceClient,
	hub *broadcast.Hub,
) *ColumnService {
	l := log.NewHelper(log.With(ctx.GetLogger(), "module", "column/service/app-service"))
	return &ColumnService{
		log:                 l,
		columnServiceClient: columnServiceClient,
		hub:             hub,
	}
}

func (s *ColumnService) List(ctx context.Context, req *paginationV1.PagingRequest) (*boardV1.ListColumnResponse, error) {
	return s.columnServiceClient.List(ctx, req)
}

func (s *ColumnService) Get(ctx context.Context, req *boardV1.GetColumnRequest) (*boardV1.Column, error) {
	return s.columnServiceClient.Get(ctx, req)
}

func (s *ColumnService) Create(ctx context.Context, req *boardV1.CreateColumnRequest) (*boardV1.Column, error) {
	if req == nil || req.Data == nil {
		return nil, appV1.ErrorBadRequest("invalid parameter")
	}

	// 获取操作人信息
	operator, err := auth.FromContext(ctx)
	if err != nil {
		return nil, err
	}

	req.Data.CreatedBy = trans.Ptr(operator.UserId)

	resp, err := s.columnServiceClient.Create(ctx, req)
	if err == nil && resp != nil {
		publishColumnEntity(ctx, s.hub, boardV1.BoardChangeEvent_COLUMN_CREATED, resp)
	}
	return resp, err
}

func (s *ColumnService) Update(ctx context.Context, req *boardV1.UpdateColumnRequest) (*boardV1.Column, error) {
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

	resp, err := s.columnServiceClient.Update(ctx, req)
	if err == nil && resp != nil {
		publishColumnEntity(ctx, s.hub, boardV1.BoardChangeEvent_COLUMN_UPDATED, resp)
	}
	return resp, err
}

func (s *ColumnService) Delete(ctx context.Context, req *boardV1.DeleteColumnRequest) (*emptypb.Empty, error) {
	// 删除前先取实体补 board_id（事件路由键）
	col, _ := s.columnServiceClient.Get(ctx, &boardV1.GetColumnRequest{
		QueryBy: &boardV1.GetColumnRequest_Id{Id: req.GetId()},
	})
	resp, err := s.columnServiceClient.Delete(ctx, req)
	if err == nil {
		publishColumnDeleted(ctx, s.hub, col.GetBoardId(), req.GetId())
	}
	return resp, err
}

// Move 移动列（看板内重排序）
func (s *ColumnService) Move(ctx context.Context, req *boardV1.MoveColumnRequest) (*boardV1.Column, error) {
	resp, err := s.columnServiceClient.Move(ctx, req)
	if err == nil && resp != nil {
		publishColumnEntity(ctx, s.hub, boardV1.BoardChangeEvent_COLUMN_MOVED, resp)
	}
	return resp, err
}
