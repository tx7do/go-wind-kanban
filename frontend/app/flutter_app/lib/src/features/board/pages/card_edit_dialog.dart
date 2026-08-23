import 'package:flutter/material.dart';

import 'package:flutter_app/src/core/utils/color_utils.dart';
import 'package:flutter_app/src/features/board/data/label_api.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';
import 'package:flutter_app/generated/l10n.dart';

/// 卡片编辑结果。
class CardEditResult {
  final bool delete;
  final String? name;
  final String? description;
  final List<int>? labelIds;
  final DateTime? setDueDate;
  final bool? setArchived;
  final String? setCoverColor;
  final bool clearDueDate;
  final bool clearCoverColor;

  CardEditResult({
    this.delete = false,
    this.name,
    this.description,
    this.labelIds,
    this.setDueDate,
    this.setArchived,
    this.setCoverColor,
    this.clearDueDate = false,
    this.clearCoverColor = false,
  });
}

/// 卡片编辑对话框：名称 + 描述 + 标签选择 + 删除。
///
/// 宽屏与窄屏共用。
class CardEditDialog extends StatefulWidget {
  final KanbanCard card;
  final List<KanbanLabel> boardLabels;
  final Set<int> initialSelectedLabelIds;

  const CardEditDialog({
    super.key,
    required this.card,
    required this.boardLabels,
    required this.initialSelectedLabelIds,
  });

  @override
  State<CardEditDialog> createState() => _CardEditDialogState();
}

class _CardEditDialogState extends State<CardEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late Set<int> _selected;
  late String? _coverColor;
  late DateTime? _dueDate;
  late bool _archived;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.card.name);
    _descCtrl = TextEditingController(text: widget.card.description ?? '');
    _selected = Set<int>.from(widget.initialSelectedLabelIds);
    _coverColor = widget.card.coverColor;
    _dueDate = widget.card.dueDate;
    _archived = widget.card.archived;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    return AlertDialog(
      title: Text(loc.editCard),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: loc.cardTitle),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: InputDecoration(labelText: loc.description),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(loc.coverColor, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              _CoverColorPicker(
                selected: _coverColor,
                onChanged: (c) => setState(() => _coverColor = c),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(loc.dueDate, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              _DueDateField(
                value: _dueDate,
                onChanged: (d) => setState(() => _dueDate = d),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                dense: true,
                title: Text(loc.archived),
                value: _archived,
                onChanged: (v) => setState(() => _archived = v),
              ),
              if (widget.boardLabels.isNotEmpty) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(loc.labels, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              color: parseNamedColor(label.color),
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
          child: Text(loc.delete, style: const TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: () {
            DateTime? setDueDate;
            bool clearDueDate = false;
            if (_dueDate != widget.card.dueDate) {
              if (_dueDate == null) {
                clearDueDate = true;
              } else {
                setDueDate = _dueDate;
              }
            }
            bool? setArchived;
            if (_archived != widget.card.archived) {
              setArchived = _archived;
            }
            String? setCoverColor;
            bool clearCoverColor = false;
            if (_coverColor != widget.card.coverColor) {
              if (_coverColor == null) {
                clearCoverColor = true;
              } else {
                setCoverColor = _coverColor;
              }
            }
            Navigator.pop(
                context,
                CardEditResult(
                  name: _nameCtrl.text.trim(),
                  description: _descCtrl.text,
                  labelIds: _selected.toList(),
                  setDueDate: setDueDate,
                  clearDueDate: clearDueDate,
                  setArchived: setArchived,
                  setCoverColor: setCoverColor,
                  clearCoverColor: clearCoverColor,
                ));
          },
          child: Text(loc.save),
        ),
      ],
    );
  }
}

/// 封面色选择器：一行命名色块按钮，选中态高亮，附"清除"按钮。
class _CoverColorPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _CoverColorPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...namedColors.keys.map((name) {
          final isSel = selected == name;
          return GestureDetector(
            onTap: () => onChanged(isSel ? null : name),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: parseNamedColor(name),
                border: isSel ? Border.all(color: Colors.black, width: 2) : null,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
        TextButton(
          onPressed: selected == null ? null : () => onChanged(null),
          child: Text(S.of(context).clear),
        ),
      ],
    );
  }
}

/// 截止日期字段：显示当前日期，按钮触发 [showDatePicker]，附"清除"按钮。
class _DueDateField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DueDateField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) onChanged(picked);
          },
          child: Text(value == null
              ? S.of(context).selectDate
              : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}',
              style: const TextStyle(decoration: TextDecoration.underline)),
        ),
        TextButton(
          onPressed: value == null ? null : () => onChanged(null),
          child: Text(S.of(context).clear),
        ),
      ],
    );
  }
}
