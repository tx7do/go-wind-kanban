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

// BoardService 看板服务
type BoardService struct {
	boardV1.UnimplementedBoardServiceServer

	log *log.Helper

	boardRepo *data.BoardRepo
}

func NewBoardService(
	ctx *bootstrap.Context,
	boardRepo *data.BoardRepo,
) *BoardService {
	svc := &BoardService{
		log:       ctx.NewLoggerHelper("board/service/core-service"),
		boardRepo: boardRepo,
	}

	return svc
}

func (s *BoardService) List(ctx context.Context, req *paginationV1.PagingRequest) (*boardV1.ListBoardResponse, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	return s.boardRepo.List(ctx, req)
}

func (s *BoardService) Get(ctx context.Context, req *boardV1.GetBoardRequest) (*boardV1.Board, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	return s.boardRepo.Get(ctx, req)
}

func (s *BoardService) Create(ctx context.Context, req *boardV1.CreateBoardRequest) (*boardV1.Board, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	// 看板名称必须由服务端校验，避免空名看板进入列表导致排序与展示异常
	if req.Data.GetName() == "" {
		return nil, boardV1.ErrorBadRequest("name is required")
	}

	return s.boardRepo.Create(ctx, req)
}

func (s *BoardService) Update(ctx context.Context, req *boardV1.UpdateBoardRequest) (*boardV1.Board, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	return s.boardRepo.Update(ctx, req)
}

func (s *BoardService) Delete(ctx context.Context, req *boardV1.DeleteBoardRequest) (*emptypb.Empty, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid request")
	}
	if err := s.boardRepo.Delete(ctx, req); err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

// Move 移动看板（租户内重排序，Lexorank 排序）
func (s *BoardService) Move(ctx context.Context, req *boardV1.MoveBoardRequest) (*boardV1.Board, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid request")
	}
	if req.GetId() == 0 {
		return nil, boardV1.ErrorBadRequest("id is required")
	}
	return s.boardRepo.Move(ctx, req)
}

// GetBoardSnapshot 获取看板完整快照（看板 + 全部列 + 全部卡片）
func (s *BoardService) GetBoardSnapshot(ctx context.Context, req *boardV1.GetBoardSnapshotRequest) (*boardV1.BoardSnapshot, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid request")
	}
	if req.GetBoardId() == 0 {
		return nil, boardV1.ErrorBadRequest("board_id is required")
	}
	return s.boardRepo.GetBoardSnapshot(ctx, req)
}

// SyncBoard 差量同步（客户端上报已知版本，仅返回变化实体与删除 ID）
func (s *BoardService) SyncBoard(ctx context.Context, req *boardV1.SyncBoardRequest) (*boardV1.SyncBoardResponse, error) {
	if req == nil || req.GetBoardId() == 0 {
		return nil, boardV1.ErrorBadRequest("invalid request")
	}
	return s.boardRepo.SyncBoard(ctx, req)
}
