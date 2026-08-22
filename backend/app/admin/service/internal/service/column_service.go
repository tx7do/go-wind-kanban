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

	"go-wind-cms/pkg/middleware/auth"
)

type ColumnService struct {
	adminV1.ColumnServiceHTTPServer

	log *log.Helper

	columnServiceClient boardV1.ColumnServiceClient
}

func NewColumnService(
	ctx *bootstrap.Context,
	columnServiceClient boardV1.ColumnServiceClient,
) *ColumnService {
	l := log.NewHelper(log.With(ctx.GetLogger(), "module", "column/service/admin-service"))
	return &ColumnService{
		log:                 l,
		columnServiceClient: columnServiceClient,
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
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}

	// 获取操作人信息
	operator, err := auth.FromContext(ctx)
	if err != nil {
		return nil, err
	}

	req.Data.CreatedBy = trans.Ptr(operator.UserId)

	return s.columnServiceClient.Create(ctx, req)
}

func (s *ColumnService) Update(ctx context.Context, req *boardV1.UpdateColumnRequest) (*boardV1.Column, error) {
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

	return s.columnServiceClient.Update(ctx, req)
}

func (s *ColumnService) Delete(ctx context.Context, req *boardV1.DeleteColumnRequest) (*emptypb.Empty, error) {
	return s.columnServiceClient.Delete(ctx, req)
}

// Move 移动列（看板内重排序）
func (s *ColumnService) Move(ctx context.Context, req *boardV1.MoveColumnRequest) (*boardV1.Column, error) {
	return s.columnServiceClient.Move(ctx, req)
}
