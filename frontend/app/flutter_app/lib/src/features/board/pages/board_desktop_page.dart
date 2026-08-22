import 'package:appflowy_board/appflowy_board.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_app/src/features/board/logic/board_controller.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';

/// 桌面/宽屏看板：AppFlowyBoard 横向多列 + 鼠标流畅拖拽 + 吸附动画。
///
/// 拖拽回调基于“拖拽前状态”解析卡片（fromIndex 处的卡），
/// 位置语义交由 BoardController.moveCard 统一换算 anchor。
class BoardDesktopPage extends StatefulWidget {
  const BoardDesktopPage({super.key});

  @override
  State<BoardDesktopPage> createState() => _BoardDesktopPageState();
}

class _BoardDesktopPageState extends State<BoardDesktopPage> {
  AppFlowyBoardController? _afController;
  int _loadedBoardId = 0;
  int _loadedFingerprint = -1;

  @override
  void dispose() {
    _afController?.dispose();
    super.dispose();
  }

  AppFlowyBoardController _buildController(BuildContext context, KanbanBoardState state) {
    final ctrl = AppFlowyBoardController(
      onMoveGroup: (fromGroupId, fromIndex, toGroupId, toIndex) {
        // 列重排（ColumnService.Move 随后接入：暂按展示序接受）
      },
      onMoveGroupItem: (groupId, fromIndex, toIndex) {
        final card = _cardAt(context, groupId, fromIndex);
        if (card != null) {
          context.read<BoardController>().moveCard(card.id, int.parse(groupId), toIndex);
        }
      },
      onMoveGroupItemToGroup: (fromGroupId, fromIndex, toGroupId, toIndex) {
        final card = _cardAt(context, fromGroupId, fromIndex);
        if (card != null) {
          context.read<BoardController>().moveCard(card.id, int.parse(toGroupId), toIndex);
        }
      },
    );
    final grouped = state.cardsByColumn;
    for (final col in state.columns) {
      ctrl.addGroup(_AfColumnData(
        column: col,
        items: (grouped[col.id] ?? [])
            .map((c) => _AfCardItem(card: c))
            .toList(growable: false),
      ));
    }
    return ctrl;
  }

  /// 拖拽前状态下取列内第 index 张卡。
  KanbanCard? _cardAt(BuildContext context, String groupId, int index) {
    final state = context.read<BoardController>().state;
    if (state == null) return null;
    final grouped = state.cardsByColumn;
    final cards = grouped[int.parse(groupId)] ?? const <KanbanCard>[];
    if (index < 0 || index >= cards.length) return null;
    return cards[index];
  }

  int _fingerprint(KanbanBoardState s) =>
      Object.hashAll([s.columns.length, s.cards.length, ...s.cards.map((c) => c.version)]);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BoardController, KanbanBoardState?>(
      listenWhen: (prev, next) =>
          next != null && _fingerprint(prev ?? next) != _fingerprint(next),
      listener: (context, state) {
        if (state == null) return;
        final fp = _fingerprint(state);
        if (_loadedBoardId != state.board.id || _afController == null || fp != _loadedFingerprint) {
          _afController?.dispose();
          _afController = _buildController(context, state);
          _loadedBoardId = state.board.id;
          _loadedFingerprint = fp;
          setState(() {});
        }
      },
      builder: (context, state) {
        if (state == null || _afController == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return AppFlowyBoard(
          controller: _afController!,
          footerBuilder: (context, column) => const SizedBox(height: 8),
          headerBuilder: (context, column) => _ColumnHeader(column: column),
          cardBuilder: (context, column, item) => _CardTile(item: item as _AfCardItem),
          groupConstraints: const BoxConstraints(maxWidth: 260),
        );
      },
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  final AppFlowyGroupData column;

  const _ColumnHeader({required this.column});

  @override
  Widget build(BuildContext context) {
    final data = column.customData as _AfColumnData;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              data.column.name,
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${column.items.length}'),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final _AfCardItem item;

  const _CardTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.card.name,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.card.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                item.card.description!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AfCardItem extends AppFlowyGroupItem {
  final KanbanCard card;

  _AfCardItem({required this.card});

  @override
  String get id => card.id.toString();
}

class _AfColumnData extends AppFlowyGroupData {
  final KanbanColumn column;

  _AfColumnData({required this.column, required List<_AfCardItem> items})
      : super(id: column.id.toString(), name: column.name, items: items);
}
