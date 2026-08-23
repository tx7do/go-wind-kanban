import 'package:appflowy_board/appflowy_board.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_app/src/features/board/data/label_api.dart';
import 'package:flutter_app/src/features/board/logic/board_controller.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';
import 'package:flutter_app/src/features/board/pages/card_edit_dialog.dart';
import 'package:flutter_app/src/features/board/pages/card_metadata_strip.dart';
import 'package:flutter_app/src/features/board/pages/card_label_strip.dart';
import 'package:flutter_app/generated/l10n.dart';

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
        // toGroupId == fromGroupId（列不跨板移动）。
        // toIndex 是列拖拽后在列表中的新位置 → 传给 controller 作 anchor 解析。
        context.read<BoardController>().moveColumn(int.parse(fromGroupId), toIndex);
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
      ctrl.addGroup(AppFlowyGroupData<_AfColumnData>(
        id: col.id.toString(),
        name: col.name,
        customData: _AfColumnData(column: col),
        items: (grouped[col.id] ?? [])
            .map((c) => _AfCardItem(card: c))
            .toList(),
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
    return BlocBuilder<BoardController, KanbanBoardState?>(
      builder: (context, state) {
        if (state == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final fp = _fingerprint(state);
        if (_loadedBoardId != state.board.id || _afController == null || fp != _loadedFingerprint) {
          _afController?.dispose();
          _afController = _buildController(context, state);
          _loadedBoardId = state.board.id;
          _loadedFingerprint = fp;
        }
        if (_afController == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return AppFlowyBoard(
          controller: _afController!,
          footerBuilder: (context, column) => const SizedBox(height: 8),
          headerBuilder: (context, column) => _ColumnHeader(column: column),
          cardBuilder: (context, column, item) => _CardTile(
              key: ValueKey(item.id),
              item: item as _AfCardItem,
              boardState: state,
              boardController: context.read<BoardController>()),
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
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 16),
            onPressed: () => _showColumnOptions(context, data.column),
          ),
        ],
      ),
    );
  }

  void _showColumnOptions(BuildContext context, KanbanColumn col) {
    final loc = S.of(context);
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(loc.renameColumn),
              onTap: () {
                Navigator.pop(sheetCtx);
                _renameColumn(context, col);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(loc.deleteColumn, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDeleteColumn(context, col);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteColumn(BuildContext context, KanbanColumn col) {
    final loc = S.of(context);
    showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(loc.deleteColumn),
        content: Text(loc.deleteColumnConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: Text(loc.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: Text(loc.delete),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        context.read<BoardController>().deleteColumn(col.id);
      }
    });
  }

  void _renameColumn(BuildContext context, KanbanColumn col) {
    final loc = S.of(context);
    final ctrl = TextEditingController(text: col.name);
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(loc.renameColumn),
        content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(labelText: loc.columnName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: Text(loc.cancel)),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              Navigator.pop(dlgCtx);
              if (name.isNotEmpty && name != col.name) {
                context.read<BoardController>().renameColumn(col.id, name);
              }
            },
            child: Text(loc.save),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final _AfCardItem item;
  final KanbanBoardState boardState;
  final BoardController boardController;

  const _CardTile(
      {super.key,
      required this.item,
      required this.boardState,
      required this.boardController});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openEdit(context, item.card, boardState, boardController),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardMetadataStrip(card: item.card),
              CardLabelStrip(
                  labels: resolveCardLabels(boardState, item.card.id)),
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
      ),
    );
  }

  void _openEdit(BuildContext context, KanbanCard card, KanbanBoardState boardState, BoardController boardController) {
    showDialog<CardEditResult>(
      context: context,
      builder: (ctx) => CardEditDialog(
          card: card,
          boardLabels: boardState.labels,
          initialSelectedLabelIds:
              boardState.cardLabelAssociations[card.id]?.toSet() ?? <int>{}),
    ).then((result) async {
      if (result == null) return;
      final bc = boardController;
      if (result.delete) {
        await bc.deleteCard(card.id);
        return;
      }
      if (result.name != null && result.name != card.name) {
        await bc.renameCard(card.id, result.name!);
      }
      if (result.description != null && result.description != card.description) {
        await bc.updateCardDescription(card.id, result.description!);
      }
      if (result.labelIds != null) {
        try {
          await LabelApi().setCardLabels(card.id, result.labelIds!);
        } catch (_) {}
      }
      if (result.setDueDate != null) {
        await bc.setCardDueDate(card.id, result.setDueDate);
      } else if (result.clearDueDate) {
        await bc.setCardDueDate(card.id, null);
      }
      if (result.setArchived != null) {
        await bc.setCardArchived(card.id, result.setArchived!);
      }
      if (result.setCoverColor != null) {
        await bc.setCardCoverColor(card.id, result.setCoverColor);
      } else if (result.clearCoverColor) {
        await bc.setCardCoverColor(card.id, null);
      }
    });
  }
}

class _AfCardItem extends AppFlowyGroupItem {
  final KanbanCard card;

  _AfCardItem({required this.card});

  @override
  String get id => card.id.toString();
}

class _AfColumnData {
  final KanbanColumn column;

  _AfColumnData({required this.column});
}
