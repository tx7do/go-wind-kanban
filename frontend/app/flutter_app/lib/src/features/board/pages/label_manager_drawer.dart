import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_app/src/features/board/data/label_api.dart';
import 'package:flutter_app/src/features/board/logic/board_controller.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';

/// 看板标签管理抽屉。
///
/// 展示当前看板的标签集合，支持创建/重命名/改色/删除。
/// 标签定义是看板级资源，与卡片关联独立。
class LabelManagerDrawer extends StatefulWidget {
  final int boardId;

  const LabelManagerDrawer({super.key, required this.boardId});

  @override
  State<LabelManagerDrawer> createState() => _LabelManagerDrawerState();
}

class _LabelManagerDrawerState extends State<LabelManagerDrawer> {
  final _api = LabelApi();
  List<KanbanLabel> _labels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _labels = await _api.listByBoard(widget.boardId);
    } catch (_) {
      _labels = [];
    }
    setState(() => _loading = false);
  }

  Future<void> _create() async {
    final name = await _prompt('标签名称', '');
    if (name == null || name.isEmpty) return;
    final color = await _prompt('颜色（如 red/blue/#hex）', 'gray');
    if (color == null) return;
    try {
      await _api.create(widget.boardId, name, color);
      await _load();
    } catch (e) {
      _toast('创建失败: $e');
    }
  }

  Future<void> _edit(KanbanLabel label) async {
    final name = await _prompt('标签名称', label.name);
    if (name == null) return;
    final color = await _prompt('颜色', label.color);
    if (color == null) return;
    try {
      await _api.update(label.id, name, color);
      await _load();
    } catch (e) {
      _toast('更新失败: $e');
    }
  }

  Future<void> _delete(KanbanLabel label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确定删除标签「${label.name}」？此操作会移除所有卡片上的该标签关联。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete(label.id);
      await _load();
    } catch (e) {
      _toast('删除失败: $e');
    }
  }

  Future<String?> _prompt(String label, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('确定')),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 320,
      child: Column(
        children: [
          AppBar(
            title: const Text('标签管理'),
            actions: [
              IconButton(onPressed: _create, icon: const Icon(Icons.add)),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_labels.isEmpty)
            const Expanded(child: Center(child: Text('暂无标签')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _labels.length,
                itemBuilder: (ctx, i) {
                  final label = _labels[i];
                  return ListTile(
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _parseColor(label.color),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    title: Text(label.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _edit(label),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () => _delete(label),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// 将颜色字符串解析为 Color（支持命名色与 #hex）。
  Color _parseColor(String s) {
    const named = {
      'red': 0xFFEF4444,
      'orange': 0xFFF97316,
      'amber': 0xFFF59E0B,
      'yellow': 0xFFEAB308,
      'lime': 0xFF84CC16,
      'green': 0xFF22C55E,
      'emerald': 0xFF10B981,
      'teal': 0xFF14B8A6,
      'cyan': 0xFF06B6D4,
      'sky': 0xFF0EA5E9,
      'blue': 0xFF3B82F6,
      'indigo': 0xFF6366F1,
      'violet': 0xFF8B5CF6,
      'purple': 0xFFA855F7,
      'fuchsia': 0xFFD946EF,
      'pink': 0xFFEC4899,
      'rose': 0xFFF43F5E,
      'gray': 0xFF6B7280,
      'slate': 0xFF64748B,
    };
    if (named.containsKey(s)) return Color(named[s]!);
    if (s.startsWith('#') && s.length == 7) {
      final hex = int.tryParse(s.substring(1), radix: 16);
      if (hex != null) return Color(0xFF000000 | hex);
    }
    return const Color(0xFF6B7280);
  }
}
