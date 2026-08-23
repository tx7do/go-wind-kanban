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

	"go-wind-kanban/app/core/service/internal/data/ent"
	"go-wind-kanban/app/core/service/internal/data/ent/card"
	"go-wind-kanban/app/core/service/internal/data/ent/column"
	"go-wind-kanban/app/core/service/internal/data/ent/predicate"

	boardV1 "go-wind-kanban/api/gen/go/board/service/v1"

	"go-wind-kanban/pkg/lexorank"
)

type CardRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper

	mapper *mapper.CopierMapper[boardV1.Card, ent.Card]

	repository *entCrud.Repository[
		ent.CardQuery, ent.CardSelect,
		ent.CardCreate, ent.CardCreateBulk,
		ent.CardUpdate, ent.CardUpdateOne,
		ent.CardDelete,
		predicate.Card,
		boardV1.Card, ent.Card,
	]
}

func NewCardRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *CardRepo {
	repo := &CardRepo{
		log:       ctx.NewLoggerHelper("card/repo/core-service"),
		entClient: entClient,
		mapper:    mapper.NewCopierMapper[boardV1.Card, ent.Card](),
	}

	repo.init()

	return repo
}

func (r *CardRepo) init() {
	r.repository = entCrud.NewRepository[
		ent.CardQuery, ent.CardSelect,
		ent.CardCreate, ent.CardCreateBulk,
		ent.CardUpdate, ent.CardUpdateOne,
		ent.CardDelete,
		predicate.Card,
		boardV1.Card, ent.Card,
	](r.mapper)

	r.mapper.AppendConverters(copierutil.NewTimeStringConverterPair())
	r.mapper.AppendConverters(copierutil.NewTimeTimestamppbConverterPair())
}

// cardToDTO 将 ent.Card 转换为 proto DTO。供 board_repo.GetBoardSnapshot 复用。
func cardToDTO(c *ent.Card) *boardV1.Card {
	if c == nil {
		return nil
	}
	return cardMapperInstance.ToDTO(c)
}

var cardMapperInstance = func() *mapper.CopierMapper[boardV1.Card, ent.Card] {
	m := mapper.NewCopierMapper[boardV1.Card, ent.Card]()
	m.AppendConverters(copierutil.NewTimeStringConverterPair())
	m.AppendConverters(copierutil.NewTimeTimestamppbConverterPair())
	return m
}()

