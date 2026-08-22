import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_app/src/features/board/logic/board_controller.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';

/// 手机/窄屏看板：TabBarView 单列分页 + 长按激活拖拽（ReorderableListView）。
class BoardMobilePage extends StatefulWidget {
  const BoardMobilePage({super.key});

  @override
  State<BoardMobilePage> createState() => _BoardMobilePageState();
}

class _BoardMobilePageState extends State<BoardMobilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _columnCount = 0;

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

        return ReorderableListView.builder(
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
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                title: Text(card.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: card.description?.isNotEmpty == true
                    ? Text(card.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
                onTap: () => _editCard(context, card),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editCard(BuildContext context, KanbanCard card) async {
    final controller = TextEditingController(text: card.name);
    final renamed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑卡片'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, '__delete__'),
            child: const Text('删除'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (renamed == null || renamed.isEmpty) return;
    final bc = context.read<BoardController>();
    if (renamed == '__delete__') {
      await bc.deleteCard(card.id);
    } else if (renamed != card.name) {
      await bc.renameCard(card.id, renamed);
    }
  }
}
