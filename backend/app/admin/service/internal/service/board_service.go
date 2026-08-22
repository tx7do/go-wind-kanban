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

type BoardService struct {
	adminV1.BoardServiceHTTPServer

	log *log.Helper

	boardServiceClient boardV1.BoardServiceClient
	hub             *broadcast.Hub
}

func NewBoardService(
	ctx *bootstrap.Context,
	boardServiceClient boardV1.BoardServiceClient,
	hub *broadcast.Hub,
) *BoardService {
	l := log.NewHelper(log.With(ctx.GetLogger(), "module", "board/service/admin-service"))
	return &BoardService{
		log:                l,
		boardServiceClient: boardServiceClient,
		hub:             hub,
	}
}

func (s *BoardService) List(ctx context.Context, req *paginationV1.PagingRequest) (*boardV1.ListBoardResponse, error) {
	return s.boardServiceClient.List(ctx, req)
}

func (s *BoardService) Get(ctx context.Context, req *boardV1.GetBoardRequest) (*boardV1.Board, error) {
	return s.boardServiceClient.Get(ctx, req)
}

func (s *BoardService) Create(ctx context.Context, req *boardV1.CreateBoardRequest) (*boardV1.Board, error) {
	if req == nil || req.Data == nil {
		return nil, adminV1.ErrorBadRequest("invalid parameter")
	}

	// 获取操作人信息
	operator, err := auth.FromContext(ctx)
	if err != nil {
		return nil, err
	}

	req.Data.CreatedBy = trans.Ptr(operator.UserId)

	resp, err := s.boardServiceClient.Create(ctx, req)
	if err == nil && resp != nil {
		publishBoardEntity(ctx, s.hub, boardV1.BoardChangeEvent_BOARD_CREATED, resp)
	}
	return resp, err
}

func (s *BoardService) Update(ctx context.Context, req *boardV1.UpdateBoardRequest) (*boardV1.Board, error) {
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

	resp, err := s.boardServiceClient.Update(ctx, req)
	if err == nil && resp != nil {
		publishBoardEntity(ctx, s.hub, boardV1.BoardChangeEvent_BOARD_UPDATED, resp)
	}
	return resp, err
}

func (s *BoardService) Delete(ctx context.Context, req *boardV1.DeleteBoardRequest) (*emptypb.Empty, error) {
	resp, err := s.boardServiceClient.Delete(ctx, req)
	if err == nil {
		publishBoardDeleted(ctx, s.hub, req.GetId())
	}
	return resp, err
}

// Move 移动看板（租户内重排序）
func (s *BoardService) Move(ctx context.Context, req *boardV1.MoveBoardRequest) (*boardV1.Board, error) {
	resp, err := s.boardServiceClient.Move(ctx, req)
	if err == nil && resp != nil {
		publishBoardEntity(ctx, s.hub, boardV1.BoardChangeEvent_BOARD_MOVED, resp)
	}
	return resp, err
}

// SyncBoard 差量同步
func (s *BoardService) SyncBoard(ctx context.Context, req *boardV1.SyncBoardRequest) (*boardV1.SyncBoardResponse, error) {
	return s.boardServiceClient.SyncBoard(ctx, req)
}
