import 'package:flutter/material.dart';

import 'package:flutter_app/src/core/utils/color_utils.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';

/// 卡片正面的元数据装饰：封面色条（顶部）+ 截止日期徽章（底部）。
///
/// 桌面与移动端共用。标签条由 [CardLabelStrip] 在调用方按需追加。
class CardMetadataStrip extends StatelessWidget {
  final KanbanCard card;

  const CardMetadataStrip({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (card.coverColor != null && card.coverColor!.isNotEmpty)
          _CoverBar(colorName: card.coverColor!),
        if (card.dueDate != null) ...[
          const SizedBox(height: 8),
          _DueDateBadge(due: card.dueDate!),
        ],
      ],
    );
  }
}

/// 封面色条：卡片顶部全宽色块，取命名色。
class _CoverBar extends StatelessWidget {
  final String colorName;
  const _CoverBar({required this.colorName});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Container(
        width: double.infinity,
        height: 6,
        color: parseNamedColor(colorName),
      ),
    );
  }
}

/// 截止日期徽章：按距今天数着色。
///
/// 红色=已过期，琥珀=24h 内，灰=其余。
class _DueDateBadge extends StatelessWidget {
  final DateTime due;
  const _DueDateBadge({required this.due});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = due.difference(DateTime(now.year, now.month, now.day)).inDays;
    final Color badgeColor;
    if (diff < 0) {
      badgeColor = const Color(0xFFEF4444);
    } else if (diff == 0) {
      badgeColor = const Color(0xFFF59E0B);
    } else {
      badgeColor = const Color(0xFF6B7280);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