func (r *CardRepo) Count(ctx context.Context, whereCond []func(s *sql.Selector)) (int, error) {
	builder := r.entClient.Client().Card.Query()
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

func (r *CardRepo) List(ctx context.Context, req *paginationV1.PagingRequest) (*boardV1.ListCardResponse, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	builder := r.entClient.Client().Card.Query()

	ret, err := r.repository.ListWithPaging(ctx, builder, builder.Clone(), req)
	if err != nil {
		return nil, err
	}
	if ret == nil {
		return &boardV1.ListCardResponse{Total: 0, Items: nil}, nil
	}

	return &boardV1.ListCardResponse{
		Total: ret.Total,
		Items: ret.Items,
	}, nil
}

func (r *CardRepo) IsExist(ctx context.Context, id uint32) (bool, error) {
	exist, err := r.entClient.Client().Card.Query().
		Where(card.IDEQ(id)).
		Exist(ctx)
	if err != nil {
		r.log.Errorf("query exist failed: %s", err.Error())
		return false, boardV1.ErrorInternalServerError("query exist failed")
	}
	return exist, nil
}

func (r *CardRepo) Get(ctx context.Context, req *boardV1.GetCardRequest) (*boardV1.Card, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	builder := r.entClient.Client().Card.Query()

	var whereCond []func(s *sql.Selector)
	switch req.QueryBy.(type) {
	default:
	case *boardV1.GetCardRequest_Id:
		whereCond = append(whereCond, card.IDEQ(req.GetId()))
	}

	dto, err := r.repository.Get(ctx, builder, req.GetViewMask(), whereCond...)
	if err != nil {
		return nil, err
	}

	return dto, err
}

func (r *CardRepo) Create(ctx context.Context, req *boardV1.CreateCardRequest) (*boardV1.Card, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	// 校验父列存在且属当前租户，防跨租户注入。
	tid, hasTenant := maybeTenantFromViewer(ctx)
	if !hasTenant {
		return nil, boardV1.ErrorBadRequest("tenant scope required to create card")
	}
	parentColumn, err := r.entClient.Client().Column.Query().
		Where(column.IDEQ(req.Data.GetColumnId()), column.TenantIDEQ(tid)).
		Only(ctx)
	if err != nil {
		return nil, boardV1.ErrorNotFound("column not found")
	}
	// board_id 冗余自列：取父列所属看板，保持反规范化一致。
	parentBoardID, err := parentColumn.QueryBoard().OnlyID(ctx)
	if err != nil {
		return nil, boardV1.ErrorInternalServerError("query parent board failed")
	}

	// 初始 rank：追加到列卡片末尾。
	newRank, err := r.allocateCardTailRank(ctx, parentColumn.ID, tid)
	if err != nil {
		return nil, err
	}

	builder := r.entClient.Client().Card.Create().
		SetNillableTenantID(req.Data.TenantId).
		SetNillableName(req.Data.Name).
		SetNillableDescription(req.Data.Description).
		SetArchived(req.Data.GetArchived()).
		SetNillableCoverColor(req.Data.CoverColor).
		SetRank(newRank).
		SetVersion(1).
		SetNillableCreatedBy(req.Data.CreatedBy).
		SetCreatedAt(time.Now()).
		SetColumnID(parentColumn.ID).
		SetBoardID(parentBoardID)

	if req.Data.DueDate != nil {
		builder.SetDueDate(req.Data.DueDate.AsTime())
	}

	t, err := builder.Save(ctx)
	if err != nil {
		r.log.Errorf("insert card failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("insert card failed")
	}

	return r.mapper.ToDTO(t), nil
}

func (r *CardRepo) Update(ctx context.Context, req *boardV1.UpdateCardRequest) (*boardV1.Card, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	if req.GetAllowMissing() {
		exist, err := r.IsExist(ctx, req.GetId())
		if err != nil {
			return nil, err
		}
		if !exist {
			createReq := &boardV1.CreateCardRequest{Data: req.Data}
			createReq.Data.CreatedBy = createReq.Data.UpdatedBy
			createReq.Data.UpdatedBy = nil
			return r.Create(ctx, createReq)
		}
	}

	tid, hasTenant := maybeTenantFromViewer(ctx)
	callerUserID, hasUser := viewerUserIDFromContext(ctx)
	builder := r.entClient.Client().Debug().Card.UpdateOneID(req.GetId())
	builder.Where(card.IDEQ(req.GetId()))
	if hasTenant {
		builder.Where(card.TenantIDEQ(tid))
	}
	if req.GetExpectedVersion() > 0 {
		builder.Where(card.VersionEQ(req.GetExpectedVersion()))
	}
	result, err := r.repository.UpdateOne(ctx, builder, req.Data, req.GetUpdateMask(),
		func(dto *boardV1.Card) {
			builder.
				SetNillableName(req.Data.Name).
				SetNillableDescription(req.Data.Description).
				SetNillableCoverColor(req.Data.CoverColor).
				SetUpdatedAt(time.Now())

			if req.Data.DueDate != nil {
				builder.SetDueDate(req.Data.DueDate.AsTime())
			}
			if req.Data.Archived != nil {
				builder.SetArchived(*req.Data.Archived)
			}

			if hasUser {
				builder.SetUpdatedBy(callerUserID)
			}
		},
		func(s *sql.Selector) {
			s.Where(sql.EQ(card.FieldID, req.GetId()))
		},
	)

	// 乐观锁命中失败：版本不匹配，返回 409。
	if err == nil && result == nil && req.GetExpectedVersion() > 0 {
		return nil, boardV1.ErrorConflict("card version conflict: expected=%d", req.GetExpectedVersion())
	}

	// 乐观锁预埋：每次 Update 成功后 version+1。
	if result != nil {
		if vErr := r.bumpVersion(ctx, req.GetId(), tid, hasTenant); vErr != nil {
			r.log.Errorf("card version bump failed: %s", vErr.Error())
		}
	}

	return result, err
}

func (r *CardRepo) bumpVersion(ctx context.Context, id uint32, tid uint32, hasTenant bool) error {
	builder := r.entClient.Client().Card.UpdateOneID(id)
	builder.Where(card.IDEQ(id))
	if hasTenant {
		builder.Where(card.TenantIDEQ(tid))
	}
	if _, err := builder.AddVersion(1).Save(ctx); err != nil {
		return err
	}
	return nil
}

func (r *CardRepo) Delete(ctx context.Context, req *boardV1.DeleteCardRequest) error {
	if req == nil {
		return boardV1.ErrorBadRequest("invalid parameter")
	}

	tid, hasTenant := maybeTenantFromViewer(ctx)
	delBuilder := r.entClient.Client().Card.Delete()
	delBuilder.Where(card.IDEQ(req.GetId()))
	if hasTenant {
		delBuilder.Where(card.TenantIDEQ(tid))
	}
	if _, err := delBuilder.Exec(ctx); err != nil {
		if ent.IsNotFound(err) {
			return boardV1.ErrorNotFound("card not found")
		}

		r.log.Errorf("delete one data failed: %s", err.Error())

		return boardV1.ErrorInternalServerError("delete failed")
	}

	return nil
}

// Move 在列内重排或跨列移动卡片。
//
// target_column_id 为 0/缺省时表示同列重排；非 0 时跨列移动到目标列。
//
// anchor 策略：
//   - before_id=X：新 rank = Between(X 的前驱 rank, X 的 rank)（目标列内）
//   - after_id=X ：新 rank = Between(X 的 rank, X 的后驱 rank)（目标列内）
//   - 无 anchor  ：追加到目标列末尾
//
// 跨列移动时，card.board_id 同步更新为目标列的 board_id，保持反规范化一致。
// Between 耗尽时对目标列整列 Rebalance。
func (r *CardRepo) Move(ctx context.Context, req *boardV1.MoveCardRequest) (*boardV1.Card, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	tid, hasTenant := maybeTenantFromViewer(ctx)
	if !hasTenant {
		return nil, boardV1.ErrorBadRequest("tenant scope required to move card")
	}

	// 取 mover（被移动卡片），校验同租户，并取其当前列。
	mover, err := r.entClient.Client().Card.Query().
		Where(card.IDEQ(req.GetId()), card.TenantIDEQ(tid)).
		Only(ctx)
	if err != nil {
		return nil, boardV1.ErrorNotFound("card not found")
	}
	moverColID, err := mover.QueryColumn().OnlyID(ctx)
	if err != nil {
		return nil, boardV1.ErrorInternalServerError("query source column failed")
	}

	// 确定目标列：同列重排用 mover 当前列；跨列移动校验目标列同租户。
	targetColID := moverColID
	var targetBoardID uint32
	if req.GetTargetColumnId() != 0 {
		tc, cerr := r.entClient.Client().Column.Query().
			Where(column.IDEQ(req.GetTargetColumnId()), column.TenantIDEQ(tid)).
			Only(ctx)
		if cerr != nil {
			return nil, boardV1.ErrorNotFound("target column not found")
		}
		targetColID = tc.ID
		if targetBoardID, cerr = tc.QueryBoard().OnlyID(ctx); cerr != nil {
			return nil, boardV1.ErrorInternalServerError("query target board failed")
		}
	}

	// 取目标列全部卡片（按 rank 升序），用于 anchor 定位与重排。
	allCards, err := r.entClient.Client().Card.Query().
		Where(card.HasColumnWith(column.IDEQ(targetColID)), card.TenantIDEQ(tid)).
		Order(ent.Asc(card.FieldRank)).
		All(ctx)
	if err != nil {
		r.log.Errorf("move card: query siblings failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("query siblings failed")
	}

	moverIdx := -1
	for i, c := range allCards {
		if c.ID == req.GetId() {
			moverIdx = i
			break
		}
	}
	// 同列重排时 mover 必在 allCards 内；跨列移动时不在（属源列），视为新插入。
	if moverIdx < 0 && targetColID == moverColID {
		return nil, boardV1.ErrorNotFound("card not found")
	}

	lowRank, highRank, ok := r.resolveAnchorRanks(allCards, moverIdx, req)
	if !ok {
		return nil, boardV1.ErrorAnchorNotSibling("anchor card not in the target column scope")
	}

	newRank, betweenOk := lexorank.Between(lowRank, highRank)
	if !betweenOk {
		if rErr := r.rebalanceCards(ctx, allCards, moverIdx, req, targetColID, targetBoardID, moverColID, tid); rErr != nil {
			return nil, rErr
		}
		return r.getCardByID(ctx, req.GetId(), tid, hasTenant)
	}

	builder := r.entClient.Client().Card.UpdateOneID(req.GetId())
	builder.Where(card.IDEQ(req.GetId()), card.TenantIDEQ(tid))
	if req.GetExpectedVersion() > 0 {
		builder.Where(card.VersionEQ(req.GetExpectedVersion()))
	}
	builder.SetRank(newRank)
	// 跨列移动：同步 board_id 与 column_id，保持反规范化一致。
	if targetColID != moverColID {
		builder.SetColumnID(targetColID)
		builder.SetBoardID(targetBoardID)
	}
	if _, err := builder.AddVersion(1).Save(ctx); err != nil {
		if ent.IsNotFound(err) && req.GetExpectedVersion() > 0 {
			return nil, boardV1.ErrorConflict("card version conflict: expected=%d", req.GetExpectedVersion())
		}
		r.log.Errorf("move card: set rank failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("move card failed")
	}

	return r.getCardByID(ctx, req.GetId(), tid, hasTenant)
}

func (r *CardRepo) resolveAnchorRanks(allCards []*ent.Card, moverIdx int, req *boardV1.MoveCardRequest) (string, string, bool) {
	// 跨列移动时 mover 不在 allCards 内（moverIdx=-1），全部卡片为同级；
	// 同列重排时剔除 mover。
	siblings := make([]*ent.Card, 0, len(allCards))
	for i, c := range allCards {
		if i == moverIdx {
			continue
		}
		siblings = append(siblings, c)
	}

	var low, high string
	switch a := req.Anchor.(type) {
	case *boardV1.MoveCardRequest_BeforeId:
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
	case *boardV1.MoveCardRequest_AfterId:
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

// rebalanceCards 对目标列整列重排，mover 按 anchor 策略插入目标位置后
// 全列重新分配均匀 rank；跨列移动时 mover 的归属在重排中一并更新。
func (r *CardRepo) rebalanceCards(ctx context.Context, allCards []*ent.Card, moverIdx int, req *boardV1.MoveCardRequest, targetColID, targetBoardID, moverColID, tid uint32) error {
	ordered := make([]*ent.Card, 0, len(allCards)+1)
	for i, c := range allCards {
		if i == moverIdx {
			continue
		}
		ordered = append(ordered, c)
	}

	// 跨列移动：mover 不在 allCards 内，需重查实体用于插入。
	var mover *ent.Card
	var err error
	if moverIdx < 0 {
		mover, err = r.entClient.Client().Card.Query().
			Where(card.IDEQ(req.GetId()), card.TenantIDEQ(tid)).
			Only(ctx)
		if err != nil {
			return boardV1.ErrorNotFound("card not found")
		}
	} else {
		mover = allCards[moverIdx]
	}

	insertAt := len(ordered)
	switch a := req.Anchor.(type) {
	case *boardV1.MoveCardRequest_BeforeId:
		for i, c := range ordered {
			if c.ID == a.BeforeId {
				insertAt = i
				break
			}
		}
	case *boardV1.MoveCardRequest_AfterId:
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
		return boardV1.ErrorRebalanceFailed("rebalance cards failed")
	}

	for i, c := range ordered {
		b := r.entClient.Client().Card.UpdateOneID(c.ID).
			Where(card.IDEQ(c.ID), card.TenantIDEQ(tid)).
			SetRank(newRanks[i])
		// mover 的跨列移动在重排时一并更新归属与版本。
		if c.ID == mover.ID && targetColID != moverColID {
			b.SetColumnID(targetColID)
			b.SetBoardID(targetBoardID)
		}
		if _, err := b.Save(ctx); err != nil {
			r.log.Errorf("rebalance card %d failed: %s", c.ID, err.Error())
			return boardV1.ErrorRebalanceFailed("rebalance cards failed")
		}
	}
	return nil
}

func (r *CardRepo) getCardByID(ctx context.Context, id uint32, tid uint32, hasTenant bool) (*boardV1.Card, error) {
	q := r.entClient.Client().Card.Query().Where(card.IDEQ(id))
	if hasTenant {
		q = q.Where(card.TenantIDEQ(tid))
	}
	t, err := q.Only(ctx)
	if err != nil {
		return nil, boardV1.ErrorNotFound("card not found")
	}
	return r.mapper.ToDTO(t), nil
}

func (r *CardRepo) allocateCardTailRank(ctx context.Context, colID uint32, tid uint32) (string, error) {
	last, err := r.entClient.Client().Card.Query().
		Where(card.HasColumnWith(column.IDEQ(colID)), card.TenantIDEQ(tid)).
		Order(ent.Desc(card.FieldRank)).
		First(ctx)
	low := ""
	if err == nil && last != nil {
		low = derefRank(last.Rank)
	}
	rank, ok := lexorank.Between(low, "")
	if ok {
		return rank, nil
	}

	all, qErr := r.entClient.Client().Card.Query().
		Where(card.HasColumnWith(column.IDEQ(colID)), card.TenantIDEQ(tid)).
		Order(ent.Asc(card.FieldRank)).
		All(ctx)
	if qErr != nil {
		return "", boardV1.ErrorInternalServerError("allocate tail rank failed")
	}
	newRanks := lexorank.Rebalance(len(all) + 1)
	if newRanks == nil {
		return "", boardV1.ErrorRebalanceFailed("allocate tail rank rebalance failed")
	}
	for i, c := range all {
		if _, err := r.entClient.Client().Card.UpdateOneID(c.ID).
			Where(card.IDEQ(c.ID), card.TenantIDEQ(tid)).
			SetRank(newRanks[i]).
			Save(ctx); err != nil {
			return "", boardV1.ErrorRebalanceFailed("allocate tail rank rebalance failed")
		}
	}
	return newRanks[len(newRanks)-1], nil
}
