import 'package:flutter/material.dart';

import '../models/run_record.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/track_map.dart';

class RunDetailPage extends StatelessWidget {
  const RunDetailPage({super.key, required this.record});

  final RunRecord record;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    formatDate(record.startedAt),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(formatDistance(record.distanceMeters),
                      style: text.displayLarge?.copyWith(fontSize: 72)),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child:
                        Text('公里', style: text.bodyMedium?.copyWith(fontSize: 15)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: TrackMap(track: record.track),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Row(
                children: [
                  Expanded(
                    child: _DetailStat(
                      label: '用时',
                      value: formatDuration(record.duration),
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.surfaceHigh),
                  Expanded(
                    child: _DetailStat(
                      label: '平均配速',
                      value: formatPace(record.paceSecPerKm),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
