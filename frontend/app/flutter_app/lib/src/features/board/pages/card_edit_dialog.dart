import 'package:flutter/material.dart';

import 'package:flutter_app/src/features/board/data/label_api.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';

/// 卡片编辑结果。
class CardEditResult {
  final bool delete;
  final String? name;
  final String? description;
  final List<int>? labelIds;

  CardEditResult({this.delete = false, this.name, this.description, this.labelIds});
}

/// 卡片编辑对话框：名称 + 描述 + 标签选择 + 删除。
///
/// 宽屏与窄屏共用。
class CardEditDialog extends StatefulWidget {
  final KanbanCard card;
  final List<KanbanLabel> boardLabels;

  const CardEditDialog({
    super.key,
    required this.card,
    required this.boardLabels,
  });

  @override
  State<CardEditDialog> createState() => _CardEditDialogState();
}

class _CardEditDialogState extends State<CardEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late Set<int> _selected;
  bool _loadingLabels = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.card.name);
    _descCtrl = TextEditingController(text: widget.card.description ?? '');
    _selected = {};
    _loadCardLabels();
  }

  Future<void> _loadCardLabels() async {
    try {
      final labels = await LabelApi().getCardLabels(widget.card.id);
      _selected = labels.map((l) => l.id).toSet();
    } catch (_) {
      _selected = {};
    }
    setState(() => _loadingLabels = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑卡片'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: '描述'),
                maxLines: 3,
              ),
              if (!_loadingLabels && widget.boardLabels.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('标签', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...widget.boardLabels.map((label) => CheckboxListTile(
                      dense: true,
                      value: _selected.contains(label.id),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(label.id);
                          } else {
                            _selected.remove(label.id);
                          }
                        });
                      },
                      title: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _parseColor(label.color),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(label.name),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, CardEditResult(delete: true)),
          child: const Text('删除', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
              context,
              CardEditResult(
                name: _nameCtrl.text.trim(),
                description: _descCtrl.text,
                labelIds: _selected.toList(),
              )),
          child: const Text('保存'),
        ),
      ],
    );
  }

  Color _parseColor(String s) {
    const named = {
      'red': 0xFFEF4444, 'orange': 0xFFF97316, 'amber': 0xFFF59E0B,
      'yellow': 0xFFEAB308, 'lime': 0xFF84CC16, 'green': 0xFF22C55E,
      'emerald': 0xFF10B981, 'teal': 0xFF14B8A6, 'cyan': 0xFF06B6D4,
      'sky': 0xFF0EA5E9, 'blue': 0xFF3B82F6, 'indigo': 0xFF6366F1,
      'violet': 0xFF8B5CF6, 'purple': 0xFFA855F7, 'fuchsia': 0xFFD946EF,
      'pink': 0xFFEC4899, 'rose': 0xFFF43F5E, 'gray': 0xFF6B7280,
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
