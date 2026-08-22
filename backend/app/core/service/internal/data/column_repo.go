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
	"go-wind-cms/app/core/service/internal/data/ent/column"
	"go-wind-cms/app/core/service/internal/data/ent/predicate"

	boardV1 "go-wind-cms/api/gen/go/board/service/v1"

	"go-wind-cms/pkg/lexorank"
)

type ColumnRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper

	mapper *mapper.CopierMapper[boardV1.Column, ent.Column]

	repository *entCrud.Repository[
		ent.ColumnQuery, ent.ColumnSelect,
		ent.ColumnCreate, ent.ColumnCreateBulk,
		ent.ColumnUpdate, ent.ColumnUpdateOne,
		ent.ColumnDelete,
		predicate.Column,
		boardV1.Column, ent.Column,
	]
}

func NewColumnRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *ColumnRepo {
	repo := &ColumnRepo{
		log:       ctx.NewLoggerHelper("column/repo/core-service"),
		entClient: entClient,
		mapper:    mapper.NewCopierMapper[boardV1.Column, ent.Column](),
	}

	repo.init()

	return repo
}

func (r *ColumnRepo) init() {
	r.repository = entCrud.NewRepository[
		ent.ColumnQuery, ent.ColumnSelect,
		ent.ColumnCreate, ent.ColumnCreateBulk,
		ent.ColumnUpdate, ent.ColumnUpdateOne,
		ent.ColumnDelete,
		predicate.Column,
		boardV1.Column, ent.Column,
	](r.mapper)

	r.mapper.AppendConverters(copierutil.NewTimeStringConverterPair())
	r.mapper.AppendConverters(copierutil.NewTimeTimestamppbConverterPair())
}

// columnToDTO 将 ent.Column 转换为 proto DTO。供 board_repo.GetBoardSnapshot 复用。
func columnToDTO(c *ent.Column) *boardV1.Column {
	if c == nil {
		return nil
	}
	return columnMapperInstance.ToDTO(c)
}

var columnMapperInstance = func() *mapper.CopierMapper[boardV1.Column, ent.Column] {
	m := mapper.NewCopierMapper[boardV1.Column, ent.Column]()
	m.AppendConverters(copierutil.NewTimeStringConverterPair())
	m.AppendConverters(copierutil.NewTimeTimestamppbConverterPair())
	return m
}()

