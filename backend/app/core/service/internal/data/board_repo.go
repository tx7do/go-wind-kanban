package data

import (
	"context"
	"time"

	"entgo.io/ent/dialect/sql"
	"github.com/go-kratos/kratos/v2/log"
	"github.com/tx7do/kratos-bootstrap/bootstrap"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	entCrud "github.com/tx7do/go-crud/entgo"

	"github.com/tx7do/go-utils/copierutil"
	"github.com/tx7do/go-utils/mapper"

	"go-wind-cms/app/core/service/internal/data/ent"
	"go-wind-cms/app/core/service/internal/data/ent/board"
	"go-wind-cms/app/core/service/internal/data/ent/card"
	"go-wind-cms/app/core/service/internal/data/ent/column"
	"go-wind-cms/app/core/service/internal/data/ent/predicate"

	boardV1 "go-wind-cms/api/gen/go/board/service/v1"

	"go-wind-cms/pkg/lexorank"
)

type BoardRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper

	mapper *mapper.CopierMapper[boardV1.Board, ent.Board]

	repository *entCrud.Repository[
		ent.BoardQuery, ent.BoardSelect,
		ent.BoardCreate, ent.BoardCreateBulk,
		ent.BoardUpdate, ent.BoardUpdateOne,
		ent.BoardDelete,
		predicate.Board,
		boardV1.Board, ent.Board,
	]
}

func NewBoardRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *BoardRepo {
	repo := &BoardRepo{
		log:       ctx.NewLoggerHelper("board/repo/core-service"),
		entClient: entClient,
		mapper:    mapper.NewCopierMapper[boardV1.Board, ent.Board](),
	}

	repo.init()

	return repo
}

func (r *BoardRepo) init() {
	r.repository = entCrud.NewRepository[
		ent.BoardQuery, ent.BoardSelect,
		ent.BoardCreate, ent.BoardCreateBulk,
		ent.BoardUpdate, ent.BoardUpdateOne,
		ent.BoardDelete,
		predicate.Board,
		boardV1.Board, ent.Board,
	](r.mapper)

	r.mapper.AppendConverters(copierutil.NewTimeStringConverterPair())
	r.mapper.AppendConverters(copierutil.NewTimeTimestamppbConverterPair())
}

