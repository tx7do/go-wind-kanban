import 'package:flutter/material.dart';

import 'package:flutter_app/src/core/utils/color_utils.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';
import 'package:flutter_app/src/features/board/data/label_api.dart';

/// 解析卡片关联的标签定义集合。
///
/// 从 board state 的关联映射与标签定义集合交集得出。
/// 仅返回既在关联中、又在标签定义中存在的标签。
List<KanbanLabel> resolveCardLabels(KanbanBoardState state, int cardId) {
  final ids = state.cardLabelAssociations[cardId];
  if (ids == null || ids.isEmpty) return const [];
  final byId = {for (final l in state.labels) l.id: l};
  return ids
      .map((id) => byId[id])
      .whereType<KanbanLabel>()
      .toList(growable: false);
}

/// 卡片正面标签条：水平排列的圆角色块，每块对应卡片上的一项标签。
///
/// 颜色取自标签定义（state.labels），关联取自 state.cardLabelAssociations。
/// 调用方负责从 board state 解析出 [labels] 后传入。
class CardLabelStrip extends StatelessWidget {
  /// 当前卡片关联的标签定义（已在调用方按关联过滤）。
  final List<KanbanLabel> labels;

  const CardLabelStrip({super.key, required this.labels});

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: labels
            .map((l) => _LabelChip(colorName: l.color))
            .toList(growable: false),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  final String colorName;
  const _LabelChip({required this.colorName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 8,
      decoration: BoxDecoration(
        color: parseNamedColor(colorName),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
