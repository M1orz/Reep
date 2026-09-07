import 'package:flutter/material.dart';

import '../models/workout_plan.dart';
import '../theme.dart';

class WorkoutEditorPage extends StatefulWidget {
  const WorkoutEditorPage({super.key, this.existingPlan});

  /// 如果传入已有计划，则为编辑模式；否则为新建模式。
  final WorkoutPlan? existingPlan;

  @override
  State<WorkoutEditorPage> createState() => _WorkoutEditorPageState();
}

class _WorkoutEditorPageState extends State<WorkoutEditorPage> {
  late List<WorkoutModule> _modules;
  late final TextEditingController _nameController;
  final _scrollController = ScrollController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _modules = widget.existingPlan?.modules.toList() ?? const [];
    _nameController = TextEditingController(
      text: widget.existingPlan?.name ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.existingPlan != null ? '编辑计划' : '新建计划',
          style: text.titleMedium,
        ),
        actions: [
          if (_modules.isNotEmpty)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving ? '保存中...' : '保存',
                style: const TextStyle(color: AppColors.accent),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 计划名称
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _nameController,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: '计划名称，如：间歇跑 8×400',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.surfaceHigh),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ),

          // 模块列表区域（可滚动）
          Expanded(
            child: _modules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 48,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '还没有模块，点击下方添加',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    scrollController: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: _modules.length,
                    onReorder: _reorderModule,
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, index) {
                      final module = _modules[index];
                      return _ModuleTile(
                        key: ValueKey('module-$index'),
                        module: module,
                        index: index,
                        onEdit: () => _editModule(index),
                        onDelete: () => _deleteModule(index),
                      );
                    },
                  ),
          ),

          // 底部添加按钮（固定）
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.surfaceHigh)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TypeSelector(
                    onSelected: (type) {
                      setState(() {
                        _modules = [
                          ..._modules,
                          WorkoutModule(
                            type: type,
                            unit:
                                type == WorkoutModuleType.run ||
                                    type == WorkoutModuleType.rest
                                ? WorkoutModuleUnit.meters
                                : WorkoutModuleUnit.minutes,
                            value:
                                type == WorkoutModuleType.run ||
                                    type == WorkoutModuleType.rest
                                ? 800
                                : 5,
                          ),
                        ];
                      });
                      _scrollToBottom();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _reorderModule(int oldIndex, int newIndex) {
    setState(() {
      final list = _modules.toList();
      if (newIndex > oldIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      _modules = list;
    });
  }

  void _editModule(int index) {
    final module = _modules[index];
    showDialog(
      context: context,
      builder: (ctx) => _ModuleEditDialog(module: module),
    ).then((result) {
      if (result != null && mounted) {
        setState(() {
          final list = _modules.toList();
          list[index] = result;
          _modules = list;
        });
      }
    });
  }

  void _deleteModule(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模块'),
        content: const Text('确定要删除这个模块吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                final list = _modules.toList()..removeAt(index);
                _modules = list;
              });
            },
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_modules.isEmpty) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先填写计划名称'),
          backgroundColor: AppColors.surfaceHigh,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final plan = (widget.existingPlan ?? WorkoutPlan(name: name, modules: []))
        .copyWith(name: name, modules: _modules);
    final saved = await WorkoutPlanRepository().upsert(plan);

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(saved);
  }
}

/// 模块类型选择器（底部弹出）。
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.onSelected});

  final void Function(WorkoutModuleType type) onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('添加模块', style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    ...WorkoutModuleType.values.map((type) {
                      return ListTile(
                        leading: Icon(_typeIcon(type), color: AppColors.accent),
                        title: Text(_typeName(type)),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onSelected(type);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.surfaceHigh),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        alignment: Alignment.center,
        child: const Text(
          '+ 添加模块',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}

IconData _typeIcon(WorkoutModuleType type) => switch (type) {
  WorkoutModuleType.warmUp => Icons.local_fire_department,
  WorkoutModuleType.run => Icons.directions_run,
  WorkoutModuleType.rest => Icons.coffee,
  WorkoutModuleType.coolDown => Icons.spa,
};

String _typeName(WorkoutModuleType type) => switch (type) {
  WorkoutModuleType.warmUp => '热身',
  WorkoutModuleType.run => '跑',
  WorkoutModuleType.rest => '休息',
  WorkoutModuleType.coolDown => '放松',
};

/// 模块列表项。
class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    super.key,
    required this.module,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkoutModule module;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            _typeIcon(module.type),
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(module.label, style: const TextStyle(fontSize: 15)),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColors.textSecondary,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.textTertiary,
            onPressed: onDelete,
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.drag_handle,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 编辑模块的弹窗。
class _ModuleEditDialog extends StatefulWidget {
  const _ModuleEditDialog({required this.module});

  final WorkoutModule module;

  @override
  State<_ModuleEditDialog> createState() => _ModuleEditDialogState();
}

class _ModuleEditDialogState extends State<_ModuleEditDialog> {
  late WorkoutModuleType _type;
  late WorkoutModuleUnit _unit;
  late final TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _type = widget.module.type;
    _unit = widget.module.unit;
    final v = widget.module.value;
    _valueController = TextEditingController(
      text: v == v.toInt().toDouble() ? v.toInt().toString() : v.toString(),
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _switchUnit(WorkoutModuleUnit unit) {
    setState(() {
      final current = double.tryParse(_valueController.text);
      _unit = unit;
      if (unit == WorkoutModuleUnit.minutes &&
          (current == null || current < 1)) {
        _valueController.text = '5';
      } else if (unit == WorkoutModuleUnit.meters &&
          (current == null || current < 100)) {
        _valueController.text = '800';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑模块'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型选择
            const Text(
              '类型',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: WorkoutModuleType.values.map((type) {
                final selected = _type == type;
                return ChoiceChip(
                  label: Text(_typeName(type)),
                  selected: selected,
                  onSelected: (v) => setState(() => _type = type),
                  selectedColor: AppColors.accent.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.accent : AppColors.textPrimary,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // 单位选择
            const Text(
              '计量方式',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _UnitButton(
                    label: '时间 (min)',
                    selected: _unit == WorkoutModuleUnit.minutes,
                    onTap: () => _switchUnit(WorkoutModuleUnit.minutes),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _UnitButton(
                    label: '距离 (m)',
                    selected: _unit == WorkoutModuleUnit.meters,
                    onTap: () => _switchUnit(WorkoutModuleUnit.meters),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 数值输入
            const Text(
              '数值',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
              decoration: InputDecoration(
                hintText: _unit == WorkoutModuleUnit.minutes ? '5' : '800',
                suffixText: _unit == WorkoutModuleUnit.minutes ? 'min' : 'm',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final value = double.tryParse(_valueController.text.trim());
            if (value == null || value <= 0) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('请输入有效的数值')));
              return;
            }
            Navigator.of(
              context,
            ).pop(WorkoutModule(type: _type, unit: _unit, value: value));
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _UnitButton extends StatelessWidget {
  const _UnitButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.surfaceHigh,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
