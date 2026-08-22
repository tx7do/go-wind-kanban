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

type LabelService struct {
	adminV1.LabelServiceHTTPServer

	log *log.Helper

	labelServiceClient boardV1.LabelServiceClient
}

func NewLabelService(
	ctx *bootstrap.Context,
	labelServiceClient boardV1.LabelServiceClient,
) *LabelService {
	l := log.NewHelper(log.With(ctx.GetLogger(), "module", "label/service/admin-service"))
	return &LabelService{
		log:                l,
		labelServiceClient: labelServiceClient,
	}
}

func (s *LabelService) List(ctx context.Context, req *paginationV1.PagingRequest) (*boardV1.ListLabelResponse, error) {
	return s.labelServiceClient.List(ctx, req)
}

func (s *LabelService) Get(ctx context.Context, req *boardV1.GetLabelRequest) (*boardV1.Label, error) {
	return s.labelServiceClient.Get(ctx, req)
}

func (s *LabelService) Create(ctx context.Context, req *boardV1.CreateLabelRequest) (*boardV1.Label, error) {
	if req == nil || req.Data == nil {
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}

	operator, err := auth.FromContext(ctx)
	if err != nil {
		return nil, err
	}

	req.Data.CreatedBy = trans.Ptr(operator.UserId)

	return s.labelServiceClient.Create(ctx, req)
}

func (s *LabelService) Update(ctx context.Context, req *boardV1.UpdateLabelRequest) (*boardV1.Label, error) {
	if req == nil || req.Data == nil {
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}

	operator, err := auth.FromContext(ctx)
	if err != nil {
		return nil, err
	}

	req.Data.Id = trans.Ptr(req.GetId())

	req.Data.UpdatedBy = trans.Ptr(operator.GetUserId())
	if req.UpdateMask != nil {
		req.UpdateMask.Paths = append(req.UpdateMask.Paths, "updated_by")
	}

	return s.labelServiceClient.Update(ctx, req)
}

func (s *LabelService) Delete(ctx context.Context, req *boardV1.DeleteLabelRequest) (*emptypb.Empty, error) {
	return s.labelServiceClient.Delete(ctx, req)
}

// SetCardLabels 全量替换卡片标签集合
func (s *LabelService) SetCardLabels(ctx context.Context, req *boardV1.SetCardLabelsRequest) (*emptypb.Empty, error) {
	return s.labelServiceClient.SetCardLabels(ctx, req)
}

// GetCardLabels 查询卡片标签集合
func (s *LabelService) GetCardLabels(ctx context.Context, req *boardV1.GetCardLabelsRequest) (*boardV1.ListLabelResponse, error) {
	return s.labelServiceClient.GetCardLabels(ctx, req)
}
