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

// Column holds the schema definition for the Column entity.
type Column struct {
	ent.Schema
}

func (Column) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sys_kanban_columns",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("看板列表"),
	}
}

// Fields of the Column.
func (Column) Fields() []ent.Field {
	return []ent.Field{
		field.String("name").
			Comment("列名称").
			NotEmpty().
			Optional().
			Nillable(),

		field.String("color").
			Comment("列颜色标识").
			Optional().
			Nillable(),

		field.String("rank").
			Comment("看板内排序权重，Lexorank 字典序字符串，服务端维护").
			Optional().
			Nillable(),

		field.Uint32("version").
			Comment("乐观锁版本号，每次更新自增").
			Default(1),

		field.Uint32("board_id").
			Comment("所属看板ID").
			Optional(),
	}
}

// Mixin of the Column.
func (Column) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.OperatorID{},
		mixin.TenantID[uint32]{},
	}
}

// Edges of the Column.
func (Column) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("board", Board.Type).
			Ref("columns").
			Field("board_id").
			Unique(),

		edge.To("cards", Card.Type).
			Annotations(entsql.Annotation{
				OnDelete: entsql.Cascade,
			}),
	}
}

// Indexes of the Column.
func (Column) Indexes() []ent.Index {
	return []ent.Index{
		// 看板内列列表按 rank 排序
		index.Fields("board_id", "rank").
			StorageKey("idx_sys_kanban_columns_board_rank"),
	}
}
