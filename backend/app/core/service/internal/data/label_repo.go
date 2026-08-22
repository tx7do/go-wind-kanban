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
	"go-wind-kanban/app/core/service/internal/data/ent/board"
	"go-wind-kanban/app/core/service/internal/data/ent/cardlabel"
	"go-wind-kanban/app/core/service/internal/data/ent/label"
	"go-wind-kanban/app/core/service/internal/data/ent/predicate"

	boardV1 "go-wind-kanban/api/gen/go/board/service/v1"
)

type LabelRepo struct {
	entClient *entCrud.EntClient[*ent.Client]
	log       *log.Helper

	mapper *mapper.CopierMapper[boardV1.Label, ent.Label]

	repository *entCrud.Repository[
		ent.LabelQuery, ent.LabelSelect,
		ent.LabelCreate, ent.LabelCreateBulk,
		ent.LabelUpdate, ent.LabelUpdateOne,
		ent.LabelDelete,
		predicate.Label,
		boardV1.Label, ent.Label,
	]
}

func NewLabelRepo(ctx *bootstrap.Context, entClient *entCrud.EntClient[*ent.Client]) *LabelRepo {
	repo := &LabelRepo{
		log:       ctx.NewLoggerHelper("label/repo/core-service"),
		entClient: entClient,
		mapper:    mapper.NewCopierMapper[boardV1.Label, ent.Label](),
	}
	repo.init()
	return repo
}

func (r *LabelRepo) init() {
	r.repository = entCrud.NewRepository[
		ent.LabelQuery, ent.LabelSelect,
		ent.LabelCreate, ent.LabelCreateBulk,
		ent.LabelUpdate, ent.LabelUpdateOne,
		ent.LabelDelete,
		predicate.Label,
		boardV1.Label, ent.Label,
	](r.mapper)

	r.mapper.AppendConverters(copierutil.NewTimeStringConverterPair())
	r.mapper.AppendConverters(copierutil.NewTimeTimestamppbConverterPair())
}

func (r *LabelRepo) List(ctx context.Context, req *paginationV1.PagingRequest) (*boardV1.ListLabelResponse, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	builder := r.entClient.Client().Label.Query()
	ret, err := r.repository.ListWithPaging(ctx, builder, builder.Clone(), req)
	if err != nil {
		return nil, err
	}
	if ret == nil {
		return &boardV1.ListLabelResponse{Total: 0, Items: nil}, nil
	}
	return &boardV1.ListLabelResponse{Total: ret.Total, Items: ret.Items}, nil
}

func (r *LabelRepo) IsExist(ctx context.Context, id uint32) (bool, error) {
	exist, err := r.entClient.Client().Label.Query().Where(label.IDEQ(id)).Exist(ctx)
	if err != nil {
		return false, boardV1.ErrorInternalServerError("query exist failed")
	}
	return exist, nil
}

func (r *LabelRepo) Get(ctx context.Context, req *boardV1.GetLabelRequest) (*boardV1.Label, error) {
	if req == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	builder := r.entClient.Client().Label.Query()
	var whereCond []func(s *sql.Selector)
	switch req.QueryBy.(type) {
	default:
	case *boardV1.GetLabelRequest_Id:
		whereCond = append(whereCond, label.IDEQ(req.GetId()))
	}
	return r.repository.Get(ctx, builder, req.GetViewMask(), whereCond...)
}

func (r *LabelRepo) Create(ctx context.Context, req *boardV1.CreateLabelRequest) (*boardV1.Label, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}

	// 校验父看板存在且属当前租户，防跨租户注入。
	tid, hasTenant := maybeTenantFromViewer(ctx)
	if !hasTenant {
		return nil, boardV1.ErrorBadRequest("tenant scope required to create label")
	}
	exists, err := r.entClient.Client().Board.Query().
		Where(board.IDEQ(req.Data.GetBoardId()), board.TenantIDEQ(tid)).Exist(ctx)
	if err != nil || !exists {
		return nil, boardV1.ErrorNotFound("board not found")
	}

	t, err := r.entClient.Client().Label.Create().
		SetNillableTenantID(req.Data.TenantId).
		SetNillableName(req.Data.Name).
		SetNillableColor(req.Data.Color).
		SetBoardID(req.Data.GetBoardId()).
		SetNillableCreatedBy(req.Data.CreatedBy).
		SetVersion(1).
		SetCreatedAt(time.Now()).
		Save(ctx)
	if err != nil {
		r.log.Errorf("insert label failed: %s", err.Error())
		return nil, boardV1.ErrorInternalServerError("insert label failed")
	}
	return r.mapper.ToDTO(t), nil
}

