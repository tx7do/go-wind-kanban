import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_app/src/features/board/data/label_api.dart';
import 'package:flutter_app/src/features/board/logic/board_controller.dart';
import 'package:flutter_app/src/features/board/pages/card_edit_dialog.dart';
import 'package:flutter_app/src/features/board/pages/card_metadata_strip.dart';
import 'package:flutter_app/src/features/board/pages/card_label_strip.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';
import 'package:flutter_app/generated/l10n.dart';

/// 手机/窄屏看板：TabBarView 单列分页 + 长按激活拖拽（ReorderableListView）。
class BoardMobilePage extends StatefulWidget {
  const BoardMobilePage({super.key});

  @override
  State<BoardMobilePage> createState() => _BoardMobilePageState();
}

class _BoardMobilePageState extends State<BoardMobilePage>
    with TickerProviderStateMixin {
  // build 会无条件读取 _tabController，0 列的空看板也必须有一个已初始化的控制器。
  late TabController _tabController;
  int _columnCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _syncTabs(int count) {
    if (count != _columnCount) {
      _tabController.dispose();
      _columnCount = count;
      _tabController = TabController(length: count, vsync: this);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BoardController, KanbanBoardState?>(
      buildWhen: (prev, next) =>
          prev?.columns.length != next?.columns.length ||
          prev?.columns.map((c) => c.name).join() != next?.columns.map((c) => c.name).join(),
      builder: (context, state) {
        if (state == null) return const SizedBox.shrink();
        _syncTabs(state.columns.length);

        return Column(
          children: [
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: state.columns
                  .map((c) => Tab(
                        text: '${c.name} (${_countOf(context, c.id)})',
                      ))
                  .toList(),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: state.columns.map((col) => _ColumnList(columnId: col.id)).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  int _countOf(BuildContext context, int columnId) {
    final s = context.read<BoardController>().state;
    return s?.cards.where((c) => c.columnId == columnId).length ?? 0;
  }
}

/// 单列卡片列表：长按拖拽重排（ReorderableListView）。
class _ColumnList extends StatelessWidget {
  final int columnId;

  const _ColumnList({required this.columnId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BoardController, KanbanBoardState?>(
      builder: (context, state) {
        if (state == null) return const SizedBox.shrink();
        final grouped = state.cardsByColumn;
        final cards = grouped[columnId] ?? const <KanbanCard>[];
        final col = state.columns.where((c) => c.id == columnId).firstOrNull;
        if (col == null) return const SizedBox.shrink();

        return Column(
          children: [
            _MobileColumnHeader(column: col),
            Expanded(
              child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
          itemCount: cards.length,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex -= 1;
            context.read<BoardController>().moveCard(
                  cards[oldIndex].id,
                  columnId,
                  newIndex,
                );
          },
          proxyDecorator: (child, index, animation) => AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final elev = Tween<double>(begin: 0, end: 6)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut))
                  .value;
              return Material(elevation: elev, borderRadius: BorderRadius.circular(8), child: child);
            },
            child: child,
          ),
          itemBuilder: (context, index) {
            final card = cards[index];
            return Container(
              key: ValueKey('card_${card.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CardMetadataStrip(card: card),
                  CardLabelStrip(labels: resolveCardLabels(state, card.id)),
                  GestureDetector(
                    onTap: () => _editCard(context, card),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(card.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                                if (card.description?.isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Text(card.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ],
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editCard(BuildContext context, KanbanCard card) async {
    final bc = context.read<BoardController>();
    final boardState = bc.state;
    if (boardState == null) return;

    final result = await showDialog<CardEditResult>(
      context: context,
      builder: (ctx) => CardEditDialog(
        card: card,
        boardLabels: boardState.labels,
        initialSelectedLabelIds:
            boardState.cardLabelAssociations[card.id]?.toSet() ?? <int>{},
      ),
    );

    if (result == null) return;

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
  }

}

/// 窄屏列头：提供重命名/删除入口，对齐宽屏功能。
class _MobileColumnHeader extends StatelessWidget {
  final KanbanColumn column;

  const _MobileColumnHeader({required this.column});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              column.name,
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 16),
            onPressed: () => _showColumnOptions(context, column),
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
}
