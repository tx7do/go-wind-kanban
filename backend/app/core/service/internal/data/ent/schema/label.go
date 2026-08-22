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

// Label holds the schema definition for the Label entity（看板级标签，Planka 同款）。
type Label struct {
	ent.Schema
}

func (Label) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sys_kanban_labels",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("看板标签表"),
	}
}

// Fields of the Label.
func (Label) Fields() []ent.Field {
	return []ent.Field{
		field.String("name").
			Comment("标签名称").
			NotEmpty().
			Optional().
			Nillable(),

		field.String("color").
			Comment("标签颜色").
			Optional().
			Nillable(),

		field.Uint32("board_id").
			Comment("所属看板ID").
			Optional(),

		field.Uint32("version").
			Comment("乐观锁版本号，每次更新自增").
			Default(1),
	}
}

// Mixin of the Label.
func (Label) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.OperatorID{},
		mixin.TenantID[uint32]{},
	}
}

// Edges of the Label.
func (Label) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("board", Board.Type).
			Ref("labels").
			Field("board_id").
			Unique(),

	}
}

// Indexes of the Label.
func (Label) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("board_id").
			StorageKey("idx_sys_kanban_labels_board"),
	}
}