// derefRank 解引用可空 rank 字段；nil 返回 ""（lexorank 下界哨兵语义）。
func derefRank(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

func (r *BoardRepo) Count(ctx context.Context, whereCond []func(s *sql.Selector)) (int, error) {
	builder := r.entClient.Client().Board.Query()
	if len(whereCond) != 0 {
		builder.Modify(whereCond...)
	}

	count, err := builder.Count(ctx)
	if err != nil {
		r.log.Errorf("query count failed: %s", err.Error())
		return 0, boardV1.ErrorInternalServerError("query count failed")
	}

	return count, nil
}

func (r *BoardRepo) List(ctx context.Context, req *paginationV1.PagingRequest) (*boardV1.ListBoardResponse, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	builder := r.entClient.Client().Board.Query()

	ret, err := r.repository.ListWithPaging(ctx, builder, builder.Clone(), req)
	if err != nil {
		return nil, err
	}
	if ret == nil {
		return &boardV1.ListBoardResponse{Total: 0, Items: nil}, nil
	}

	return &boardV1.ListBoardResponse{
		Total: ret.Total,
		Items: ret.Items,
	}, nil
}

func (r *BoardRepo) IsExist(ctx context.Context, id uint32) (bool, error) {
	exist, err := r.entClient.Client().Board.Query().
		Where(board.IDEQ(id)).
		Exist(ctx)
	if err != nil {
		r.log.Errorf("query exist failed: %s", err.Error())
		return false, boardV1.ErrorInternalServerError("query exist failed")
	}
	return exist, nil
}

func (r *BoardRepo) Get(ctx context.Context, req *boardV1.GetBoardRequest) (*boardV1.Board, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	builder := r.entClient.Client().Board.Query()

	var whereCond []func(s *sql.Selector)
	switch req.QueryBy.(type) {
	default:
	case *boardV1.GetBoardRequest_Id:
		whereCond = append(whereCond, board.IDEQ(req.GetId()))
	}

	dto, err := r.repository.Get(ctx, builder, req.GetViewMask(), whereCond...)
	if err != nil {
		return nil, err
	}

	return dto, err
}

func (r *BoardRepo) Create(ctx context.Context, req *boardV1.CreateBoardRequest) (*boardV1.Board, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	// 新看板的初始 rank：追加到租户看板列表末尾。
	tid, hasTenant := maybeTenantFromViewer(ctx)
	newRank, err := r.allocateTailRank(ctx, tid, hasTenant)
	if err != nil {
		return nil, err
	}

	builder := r.entClient.Client().Board.Create().
		SetNillableTenantID(req.Data.TenantId).
		SetNillableName(req.Data.Name).
		SetNillableDescription(req.Data.Description).
		SetRank(newRank).
		SetVersion(1).
		SetNillableCreatedBy(req.Data.CreatedBy).
		SetCreatedAt(time.Now())

	if req.Data.Id != nil {
		builder.SetID(req.GetData().GetId())
	}

	t, err := builder.Save(ctx)
	if err != nil {
		r.log.Errorf("insert board failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("insert board failed")
	}

	return r.mapper.ToDTO(t), nil
}

func (r *BoardRepo) Update(ctx context.Context, req *boardV1.UpdateBoardRequest) (*boardV1.Board, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	// 如果不存在则创建
	if req.GetAllowMissing() {
		exist, err := r.IsExist(ctx, req.GetId())
		if err != nil {
			return nil, err
		}
		if !exist {
			createReq := &boardV1.CreateBoardRequest{Data: req.Data}
			createReq.Data.CreatedBy = createReq.Data.UpdatedBy
			createReq.Data.UpdatedBy = nil
			return r.Create(ctx, createReq)
		}
	}

	tid, hasTenant := maybeTenantFromViewer(ctx)
	callerUserID, hasUser := viewerUserIDFromContext(ctx)
	builder := r.entClient.Client().Debug().Board.UpdateOneID(req.GetId())
	builder.Where(board.IDEQ(req.GetId()))
	if hasTenant {
		builder.Where(board.TenantIDEQ(tid))
	}
	// 乐观锁：期望版本不匹配（0 行命中）时由 UpdateOne 返回空结果 → 上层转 CONFLICT。
	if req.GetExpectedVersion() > 0 {
		builder.Where(board.VersionEQ(req.GetExpectedVersion()))
	}
	result, err := r.repository.UpdateOne(ctx, builder, req.Data, req.GetUpdateMask(),
		func(dto *boardV1.Board) {
			builder.
				SetNillableName(req.Data.Name).
				SetNillableDescription(req.Data.Description).
				SetUpdatedAt(time.Now())

			// updated_by 强制由服务端 viewer context 推导，忽略客户端传入值
			if hasUser {
				builder.SetUpdatedBy(callerUserID)
			}
		},
		func(s *sql.Selector) {
			s.Where(sql.EQ(board.FieldID, req.GetId()))
		},
	)

	// 乐观锁命中失败：版本不匹配，返回 409。
	if err == nil && result == nil && req.GetExpectedVersion() > 0 {
		return nil, boardV1.ErrorConflict("board version conflict: expected=%d", req.GetExpectedVersion())
	}

	// 乐观锁预埋：每次 Update 成功后 version+1（AddVersion 为 SQL 原子自增）。
	if result != nil {
		if vErr := r.bumpVersion(ctx, req.GetId(), tid, hasTenant); vErr != nil {
			r.log.Errorf("board version bump failed: %s", vErr.Error())
		}
	}

	return result, err
}

func (r *BoardRepo) bumpVersion(ctx context.Context, id uint32, tid uint32, hasTenant bool) error {
	builder := r.entClient.Client().Board.UpdateOneID(id)
	builder.Where(board.IDEQ(id))
	if hasTenant {
		builder.Where(board.TenantIDEQ(tid))
	}
	if _, err := builder.AddVersion(1).Save(ctx); err != nil {
		return err
	}
	return nil
}

func (r *BoardRepo) Delete(ctx context.Context, req *boardV1.DeleteBoardRequest) error {
	if req == nil {
		return boardV1.ErrorBadRequest("invalid parameter")
	}

	tid, hasTenant := maybeTenantFromViewer(ctx)
	delBuilder := r.entClient.Client().Board.Delete()
	delBuilder.Where(board.IDEQ(req.GetId()))
	if hasTenant {
		delBuilder.Where(board.TenantIDEQ(tid))
	}
	if _, err := delBuilder.Exec(ctx); err != nil {
		if ent.IsNotFound(err) {
			return boardV1.ErrorNotFound("board not found")
		}

		r.log.Errorf("delete one data failed: %s", err.Error())

		return boardV1.ErrorInternalServerError("delete failed")
	}

	return nil
}

// Move 在租户看板列表内重排指定看板的位置。
//
// anchor 策略：
//   - before_id=X：新 rank = Between(X 的前驱 rank, X 的 rank)
//   - after_id=X ：新 rank = Between(X 的 rank, X 的后驱 rank)
//   - 无 anchor  ：尾部追加 = Between(末位 rank, "")
//
// Between 键空间耗尽时，对当前租户全部看板执行 Rebalance，整列重写 rank。
func (r *BoardRepo) Move(ctx context.Context, req *boardV1.MoveBoardRequest) (*boardV1.Board, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	tid, hasTenant := maybeTenantFromViewer(ctx)
	if !hasTenant {
		return nil, boardV1.ErrorBadRequest("tenant scope required to move board")
	}

	// 拉取当前租户内全部看板（按 rank 升序），用于定位 anchor 与重排。
	allBoards, err := r.entClient.Client().Board.Query().
		Where(board.TenantIDEQ(tid)).
		Order(ent.Asc(board.FieldRank)).
		All(ctx)
	if err != nil {
		r.log.Errorf("move board: query siblings failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("query siblings failed")
	}

	moverIdx := -1
	for i, b := range allBoards {
		if b.ID == req.GetId() {
			moverIdx = i
			break
		}
	}
	if moverIdx < 0 {
		return nil, boardV1.ErrorNotFound("board not found")
	}

	lowRank, highRank, ok := r.resolveAnchorRanks(allBoards, moverIdx, req)
	if !ok {
		return nil, boardV1.ErrorAnchorNotSibling("anchor board not in the same tenant scope")
	}

	newRank, betweenOk := lexorank.Between(lowRank, highRank)
	if !betweenOk {
		// 键空间耗尽：整列重排。
		if rErr := r.rebalanceBoards(ctx, allBoards, moverIdx, req, tid); rErr != nil {
			return nil, rErr
		}
		return r.getBoardByID(ctx, req.GetId(), tid, hasTenant)
	}

	builder := r.entClient.Client().Board.UpdateOneID(req.GetId())
	builder.Where(board.IDEQ(req.GetId()), board.TenantIDEQ(tid))
	if req.GetExpectedVersion() > 0 {
		builder.Where(board.VersionEQ(req.GetExpectedVersion()))
	}
	if _, err := builder.SetRank(newRank).AddVersion(1).Save(ctx); err != nil {
		if ent.IsNotFound(err) && req.GetExpectedVersion() > 0 {
			return nil, boardV1.ErrorConflict("board version conflict: expected=%d", req.GetExpectedVersion())
		}
		r.log.Errorf("move board: set rank failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("move board failed")
	}

	return r.getBoardByID(ctx, req.GetId(), tid, hasTenant)
}

// resolveAnchorRanks 根据移动请求确定新 rank 的上下界（low, high）。
// 空串表示哨兵边界（列首/列尾）。anchor 指定但不在同级范围内时 ok=false。
func (r *BoardRepo) resolveAnchorRanks(allBoards []*ent.Board, moverIdx int, req *boardV1.MoveBoardRequest) (string, string, bool) {
	// 把 mover 从序列中剔除，便于在剩余同级中定位 anchor。
	siblings := make([]*ent.Board, 0, len(allBoards)-1)
	for i, b := range allBoards {
		if i == moverIdx {
			continue
		}
		siblings = append(siblings, b)
	}

	var low, high string
	switch a := req.Anchor.(type) {
	case *boardV1.MoveBoardRequest_BeforeId:
		anchorIdx := -1
		for i, b := range siblings {
			if b.ID == a.BeforeId {
				anchorIdx = i
				break
			}
		}
		if anchorIdx < 0 {
			return "", "", false
		}
		if anchorIdx > 0 {
			low = derefRank(siblings[anchorIdx-1].Rank)
		}
		high = derefRank(siblings[anchorIdx].Rank)
	case *boardV1.MoveBoardRequest_AfterId:
		anchorIdx := -1
		for i, b := range siblings {
			if b.ID == a.AfterId {
				anchorIdx = i
				break
			}
		}
		if anchorIdx < 0 {
			return "", "", false
		}
		low = derefRank(siblings[anchorIdx].Rank)
		if anchorIdx < len(siblings)-1 {
			high = derefRank(siblings[anchorIdx+1].Rank)
		}
	default:
		// 无 anchor：尾部追加，上界为 ""（哨兵）。
		if len(siblings) > 0 {
			low = derefRank(siblings[len(siblings)-1].Rank)
		}
	}
	return low, high, true
}

// rebalanceBoards 对租户内全部看板执行整列重排。
// moverIdx 指示被移动看板在 allBoards 中的原始位置；重排时将其按 anchor
// 策略插入目标位置，然后对全列重新分配均匀 rank。
func (r *BoardRepo) rebalanceBoards(ctx context.Context, allBoards []*ent.Board, moverIdx int, req *boardV1.MoveBoardRequest, tid uint32) error {
	ordered := make([]*ent.Board, 0, len(allBoards))
	mover := allBoards[moverIdx]
	for i, b := range allBoards {
		if i == moverIdx {
			continue
		}
		ordered = append(ordered, b)
	}

	// 根据 anchor 决定 mover 在 ordered 中的插入位置。
	insertAt := len(ordered) // 默认尾部
	switch a := req.Anchor.(type) {
	case *boardV1.MoveBoardRequest_BeforeId:
		for i, b := range ordered {
			if b.ID == a.BeforeId {
				insertAt = i
				break
			}
		}
	case *boardV1.MoveBoardRequest_AfterId:
		for i, b := range ordered {
			if b.ID == a.AfterId {
				insertAt = i + 1
				break
			}
		}
	}
	ordered = append(ordered, nil)
	copy(ordered[insertAt+1:], ordered[insertAt:])
	ordered[insertAt] = mover

	newRanks := lexorank.Rebalance(len(ordered))
	if newRanks == nil || len(newRanks) != len(ordered) {
		return boardV1.ErrorRebalanceFailed("rebalance boards failed")
	}

	for i, b := range ordered {
		if _, err := r.entClient.Client().Board.UpdateOneID(b.ID).
			Where(board.IDEQ(b.ID), board.TenantIDEQ(tid)).
			SetRank(newRanks[i]).
			Save(ctx); err != nil {
			r.log.Errorf("rebalance board %d failed: %s", b.ID, err.Error())
			return boardV1.ErrorRebalanceFailed("rebalance boards failed")
		}
	}
	return nil
}

// getBoardByID 取单个看板（带租户过滤），用于 Move 后回读最新状态。
func (r *BoardRepo) getBoardByID(ctx context.Context, id uint32, tid uint32, hasTenant bool) (*boardV1.Board, error) {
	q := r.entClient.Client().Board.Query().Where(board.IDEQ(id))
	if hasTenant {
		q = q.Where(board.TenantIDEQ(tid))
	}
	t, err := q.Only(ctx)
	if err != nil {
		return nil, boardV1.ErrorNotFound("board not found")
	}
	return r.mapper.ToDTO(t), nil
}

// allocateTailRank 为新建看板分配尾部 rank = Between(当前租户末位 rank, "")。
// 空租户（无任何看板）时返回全键空间中点。
func (r *BoardRepo) allocateTailRank(ctx context.Context, tid uint32, hasTenant bool) (string, error) {
	q := r.entClient.Client().Board.Query()
	if hasTenant {
		q = q.Where(board.TenantIDEQ(tid))
	}
	last, err := q.Order(ent.Desc(board.FieldRank)).First(ctx)
	low := ""
	if err == nil && last != nil {
		low = derefRank(last.Rank)
	}
	rank, ok := lexorank.Between(low, "")
	if ok {
		return rank, nil
	}

	// 尾部追加耗尽极罕见（需末位 rank 已贴 maxRank），触发全列重排。
	allQ := r.entClient.Client().Board.Query()
	if hasTenant {
		allQ = allQ.Where(board.TenantIDEQ(tid))
	}
	all, qErr := allQ.Order(ent.Asc(board.FieldRank)).All(ctx)
	if qErr != nil {
		return "", boardV1.ErrorInternalServerError("allocate tail rank failed")
	}
	newRanks := lexorank.Rebalance(len(all) + 1)
	if newRanks == nil {
		return "", boardV1.ErrorRebalanceFailed("allocate tail rank rebalance failed")
	}
	for i, b := range all {
		if _, err := r.entClient.Client().Board.UpdateOneID(b.ID).
			Where(board.IDEQ(b.ID), board.TenantIDEQ(tid)).
			SetRank(newRanks[i]).
			Save(ctx); err != nil {
			return "", boardV1.ErrorRebalanceFailed("allocate tail rank rebalance failed")
		}
	}
	return newRanks[len(newRanks)-1], nil
}

// GetBoardSnapshot 取看板完整快照：看板本体 + 全部列 + 全部卡片（扁平）。
//
// 共 3 次 DB 查询（看板本体、列 edge 查询、卡片 edge 查询），列与卡片均为
// 扁平列表，客户端按 column_id 分组组装看板视图；列内排序已按 rank 升序。
func (r *BoardRepo) GetBoardSnapshot(ctx context.Context, req *boardV1.GetBoardSnapshotRequest) (*boardV1.BoardSnapshot, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	tid, hasTenant := maybeTenantFromViewer(ctx)

	// 1. 看板本体
	bq := r.entClient.Client().Board.Query().Where(board.IDEQ(req.GetBoardId()))
	if hasTenant {
		bq = bq.Where(board.TenantIDEQ(tid))
	}
	b, err := bq.Only(ctx)
	if err != nil {
		return nil, boardV1.ErrorNotFound("board not found")
	}

	// 2. 列（edge 查询，按 rank 升序；租户过滤由 ent privacy 层注入）
	cols, err := b.QueryColumns().
		Order(ent.Asc(column.FieldRank)).
		All(ctx)
	if err != nil {
		r.log.Errorf("snapshot: query columns failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("snapshot query failed")
	}

	// 3. 卡片（edge 查询，按 rank 升序）
	cards, err := b.QueryCards().
		Order(ent.Asc(card.FieldRank)).
		All(ctx)
	if err != nil {
		r.log.Errorf("snapshot: query cards failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("snapshot query failed")
	}

	snap := &boardV1.BoardSnapshot{
		Board: r.mapper.ToDTO(b),
	}
	for _, c := range cols {
		snap.Columns = append(snap.Columns, columnToDTO(c))
	}
	for _, c := range cards {
		snap.Cards = append(snap.Cards, cardToDTO(c))
	}
	return snap, nil
}

// SyncBoard 差量同步：客户端上报已知版本，仅返回版本有变化的实体与已删除 ID。
//
// 语义：
//   - board 版本与 known 不一致 → 返回最新本体；一致 → 不带本体
//   - 列/卡片：DB 中不存在于 known（新）或版本不同（变）→ upserted
//   - known 中存在但 DB 已无（删）→ deleted_ids
func (r *BoardRepo) SyncBoard(ctx context.Context, req *boardV1.SyncBoardRequest) (*boardV1.SyncBoardResponse, error) {
	if req == nil || req.GetBoardId() == 0 {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	tid, hasTenant := maybeTenantFromViewer(ctx)

	bq := r.entClient.Client().Board.Query().Where(board.IDEQ(req.GetBoardId()))
	if hasTenant {
		bq = bq.Where(board.TenantIDEQ(tid))
	}
	b, err := bq.Only(ctx)
	if err != nil {
		return nil, boardV1.ErrorNotFound("board not found")
	}

	resp := &boardV1.SyncBoardResponse{}

	if req.GetKnownBoardVersion() != b.Version {
		resp.Board = r.mapper.ToDTO(b)
	}

	// 列差量
	cols, err := b.QueryColumns().Order(ent.Asc(column.FieldRank)).All(ctx)
	if err != nil {
		r.log.Errorf("sync board: query columns failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("sync board failed")
	}
	knownCols := make(map[uint32]uint32, len(req.GetKnownColumnVersions()))
	for _, e := range req.GetKnownColumnVersions() {
		knownCols[e.GetId()] = e.GetVersion()
	}
	liveCols := make(map[uint32]struct{}, len(cols))
	for _, c := range cols {
		liveCols[c.ID] = struct{}{}
		if v, known := knownCols[c.ID]; !known || v != c.Version {
			resp.UpsertedColumns = append(resp.UpsertedColumns, columnToDTO(c))
		}
	}
	for id := range knownCols {
		if _, live := liveCols[id]; !live {
			resp.DeletedColumnIds = append(resp.DeletedColumnIds, id)
		}
	}

	// 卡片差量
	cards, err := b.QueryCards().Order(ent.Asc(card.FieldRank)).All(ctx)
	if err != nil {
		r.log.Errorf("sync board: query cards failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("sync board failed")
	}
	knownCards := make(map[uint32]uint32, len(req.GetKnownCardVersions()))
	for _, e := range req.GetKnownCardVersions() {
		knownCards[e.GetId()] = e.GetVersion()
	}
	liveCards := make(map[uint32]struct{}, len(cards))
	for _, c := range cards {
		liveCards[c.ID] = struct{}{}
		if v, known := knownCards[c.ID]; !known || v != c.Version {
			resp.UpsertedCards = append(resp.UpsertedCards, cardToDTO(c))
		}
	}
	for id := range knownCards {
		if _, live := liveCards[id]; !live {
			resp.DeletedCardIds = append(resp.DeletedCardIds, id)
		}
	}

	return resp, nil
}
