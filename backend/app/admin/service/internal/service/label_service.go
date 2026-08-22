package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/go-utils/trans"

	adminV1 "go-wind-kanban/api/gen/go/admin/service/v1"
	boardV1 "go-wind-kanban/api/gen/go/board/service/v1"

	"go-wind-kanban/pkg/broadcast"
	"go-wind-kanban/pkg/middleware/auth"
)

type LabelService struct {
	adminV1.LabelServiceHTTPServer

	log *log.Helper

	labelServiceClient boardV1.LabelServiceClient
	hub                 *broadcast.Hub
}

func NewLabelService(
	ctx *bootstrap.Context,
	labelServiceClient boardV1.LabelServiceClient,
	hub *broadcast.Hub,
) *LabelService {
	l := log.NewHelper(log.With(ctx.GetLogger(), "module", "label/service/admin-service"))
	return &LabelService{
		log:                l,
		labelServiceClient: labelServiceClient,
		hub:                 hub,
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

	resp, err := s.labelServiceClient.Create(ctx, req)
	if err == nil && resp != nil {
		publishLabelEntity(ctx, s.hub, boardV1.BoardChangeEvent_LABEL_CREATED, resp)
	}
	return resp, err
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
	// 删除前先取实体补 board_id（事件路由键）
	label, _ := s.labelServiceClient.Get(ctx, &boardV1.GetLabelRequest{
		QueryBy: &boardV1.GetLabelRequest_Id{Id: req.GetId()},
	})
	resp, err := s.labelServiceClient.Delete(ctx, req)
	if err == nil {
		publishLabelDeleted(ctx, s.hub, label.GetBoardId(), req.GetId())
	}
	return resp, err
}

// SetCardLabels 全量替换卡片标签集合
func (s *LabelService) SetCardLabels(ctx context.Context, req *boardV1.SetCardLabelsRequest) (*emptypb.Empty, error) {
	resp, err := s.labelServiceClient.SetCardLabels(ctx, req)
	if err == nil {
		// 轻量载荷：仅告知客户端某卡片标签集合变更，由客户端重拉。
		// boardId 未知（label_service 无 card 访问权），用 0 占位——
		// 客户端按 cardId 本地定位所属看板即可。
		publishCardLabelsChanged(ctx, s.hub, &boardV1.Card{
			Id:      trans.Ptr(req.GetCardId()),
			BoardId: trans.Ptr(uint32(0)),
		})
	}
	return resp, err
}

// GetCardLabels 查询卡片标签集合
func (s *LabelService) GetCardLabels(ctx context.Context, req *boardV1.GetCardLabelsRequest) (*boardV1.ListLabelResponse, error) {
	return s.labelServiceClient.GetCardLabels(ctx, req)
}