func (r *LabelRepo) Update(ctx context.Context, req *boardV1.UpdateLabelRequest) (*boardV1.Label, error) {
	if req == nil || req.Data == nil {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	if req.GetAllowMissing() {
		exist, err := r.IsExist(ctx, req.GetId())
		if err != nil {
			return nil, err
		}
		if !exist {
			createReq := &boardV1.CreateLabelRequest{Data: req.Data}
			createReq.Data.CreatedBy = createReq.Data.UpdatedBy
			createReq.Data.UpdatedBy = nil
			return r.Create(ctx, createReq)
		}
	}

	tid, hasTenant := maybeTenantFromViewer(ctx)
	callerUserID, hasUser := viewerUserIDFromContext(ctx)
	builder := r.entClient.Client().Label.UpdateOneID(req.GetId())
	builder.Where(label.IDEQ(req.GetId()))
	if hasTenant {
		builder.Where(label.TenantIDEQ(tid))
	}
	if req.GetExpectedVersion() > 0 {
		builder.Where(label.VersionEQ(req.GetExpectedVersion()))
	}
	result, err := r.repository.UpdateOne(ctx, builder, req.Data, req.GetUpdateMask(),
		func(dto *boardV1.Label) {
			builder.
				SetNillableName(req.Data.Name).
				SetNillableColor(req.Data.Color).
				SetUpdatedAt(time.Now())
			if hasUser {
				builder.SetUpdatedBy(callerUserID)
			}
		},
		func(s *sql.Selector) {
			s.Where(sql.EQ(label.FieldID, req.GetId()))
		},
	)
	if err == nil && result == nil && req.GetExpectedVersion() > 0 {
		return nil, boardV1.ErrorConflict("label version conflict: expected=%d", req.GetExpectedVersion())
	}
	return result, err
}

func (r *LabelRepo) Delete(ctx context.Context, req *boardV1.DeleteLabelRequest) error {
	if req == nil {
		return boardV1.ErrorBadRequest("invalid parameter")
	}
	tid, hasTenant := maybeTenantFromViewer(ctx)
	delBuilder := r.entClient.Client().Label.Delete()
	delBuilder.Where(label.IDEQ(req.GetId()))
	if hasTenant {
		delBuilder.Where(label.TenantIDEQ(tid))
	}
	if _, err := delBuilder.Exec(ctx); err != nil {
		if ent.IsNotFound(err) {
			return boardV1.ErrorNotFound("label not found")
		}
		return boardV1.ErrorInternalServerError("delete failed")
	}
	// 级联清理关联（无 DB 外键时的手工一致性行为）
	_, _ = r.entClient.Client().CardLabel.Delete().
		Where(cardlabel.LabelIDEQ(req.GetId())).Exec(ctx)
	return nil
}

// SetCardLabels 全量替换卡片标签集合（差量增删，事务内）。
func (r *LabelRepo) SetCardLabels(ctx context.Context, req *boardV1.SetCardLabelsRequest) error {
	if req == nil || req.GetCardId() == 0 {
		return boardV1.ErrorBadRequest("invalid parameter")
	}
	tid, hasTenant := maybeTenantFromViewer(ctx)

	tx, err := r.entClient.Client().Tx(ctx)
	if err != nil {
		return boardV1.ErrorInternalServerError("start transaction failed")
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
			return
		}
		_ = tx.Commit()
	}()

	// 现有集合
	current, err := tx.CardLabel.Query().
		Where(cardlabel.CardIDEQ(req.GetCardId())).All(ctx)
	if err != nil {
		return boardV1.ErrorInternalServerError("query card labels failed")
	}
	currentSet := make(map[uint32]struct{}, len(current))
	for _, cl := range current {
		currentSet[cl.LabelID] = struct{}{}
	}
	targetSet := make(map[uint32]struct{}, len(req.GetLabelIds()))
	for _, id := range req.GetLabelIds() {
		targetSet[id] = struct{}{}
	}

	// 差量校验：目标标签必须同租户且存在
	if len(targetSet) > 0 {
		ids := make([]uint32, 0, len(targetSet))
		for id := range targetSet {
			ids = append(ids, id)
		}
		lq := tx.Label.Query().Where(label.IDIn(ids...))
		if hasTenant {
			lq = lq.Where(label.TenantIDEQ(tid))
		}
		count, qErr := lq.Count(ctx)
		if qErr != nil || count != len(ids) {
			return boardV1.ErrorBadRequest("label not found or cross-tenant")
		}
	}

	// 删除多余
	for _, cl := range current {
		if _, keep := targetSet[cl.LabelID]; !keep {
			if _, dErr := tx.CardLabel.Delete().Where(cardlabel.IDEQ(cl.ID)).Exec(ctx); dErr != nil {
				err = dErr
				return boardV1.ErrorInternalServerError("set card labels failed")
			}
		}
	}
	// 新增缺失
	for id := range targetSet {
		if _, has := currentSet[id]; !has {
			if _, cErr := tx.CardLabel.Create().
				SetCardID(req.GetCardId()).
				SetLabelID(id).
				SetCreatedAt(time.Now()).
				Save(ctx); cErr != nil {
				err = cErr
				return boardV1.ErrorInternalServerError("set card labels failed")
			}
		}
	}
	return nil
}

// GetCardLabels 查询卡片标签集合。
func (r *LabelRepo) GetCardLabels(ctx context.Context, req *boardV1.GetCardLabelsRequest) (*boardV1.ListLabelResponse, error) {
	if req == nil || req.GetCardId() == 0 {
		return nil, boardV1.ErrorBadRequest("invalid parameter")
	}
	tid, hasTenant := maybeTenantFromViewer(ctx)

	q := r.entClient.Client().Label.Query().
		Where(func(s *sql.Selector) {
			// label.id IN (SELECT label_id FROM card_labels WHERE card_id = ?)
			sub := sql.Select(cardlabel.FieldLabelID).
				From(sql.Table(cardlabel.Table)).
				Where(sql.EQ(cardlabel.FieldCardID, req.GetCardId()))
			s.Where(sql.In(label.FieldID, sub))
		})
	if hasTenant {
		q = q.Where(label.TenantIDEQ(tid))
	}
	labels, err := q.All(ctx)
	if err != nil {
		return nil, boardV1.ErrorInternalServerError("query card labels failed")
	}
	resp := &boardV1.ListLabelResponse{Total: uint64(len(labels))}
	for _, l := range labels {
		resp.Items = append(resp.Items, r.mapper.ToDTO(l))
	}
	return resp, nil
}
