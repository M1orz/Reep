import 'package:flutter/material.dart';

import '../models/run_record.dart';
import '../theme.dart';
import 'home_page.dart' show RunListTile;
import 'run_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.repository});

  final RunRepository repository;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<RunRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await widget.repository.load();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _delete(RunRecord record) async {
    await widget.repository.delete(record.id);
    _load();
  }

  void _openDetail(RunRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RunDetailPage(record: record)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalKm = _records.fold<double>(0, (s, r) => s + r.distanceKm);

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
                    '累计 ${totalKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Text(
                '历史记录',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -1,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const SizedBox.shrink()
                  : _records.isEmpty
                      ? const Center(
                          child: Text('暂无记录',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textTertiary)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                          itemCount: _records.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final r = _records[i];
                            return Dismissible(
                              key: ValueKey(r.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(Icons.delete_outline_rounded,
                                    color: AppColors.danger, size: 20),
                              ),
                              onDismissed: (_) => _delete(r),
                              child: RunListTile(
                                record: r,
                                onTap: () => _openDetail(r),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