func (r *ColumnRepo) Count(ctx context.Context, whereCond []func(s *sql.Selector)) (int, error) {
	builder := r.entClient.Client().Column.Query()
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

func (r *ColumnRepo) List(ctx context.Context, req *paginationV1.PagingRequest) (*boardV1.ListColumnResponse, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	builder := r.entClient.Client().Column.Query()

	ret, err := r.repository.ListWithPaging(ctx, builder, builder.Clone(), req)
	if err != nil {
		return nil, err
	}
	if ret == nil {
		return &boardV1.ListColumnResponse{Total: 0, Items: nil}, nil
	}

	return &boardV1.ListColumnResponse{
		Total: ret.Total,
		Items: ret.Items,
	}, nil
}

func (r *ColumnRepo) IsExist(ctx context.Context, id uint32) (bool, error) {
	exist, err := r.entClient.Client().Column.Query().
		Where(column.IDEQ(id)).
		Exist(ctx)
	if err != nil {
		r.log.Errorf("query exist failed: %s", err.Error())
		return false, boardV1.ErrorInternalServerError("query exist failed")
	}
	return exist, nil
}

func (r *ColumnRepo) Get(ctx context.Context, req *boardV1.GetColumnRequest) (*boardV1.Column, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	builder := r.entClient.Client().Column.Query()

	var whereCond []func(s *sql.Selector)
	switch req.QueryBy.(type) {
	default:
	case *boardV1.GetColumnRequest_Id:
		whereCond = append(whereCond, column.IDEQ(req.GetId()))
	}

	dto, err := r.repository.Get(ctx, builder, req.GetViewMask(), whereCond...)
	if err != nil {
		return nil, err
	}

	return dto, err
}

func (r *ColumnRepo) Create(ctx context.Context, req *boardV1.CreateColumnRequest) (*boardV1.Column, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	// 校验父看板存在且属当前租户，防跨租户注入。
	tid, hasTenant := maybeTenantFromViewer(ctx)
	if !hasTenant {
		return nil, boardV1.ErrorBadRequest("tenant scope required to create column")
	}
	parentBoard, err := r.entClient.Client().Board.Query().
		Where(board.IDEQ(req.Data.GetBoardId()), board.TenantIDEQ(tid)).
		Only(ctx)
	if err != nil {
		return nil, boardV1.ErrorNotFound("board not found")
	}

	// 初始 rank：追加到看板列末尾。
	newRank, err := r.allocateColumnTailRank(ctx, parentBoard.ID, tid)
	if err != nil {
		return nil, err
	}

	builder := r.entClient.Client().Column.Create().
		SetNillableTenantID(req.Data.TenantId).
		SetNillableName(req.Data.Name).
		SetNillableColor(req.Data.Color).
		SetRank(newRank).
		SetVersion(1).
		SetNillableCreatedBy(req.Data.CreatedBy).
		SetCreatedAt(time.Now()).
		SetBoardID(parentBoard.ID)

	t, err := builder.Save(ctx)
	if err != nil {
		r.log.Errorf("insert column failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("insert column failed")
	}

	return r.mapper.ToDTO(t), nil
}

func (r *ColumnRepo) Update(ctx context.Context, req *boardV1.UpdateColumnRequest) (*boardV1.Column, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	if req.GetAllowMissing() {
		exist, err := r.IsExist(ctx, req.GetId())
		if err != nil {
			return nil, err
		}
		if !exist {
			createReq := &boardV1.CreateColumnRequest{Data: req.Data}
			createReq.Data.CreatedBy = createReq.Data.UpdatedBy
			createReq.Data.UpdatedBy = nil
			return r.Create(ctx, createReq)
		}
	}

	tid, hasTenant := maybeTenantFromViewer(ctx)
	callerUserID, hasUser := viewerUserIDFromContext(ctx)
	builder := r.entClient.Client().Debug().Column.UpdateOneID(req.GetId())
	builder.Where(column.IDEQ(req.GetId()))
	if hasTenant {
		builder.Where(column.TenantIDEQ(tid))
	}
	result, err := r.repository.UpdateOne(ctx, builder, req.Data, req.GetUpdateMask(),
		func(dto *boardV1.Column) {
			builder.
				SetNillableName(req.Data.Name).
				SetNillableColor(req.Data.Color).
				SetUpdatedAt(time.Now())

			if hasUser {
				builder.SetUpdatedBy(callerUserID)
			}
		},
		func(s *sql.Selector) {
			s.Where(sql.EQ(column.FieldID, req.GetId()))
		},
	)

	// 乐观锁预埋：每次 Update 成功后 version+1。
	if result != nil {
		if vErr := r.bumpVersion(ctx, req.GetId(), tid, hasTenant); vErr != nil {
			r.log.Errorf("column version bump failed: %s", vErr.Error())
		}
	}

	return result, err
}

func (r *ColumnRepo) bumpVersion(ctx context.Context, id uint32, tid uint32, hasTenant bool) error {
	builder := r.entClient.Client().Column.UpdateOneID(id)
	builder.Where(column.IDEQ(id))
	if hasTenant {
		builder.Where(column.TenantIDEQ(tid))
	}
	if _, err := builder.AddVersion(1).Save(ctx); err != nil {
		return err
	}
	return nil
}

func (r *ColumnRepo) Delete(ctx context.Context, req *boardV1.DeleteColumnRequest) error {
	if req == nil {
		return boardV1.ErrorBadRequest("invalid parameter")
	}

	tid, hasTenant := maybeTenantFromViewer(ctx)
	delBuilder := r.entClient.Client().Column.Delete()
	delBuilder.Where(column.IDEQ(req.GetId()))
	if hasTenant {
		delBuilder.Where(column.TenantIDEQ(tid))
	}
	if _, err := delBuilder.Exec(ctx); err != nil {
		if ent.IsNotFound(err) {
			return boardV1.ErrorNotFound("column not found")
		}

		r.log.Errorf("delete one data failed: %s", err.Error())

		return boardV1.ErrorInternalServerError("delete failed")
	}

	return nil
}

// Move 在看板列内重排指定列。anchor 策略与 BoardRepo.Move 一致。
func (r *ColumnRepo) Move(ctx context.Context, req *boardV1.MoveColumnRequest) (*boardV1.Column, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	tid, hasTenant := maybeTenantFromViewer(ctx)
	if !hasTenant {
		return nil, boardV1.ErrorBadRequest("tenant scope required to move column")
	}

	// 拉取 mover（被移动列），校验同租户，并取其所属看板。
	mover, err := r.entClient.Client().Column.Query().
		Where(column.IDEQ(req.GetId()), column.TenantIDEQ(tid)).
		Only(ctx)
	if err != nil {
		return nil, boardV1.ErrorNotFound("column not found")
	}
	bid, err := mover.QueryBoard().OnlyID(ctx)
	if err != nil {
		return nil, boardV1.ErrorInternalServerError("query parent board failed")
	}

	// 拉取该看板全部列（按 rank 升序）。
	allCols, err := r.entClient.Client().Column.Query().
		Where(column.HasBoardWith(board.IDEQ(bid)), column.TenantIDEQ(tid)).
		Order(ent.Asc(column.FieldRank)).
		All(ctx)
	if err != nil {
		r.log.Errorf("move column: query siblings failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("query siblings failed")
	}

	moverIdx := -1
	for i, c := range allCols {
		if c.ID == req.GetId() {
			moverIdx = i
			break
		}
	}
	if moverIdx < 0 {
		return nil, boardV1.ErrorNotFound("column not found")
	}

	lowRank, highRank, ok := r.resolveAnchorRanks(allCols, moverIdx, req)
	if !ok {
		return nil, boardV1.ErrorAnchorNotSibling("anchor column not in the same board scope")
	}

	newRank, betweenOk := lexorank.Between(lowRank, highRank)
	if !betweenOk {
		if rErr := r.rebalanceColumns(ctx, allCols, moverIdx, req, tid); rErr != nil {
			return nil, rErr
		}
		return r.getColumnByID(ctx, req.GetId(), tid, hasTenant)
	}

	builder := r.entClient.Client().Column.UpdateOneID(req.GetId())
	builder.Where(column.IDEQ(req.GetId()), column.TenantIDEQ(tid))
	if _, err := builder.SetRank(newRank).AddVersion(1).Save(ctx); err != nil {
		r.log.Errorf("move column: set rank failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("move column failed")
	}

	return r.getColumnByID(ctx, req.GetId(), tid, hasTenant)
}

func (r *ColumnRepo) resolveAnchorRanks(allCols []*ent.Column, moverIdx int, req *boardV1.MoveColumnRequest) (string, string, bool) {
	siblings := make([]*ent.Column, 0, len(allCols)-1)
	for i, c := range allCols {
		if i == moverIdx {
			continue
		}
		siblings = append(siblings, c)
	}

	var low, high string
	switch a := req.Anchor.(type) {
	case *boardV1.MoveColumnRequest_BeforeId:
		anchorIdx := -1
		for i, c := range siblings {
			if c.ID == a.BeforeId {
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
	case *boardV1.MoveColumnRequest_AfterId:
		anchorIdx := -1
		for i, c := range siblings {
			if c.ID == a.AfterId {
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
		if len(siblings) > 0 {
			low = derefRank(siblings[len(siblings)-1].Rank)
		}
	}
	return low, high, true
}

func (r *ColumnRepo) rebalanceColumns(ctx context.Context, allCols []*ent.Column, moverIdx int, req *boardV1.MoveColumnRequest, tid uint32) error {
	ordered := make([]*ent.Column, 0, len(allCols))
	mover := allCols[moverIdx]
	for i, c := range allCols {
		if i == moverIdx {
			continue
		}
		ordered = append(ordered, c)
	}

	insertAt := len(ordered)
	switch a := req.Anchor.(type) {
	case *boardV1.MoveColumnRequest_BeforeId:
		for i, c := range ordered {
			if c.ID == a.BeforeId {
				insertAt = i
				break
			}
		}
	case *boardV1.MoveColumnRequest_AfterId:
		for i, c := range ordered {
			if c.ID == a.AfterId {
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
		return boardV1.ErrorRebalanceFailed("rebalance columns failed")
	}

	for i, c := range ordered {
		if _, err := r.entClient.Client().Column.UpdateOneID(c.ID).
			Where(column.IDEQ(c.ID), column.TenantIDEQ(tid)).
			SetRank(newRanks[i]).
			Save(ctx); err != nil {
			r.log.Errorf("rebalance column %d failed: %s", c.ID, err.Error())
			return boardV1.ErrorRebalanceFailed("rebalance columns failed")
		}
	}
	return nil
}

func (r *ColumnRepo) getColumnByID(ctx context.Context, id uint32, tid uint32, hasTenant bool) (*boardV1.Column, error) {
	q := r.entClient.Client().Column.Query().Where(column.IDEQ(id))
	if hasTenant {
		q = q.Where(column.TenantIDEQ(tid))
	}
	t, err := q.Only(ctx)
	if err != nil {
		return nil, boardV1.ErrorNotFound("column not found")
	}
	return r.mapper.ToDTO(t), nil
}

func (r *ColumnRepo) allocateColumnTailRank(ctx context.Context, boardID uint32, tid uint32) (string, error) {
	last, err := r.entClient.Client().Column.Query().
		Where(column.HasBoardWith(board.IDEQ(boardID)), column.TenantIDEQ(tid)).
		Order(ent.Desc(column.FieldRank)).
		First(ctx)
	low := ""
	if err == nil && last != nil {
		low = derefRank(last.Rank)
	}
	rank, ok := lexorank.Between(low, "")
	if ok {
		return rank, nil
	}

	all, qErr := r.entClient.Client().Column.Query().
		Where(column.HasBoardWith(board.IDEQ(boardID)), column.TenantIDEQ(tid)).
		Order(ent.Asc(column.FieldRank)).
		All(ctx)
	if qErr != nil {
		return "", boardV1.ErrorInternalServerError("allocate tail rank failed")
	}
	newRanks := lexorank.Rebalance(len(all) + 1)
	if newRanks == nil {
		return "", boardV1.ErrorRebalanceFailed("allocate tail rank rebalance failed")
	}
	for i, c := range all {
		if _, err := r.entClient.Client().Column.UpdateOneID(c.ID).
			Where(column.IDEQ(c.ID), column.TenantIDEQ(tid)).
			SetRank(newRanks[i]).
			Save(ctx); err != nil {
			return "", boardV1.ErrorRebalanceFailed("allocate tail rank rebalance failed")
		}
	}
	return newRanks[len(newRanks)-1], nil
}
