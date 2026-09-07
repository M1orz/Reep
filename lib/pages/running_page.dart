import 'package:flutter/material.dart';

import '../models/run_record.dart';
import '../models/workout_plan.dart';
import '../services/run_session.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/track_map.dart';
import 'summary_page.dart';

class RunningPage extends StatefulWidget {
  const RunningPage({super.key, required this.repository, this.workoutPlan});

  final RunRepository repository;

  /// 可选的训练计划。为 null 时表示自由跑。
  final WorkoutPlan? workoutPlan;

  @override
  State<RunningPage> createState() => _RunningPageState();
}

class _RunningPageState extends State<RunningPage> {
  final _session = RunSession();

  /// 地图默认关闭：纯数据界面更省电，也更符合专注跑步的场景。
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onChange);

    // 设置训练计划。
    if (widget.workoutPlan != null) {
      _session.setWorkoutPlan(widget.workoutPlan);
    }

    _session.start();
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _session.removeListener(_onChange);
    _session.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final record = _session.finish();
    if (!mounted) return;

    if (record.distanceMeters < 10) {
      // 距离过短不保存，直接退出。
      Navigator.of(context).pop();
      return;
    }

    await widget.repository.save(record);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SummaryPage(record: record)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final running = _session.state == RunState.running;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.center,
                children: [
                  _GpsBadge(session: _session),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _MapToggle(
                      active: _showMap,
                      onTap: () => setState(() => _showMap = !_showMap),
                    ),
                  ),
                ],
              ),

              // 训练模式：显示当前模块信息。
              if (_session.isWorkout) ...[
                const SizedBox(height: 20),
                _WorkoutModuleIndicator(session: _session),
              ],
              if (_showMap) ...[
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: TrackMap(
                      track: _session.track,
                      interactive: false,
                      showStartEnd: false,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatDistance(_session.distanceMeters),
                      style: text.displayLarge?.copyWith(fontSize: 52),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '公里',
                        style: text.bodyMedium?.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Spacer(flex: 2),
                Text('距离 · 公里', style: text.labelSmall),
                const SizedBox(height: 10),
                Text(
                  formatDistance(_session.distanceMeters),
                  style: text.displayLarge?.copyWith(fontSize: 88),
                ),
                const Spacer(flex: 2),
              ],
              Row(
                children: [
                  Expanded(
                    child: _LiveStat(
                      label: '时长',
                      value: formatDuration(_session.elapsed),
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppColors.surfaceHigh),
                  Expanded(
                    child: _LiveStat(
                      label: '配速',
                      value: formatPace(
                        _session.currentPaceSecPerKm ??
                            _session.avgPaceSecPerKm,
                      ),
                    ),
                  ),
                ],
              ),
              _showMap ? const SizedBox(height: 32) : const Spacer(flex: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!running)
                    _CircleAction(
                      label: '结束',
                      color: AppColors.surfaceHigh,
                      textColor: AppColors.danger,
                      onTap: _finish,
                    ),
                  if (!running) const SizedBox(width: 28),
                  _CircleAction(
                    label: running ? '暂停' : '继续',
                    color: running ? AppColors.surfaceHigh : AppColors.accent,
                    textColor: running
                        ? AppColors.textPrimary
                        : const Color(0xFF0A0A0B),
                    size: 92,
                    onTap: running ? _session.pause : _session.resume,
                  ),
                ],
              ),
              const SizedBox(height: 44),
            ],
          ),
        ),
      ),
    );
  }
}

/// 地图显示开关。选中时用强调色描边，未选中仅为低对比图标。
class _MapToggle extends StatelessWidget {
  const _MapToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.surfaceHigh,
          ),
        ),
        child: Icon(
          Icons.map_outlined,
          size: 15,
          color: active ? AppColors.accent : AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _GpsBadge extends StatelessWidget {
  const _GpsBadge({required this.session});

  final RunSession session;

  @override
  Widget build(BuildContext context) {
    final error = session.error;
    final ok = session.hasGpsFix;
    final label = error ?? (ok ? 'GPS 已定位' : '正在搜索 GPS');
    final color = error != null
        ? AppColors.danger
        : (ok ? AppColors.accent : AppColors.textTertiary);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color, letterSpacing: 0.5),
        ),
      ],
    );
  }
}

class _LiveStat extends StatelessWidget {
  const _LiveStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 10),
        Text(
          value,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// 训练模块指示器：显示当前模块名称、进度条和完成状态。
class _WorkoutModuleIndicator extends StatelessWidget {
  const _WorkoutModuleIndicator({required this.session});

  final RunSession session;

  @override
  Widget build(BuildContext context) {
    final module = session.activeModule;
    if (module == null) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final progress = module.progress;
    final completedCount = session.completedModuleCount;
    final totalCount = session.totalModuleCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 模块进度标题。
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '模块 ${completedCount + 1} / $totalCount',
                style: text.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                module.module.label,
                style: text.titleSmall?.copyWith(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 进度条。
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),

          // 进度百分比。
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: text.labelSmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.size = 76,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
