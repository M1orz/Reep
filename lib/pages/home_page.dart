import 'package:flutter/material.dart';

import '../models/run_record.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'history_page.dart';
import 'run_detail_page.dart';
import 'running_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.repository});

  final RunRepository repository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<RunRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final records = await widget.repository.load();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  List<RunRecord> get _thisWeek {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return _records.where((r) => r.startedAt.isAfter(monday)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final week = _thisWeek;
    final weekKm = week.fold<double>(0, (sum, r) => sum + r.distanceKm);
    final weekDuration = week.fold<Duration>(
      Duration.zero,
      (sum, r) => sum + r.duration,
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            children: [
              _Header(onHistory: _openHistory),
              const SizedBox(height: 44),
              Text('本周', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 14),
              _WeekSummary(
                km: weekKm,
                duration: weekDuration,
                runs: week.length,
                loading: _loading,
              ),
              const SizedBox(height: 40),
              _StartButton(onTap: _startRun),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('最近', style: Theme.of(context).textTheme.labelSmall),
                  if (_records.length > 3)
                    GestureDetector(
                      onTap: _openHistory,
                      child: const Text(
                        '全部',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_records.isEmpty && !_loading)
                const _EmptyHint()
              else
                ..._records.take(3).map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RunListTile(
                          record: r,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RunDetailPage(record: r),
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRun() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RunningPage(repository: widget.repository),
      ),
    );
    _refresh();
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryPage(repository: widget.repository),
      ),
    );
    _refresh();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onHistory});

  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'REEP',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
            color: AppColors.textPrimary,
          ),
        ),
        IconButton(
          onPressed: onHistory,
          icon: const Icon(Icons.history_rounded,
              color: AppColors.textSecondary, size: 22),
        ),
      ],
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({
    required this.km,
    required this.duration,
    required this.runs,
    required this.loading,
  });

  final double km;
  final Duration duration;
  final int runs;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(loading ? '--' : km.toStringAsFixed(1),
                style: text.displayLarge),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('公里',
                  style: text.bodyMedium?.copyWith(fontSize: 15)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _MiniStat(label: '次数', value: loading ? '--' : '$runs'),
            const SizedBox(width: 36),
            _MiniStat(
              label: '时长',
              value: loading ? '--' : formatDuration(duration),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                color: AppColors.textTertiary)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        alignment: Alignment.center,
        child: const Text(
          '开始跑步',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: Color(0xFF0A0A0B),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Text(
        '还没有记录，去跑第一公里',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
      ),
    );
  }
}

class RunListTile extends StatelessWidget {
  const RunListTile({super.key, required this.record, this.onTap});

  final RunRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDate(record.startedAt),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatDistance(record.distanceMeters),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('km',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDuration(record.duration),
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatPace(record.paceSecPerKm)} /km',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
