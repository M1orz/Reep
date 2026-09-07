import 'package:flutter/material.dart';

import '../models/workout_plan.dart';
import '../theme.dart';
import 'workout_editor_page.dart';

/// 用户选择的跑步模式。
enum RunMode { free, workout }

class WorkoutSelectPage extends StatefulWidget {
  const WorkoutSelectPage({super.key});

  @override
  State<WorkoutSelectPage> createState() => _WorkoutSelectPageState();
}

/// 模式选择页的返回值。
class WorkoutSelection {
  const WorkoutSelection({required this.mode, required this.plan});

  final RunMode mode;
  final WorkoutPlan? plan;
}

class _WorkoutSelectPageState extends State<WorkoutSelectPage> {
  List<WorkoutPlan> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await WorkoutPlanRepository().load();
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择跑步模式', style: text.headlineSmall),
              const SizedBox(height: 32),

              // 自由跑
              _ModeCard(
                icon: Icons.directions_run,
                title: '自由跑',
                subtitle: '无结构跑步，随意记录',
                onTap: () => Navigator.of(
                  context,
                ).pop(const WorkoutSelection(mode: RunMode.free, plan: null)),
              ),

              const SizedBox(height: 16),

              // 自定义训练
              _ModeCard(
                icon: Icons.schedule,
                title: '自定义训练',
                subtitle: _loading
                    ? '加载中...'
                    : (_plans.isEmpty ? '暂无计划，点击创建' : '${_plans.length} 个可用计划'),
                onTap: _plans.isEmpty
                    ? () => _openEditor(null)
                    : () => _showPlanPicker(),
              ),

              const Spacer(),

              if (_plans.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => _openEditor(null),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.surfaceHigh),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '+ 创建新训练计划',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPlanPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择训练计划', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ..._plans.asMap().entries.map((entry) {
              final plan = entry.value;
              return ListTile(
                title: Text(plan.name),
                subtitle: Text(
                  '${plan.modules.length} 个模块 · '
                  '${_formatPlanSummary(plan)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openEditor(plan);
                  },
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(
                    context,
                  ).pop(WorkoutSelection(mode: RunMode.workout, plan: plan));
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(WorkoutPlan? existing) async {
    final saved = await Navigator.of(context).push<WorkoutPlan>(
      MaterialPageRoute(
        builder: (_) => WorkoutEditorPage(existingPlan: existing),
      ),
    );
    if (saved != null) {
      await _loadPlans();
      // 新建计划保存后，直接进入训练；编辑已有计划则停留在选择页。
      if (existing == null && mounted) {
        Navigator.of(
          context,
        ).pop(WorkoutSelection(mode: RunMode.workout, plan: saved));
      }
    }
  }

  String _formatPlanSummary(WorkoutPlan plan) {
    final totalMin = plan.totalDurationSeconds / 60;
    final totalDist = plan.totalDistanceMeters;
    final parts = <String>[];
    if (totalMin > 0) parts.add('${totalMin.toStringAsFixed(0)}分钟');
    if (totalDist > 0) parts.add('${(totalDist / 1000).toStringAsFixed(1)}公里');
    return parts.join(' · ');
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceHigh),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
