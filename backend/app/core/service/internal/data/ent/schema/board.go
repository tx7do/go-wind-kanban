package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// Board holds the schema definition for the Board entity.
type Board struct {
	ent.Schema
}

func (Board) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sys_kanban_boards",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("看板表"),
	}
}

// Fields of the Board.
func (Board) Fields() []ent.Field {
	return []ent.Field{
		field.String("name").
			Comment("看板名称").
			NotEmpty().
			Optional().
			Nillable(),

		field.String("description").
			Comment("看板描述").
			Optional().
			Nillable(),

		field.String("rank").
			Comment("租户内排序权重，Lexorank 字典序字符串，服务端维护").
			Optional().
			Nillable(),

		field.Uint32("version").
			Comment("乐观锁版本号，每次更新自增").
			Default(1),
	}
}

// Mixin of the Board.
func (Board) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.OperatorID{},
		mixin.TenantID[uint32]{},
	}
}

// Edges of the Board.
func (Board) Edges() []ent.Edge {
	return []ent.Edge{
		edge.To("columns", Column.Type).
			Required().
			Annotations(entsql.Annotation{
				OnDelete: entsql.Cascade,
			}).
			StorageKey(edge.Column("board_id")),

		edge.To("cards", Card.Type).
			Required().
			Annotations(entsql.Annotation{
				OnDelete: entsql.Cascade,
			}).
			StorageKey(edge.Column("board_id")),
	}
}
// Indexes of the Board.
func (Board) Indexes() []ent.Index {
	return []ent.Index{
		// 租户内看板列表按 rank 排序
		index.Fields("tenant_id", "rank").
			StorageKey("idx_sys_kanban_boards_tenant_rank"),

		// 租户时间区间分页
		index.Fields("tenant_id", "created_at").
			StorageKey("idx_sys_kanban_boards_tenant_created_at"),
	}
}
