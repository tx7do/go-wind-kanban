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

// Card holds the schema definition for the Card entity.
type Card struct {
	ent.Schema
}

func (Card) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sys_kanban_cards",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("看板卡片表"),
	}
}

// Fields of the Card.
func (Card) Fields() []ent.Field {
	return []ent.Field{
		field.String("name").
			Comment("卡片标题").
			NotEmpty().
			Optional().
			Nillable(),

		field.String("description").
			Comment("卡片描述").
			Optional().
			Nillable(),

		field.String("rank").
			Comment("列内排序权重，Lexorank 字典序字符串，服务端维护").
			Optional().
			Nillable(),

		field.Uint32("version").
			Comment("乐观锁版本号，每次更新自增").
			Default(1),

		field.Uint32("column_id").
			Comment("所属列ID").
			Optional(),

		field.Uint32("board_id").
			Comment("所属看板ID，冗余自列，供看板级查询，服务端维护").
			Optional(),
	}
}

// Mixin of the Card.
func (Card) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.OperatorID{},
		mixin.TenantID[uint32]{},
	}
}

// Edges of the Card.
func (Card) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("column", Column.Type).
			Ref("cards").
			Field("column_id").
			Unique(),

		edge.From("board", Board.Type).
			Ref("cards").
			Field("board_id").
			Unique(),
	}
}

// Indexes of the Card.
func (Card) Indexes() []ent.Index {
	return []ent.Index{
		// 单列卡片按 rank 排序 + Move 邻居查找
		index.Fields("column_id", "rank").
			StorageKey("idx_sys_kanban_cards_column_rank"),

		// 看板快照单次查询、按列分组内存聚合
		index.Fields("board_id", "column_id", "rank").
			StorageKey("idx_sys_kanban_cards_board_column_rank"),
	}
}
