import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_app/src/core/utils/color_utils.dart';
import 'package:flutter_app/src/features/board/data/label_api.dart';
import 'package:flutter_app/src/features/board/logic/board_controller.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';
import 'package:flutter_app/generated/l10n.dart';

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
    final loc = S.of(context);
    final name = await _prompt(loc.labelName, '');
    if (name == null || name.isEmpty) return;
    final color = await _prompt(loc.colorHint, 'gray');
    if (color == null) return;
    try {
      await _api.create(widget.boardId, name, color);
      await _load();
      await context.read<BoardController>().refreshLabels();
    } catch (e) {
      _toast(loc.createFailed);
    }
  }

  Future<void> _edit(KanbanLabel label) async {
    final loc = S.of(context);
    final name = await _prompt(loc.labelName, label.name);
    if (name == null) return;
    final color = await _prompt(loc.color, label.color);
    if (color == null) return;
    try {
      await _api.update(label.id, name, color);
      await _load();
      await context.read<BoardController>().refreshLabels();
    } catch (e) {
      _toast(loc.updateFailed);
    }
  }

  Future<void> _delete(KanbanLabel label) async {
    final loc = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.deleteLabel),
        content: Text(loc.deleteLabelConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.delete)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete(label.id);
      await _load();
      await context.read<BoardController>().refreshLabels();
    } catch (e) {
      _toast(loc.deleteFailed);
    }
  }

  Future<String?> _prompt(String label, String initial) {
    final loc = S.of(context);
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(loc.confirm)),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    return Drawer(
      width: 320,
      child: Column(
        children: [
          AppBar(
            title: Text(loc.labelManagement),
            actions: [
              IconButton(onPressed: _create, icon: const Icon(Icons.add)),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_labels.isEmpty)
            Expanded(child: Center(child: Text(loc.noLabels)))
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
                        color: parseNamedColor(label.color),
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
}
