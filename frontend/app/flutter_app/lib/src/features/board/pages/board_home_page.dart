import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'package:flutter_app/src/features/board/data/board_cache.dart';
import 'package:flutter_app/src/features/board/logic/board_controller.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';
import 'package:flutter_app/src/features/board/pages/board_desktop_page.dart';
import 'package:flutter_app/src/features/board/pages/board_mobile_page.dart';
import 'package:flutter_app/src/features/board/pages/label_manager_drawer.dart';

/// 看板主页：响应式分派。
///
/// 宽屏（桌面/Web，>=900dp）：AppFlowyBoard 横向多列看板，
/// 鼠标流畅拖拽 + 吸附动画；窄屏（手机，<900dp）：TabBarView 单列分页，
/// 长按激活拖拽。
class BoardHomePage extends StatefulWidget {
  final int boardId;

  const BoardHomePage({super.key, required this.boardId});

  @override
  State<BoardHomePage> createState() => _BoardHomePageState();
}

class _BoardHomePageState extends State<BoardHomePage> {
  late final BoardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BoardController(
      cache: GetIt.instance<BoardCache>(),
      pending: GetIt.instance<PendingOps>(),
    );
    _controller.load(widget.boardId);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BoardController>.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: BlocBuilder<BoardController, KanbanBoardState?>(
            buildWhen: (a, b) => a?.board.name != b?.board.name,
            builder: (context, state) => Text(state?.board.name ?? ''),
          ),
          actions: [
            // 标签管理入口
            Builder(
              builder: (scaffoldCtx) => IconButton(
                icon: const Icon(Icons.label_outline),
                tooltip: '标签管理',
                onPressed: () => Scaffold.of(scaffoldCtx).openEndDrawer(),
              ),
            ),
            // 离线徽标：断网或存在待同步操作时显示
            BlocBuilder<BoardController, KanbanBoardState?>(
              builder: (context, _) {
                final c = context.read<BoardController>();
                if (!c.isOffline && c.pendingCount == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Chip(
                    avatar: const Icon(Icons.cloud_off, size: 16),
                    label: Text(c.isOffline
                        ? '离线'
                        : '待同步 ${c.pendingCount}'),
                  ),
                );
              },
            ),
          ],
        ),
        endDrawer: LabelManagerDrawer(boardId: widget.boardId),
        body: BlocBuilder<BoardController, KanbanBoardState?>(
          builder: (context, state) {
            if (state == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.columns.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('看板暂无列'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('新建列'),
                      onPressed: () => _promptCreateColumn(context),
                    ),
                  ],
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return wide
                    ? const BoardDesktopPage()
                    : const BoardMobilePage();
              },
            );
          },
        ),
        floatingActionButton: BlocBuilder<BoardController, KanbanBoardState?>(
          builder: (context, state) {
            if (state == null) return const SizedBox.shrink();
            if (state.columns.isEmpty) {
              return FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('新建列'),
                onPressed: () => _promptCreateColumn(context),
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  icon: const Icon(Icons.view_column),
                  label: const Text('新建列'),
                  onPressed: () => _promptCreateColumn(context),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  icon: const Icon(Icons.add),
                  label: const Text('新建卡片'),
                  onPressed: () => _promptCreateCard(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _promptCreateColumn(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建列'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '列名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    if (confirmed == true && name.isNotEmpty) {
      await _controller.createColumn(name);
    }
  }

  Future<void> _promptCreateCard(BuildContext context) async {
    final state = _controller.state;
    if (state == null) return;

    final nameCtrl = TextEditingController();
    var columnId = state.columns.first.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('新建卡片'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: '卡片标题'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: columnId,
                decoration: const InputDecoration(labelText: '目标列'),
                items: state.columns
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setDialog(() => columnId = v ?? columnId),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    if (confirmed == true && name.isNotEmpty) {
      await _controller.createCard(columnId, name);
    }
  }
}
