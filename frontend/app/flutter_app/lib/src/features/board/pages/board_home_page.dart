import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_app/src/core/constants/router_paths.dart';
import 'package:flutter_app/src/core/utils/responsive_utils.dart';
import 'package:flutter_app/src/features/board/data/board_cache.dart';
import 'package:flutter_app/src/features/board/logic/board_controller.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';
import 'package:flutter_app/src/features/board/pages/board_desktop_page.dart';
import 'package:flutter_app/src/features/board/pages/board_mobile_page.dart';
import 'package:flutter_app/src/features/board/pages/label_manager_drawer.dart';
import 'package:flutter_app/generated/l10n.dart';

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
          // 窄屏无 Shell 顶栏，需在此提供返回看板列表的入口；
          // 宽屏由 WebShellLayout 顶栏承担，此处留空。
          leading: ResponsiveUtils.isMobile(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => context.go(AppRoutePath.initial),
                )
              : null,
          title: BlocBuilder<BoardController, KanbanBoardState?>(
            buildWhen: (a, b) => a?.board.name != b?.board.name,
            builder: (context, state) {
              final name = state?.board.name ?? '';
              // 文本内容变化时强制重建 RenderParagraph，避开 TextPainter
              // _rebuildParagraphForPaint 就地重建导致的 debugSize!=size 断言。
              return Text(name, key: ValueKey<String>(name));
            },
          ),
          actions: [
            // 标签管理入口
            Builder(
              builder: (scaffoldCtx) => IconButton(
                icon: const Icon(Icons.label_outline),
                tooltip: S.of(context).labelManagement,
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
                        ? S.of(context).offline
                        : S.of(context).pendingSync),
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
                    Text(S.of(context).boardNoColumns),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(S.of(context).newColumn),
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
                label: Text(S.of(context).newColumn),
                onPressed: () => _promptCreateColumn(context),
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'board_fab_new_column',
                  icon: const Icon(Icons.view_column),
                  label: Text(S.of(context).newColumn),
                  onPressed: () => _promptCreateColumn(context),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  heroTag: 'board_fab_new_card',
                  icon: const Icon(Icons.add),
                  label: Text(S.of(context).newCard),
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
    final loc = S.of(context);
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.newColumn),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(labelText: loc.columnName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.create)),
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

    final loc = S.of(context);
    final nameCtrl = TextEditingController();
    var columnId = state.columns.first.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(loc.newCard),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: loc.cardTitle),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: columnId,
                decoration: InputDecoration(labelText: loc.targetColumn),
                items: state.columns
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setDialog(() => columnId = v ?? columnId),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.create),
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
