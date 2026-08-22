package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"

	"github.com/tx7do/go-crud/entgo/mixin"
)

// CardLabel holds the schema definition for the CardLabel entity（卡片-标签多对多关联表）。
type CardLabel struct {
	ent.Schema
}

func (CardLabel) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.Annotation{
			Table:     "sys_kanban_card_labels",
			Charset:   "utf8mb4",
			Collation: "utf8mb4_bin",
		},
		entsql.WithComments(true),
		schema.Comment("卡片标签关联表"),
	}
}

// Fields of the CardLabel.
func (CardLabel) Fields() []ent.Field {
	return []ent.Field{
		field.Uint32("card_id").
			Comment("卡片ID").
			Optional(),

		field.Uint32("label_id").
			Comment("标签ID").
			Optional(),
	}
}

// Mixin of the CardLabel.
func (CardLabel) Mixin() []ent.Mixin {
	return []ent.Mixin{
		mixin.AutoIncrementId{},
		mixin.TimeAt{},
		mixin.OperatorID{},
	}
}

// Indexes of the CardLabel.
func (CardLabel) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("card_id", "label_id").
			Unique().
			StorageKey("uix_sys_kanban_card_labels_card_label"),
	}
}
