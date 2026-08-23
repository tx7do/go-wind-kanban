import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_app/generated/api/app/service/v1/index.dart' as api;
import 'package:flutter_app/src/features/board/data/board_cache.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';

/// 看板列表页：在线拉取看板列表，断网回落到本地缓存列表。
class BoardListPage extends StatefulWidget {
  const BoardListPage({super.key});

  @override
  State<BoardListPage> createState() => _BoardListPageState();
}

class _BoardListPageState extends State<BoardListPage> {
  List<KanbanBoard> _boards = [];
  bool _offline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final resp = await GetIt.instance<api.ApiClient>()
          .boardService
          .list(api.PaginationPagingRequest(noPaging: true));
      final boards = (resp.items ?? [])
          .map(KanbanBoard.fromDto)
          .toList()
        ..sort((a, b) => (a.rank ?? '').compareTo(b.rank ?? ''));
      setState(() {
        _boards = boards;
        _offline = false;
      });
    } catch (_) {
      // 断网/未登录：回落缓存
      setState(() {
        _boards = GetIt.instance<BoardCache>().listBoards();
        _offline = true;
      });
    }
  }

  Future<void> _editBoard(
      BuildContext context, KanbanBoard board,
      {required bool editName}) async {
    final nameCtrl = TextEditingController(text: board.name);
    final descCtrl = TextEditingController(text: board.description ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editName ? '重命名看板' : '编辑描述'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (editName)
              TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '看板名称'))
            else
              TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '描述')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final data = api.BoardServiceV1Board(
        name: editName ? nameCtrl.text.trim() : board.name,
        description: editName ? board.description : descCtrl.text.trim(),
      );
      await GetIt.instance<api.ApiClient>().boardService.update(
            api.BoardServiceV1UpdateBoardRequest(
              id: board.id,
              data: data,
              expectedVersion: board.version,
              updateMask: editName ? 'name' : 'description',
            ),
          );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('更新失败: $e')));
    }
  }

  Future<void> _deleteBoard(
      BuildContext context, KanbanBoard board) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除看板'),
        content: Text('确定删除看板「${board.name}」？此操作不可撤销，列和卡片将一并删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await GetIt.instance<api.ApiClient>().boardService.delete(
            api.BoardServiceV1DeleteBoardRequest(id: board.id),
          );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  Future<void> _createBoard() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建看板'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: '看板名称')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述（可选）')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await GetIt.instance<api.ApiClient>().boardService.create(
        api.BoardServiceV1CreateBoardRequest(
          data: api.BoardServiceV1Board(
            name: nameCtrl.text.trim(),
            description: descCtrl.text.trim(),
          ),
        ),
      );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_offline ? '看板（离线）' : '看板'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _boards.isEmpty
          ? Center(
              child: Text(_error ?? '暂无看板'),
            )
          : ListView.separated(
              itemCount: _boards.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final b = _boards[i];
                return ListTile(
                  leading: const Icon(Icons.view_kanban_outlined),
                  title: Text(b.name),
                  subtitle: b.description?.isNotEmpty == true ? Text(b.description!) : null,
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Text('重命名')),
                      const PopupMenuItem(value: 'editDesc', child: Text('编辑描述')),
                      const PopupMenuItem(value: 'delete', child: Text('删除看板')),
                    ],
                    onSelected: (v) {
                      switch (v) {
                        case 'rename':
                          _editBoard(context, b, editName: true);
                        case 'editDesc':
                          _editBoard(context, b, editName: false);
                        case 'delete':
                          _deleteBoard(context, b);
                      }
                    },
                  ),
                  onTap: () => context.go('/board/${b.id}'),
                );
              },
            ),
      floatingActionButton: _offline
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('新建看板'),
              onPressed: _createBoard,
            ),
    );
  }
}
