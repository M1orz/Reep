import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 轨迹点：仅保留雏形阶段需要的字段。
class TrackPoint {
  const TrackPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  final double lat;
  final double lng;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        't': timestamp.millisecondsSinceEpoch,
      };

  factory TrackPoint.fromJson(Map<String, dynamic> json) => TrackPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
      );
}

class RunRecord {
  const RunRecord({
    required this.id,
    required this.startedAt,
    required this.duration,
    required this.distanceMeters,
    required this.track,
  });

  final String id;
  final DateTime startedAt;
  final Duration duration;
  final double distanceMeters;
  final List<TrackPoint> track;

  double get distanceKm => distanceMeters / 1000;

  /// 平均配速，单位：秒 / 公里。距离过短时返回 null。
  double? get paceSecPerKm {
    if (distanceMeters < 50) return null;
    return duration.inSeconds / distanceKm;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'durationSec': duration.inSeconds,
        'distance': distanceMeters,
        'track': track.map((p) => p.toJson()).toList(),
      };

  factory RunRecord.fromJson(Map<String, dynamic> json) => RunRecord(
        id: json['id'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int),
        duration: Duration(seconds: json['durationSec'] as int),
        distanceMeters: (json['distance'] as num).toDouble(),
        track: (json['track'] as List<dynamic>)
            .map((e) => TrackPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 本地记录仓库。雏形阶段用 SharedPreferences 存 JSON，后续可换 SQLite。
class RunRepository {
  static const _key = 'reep_runs_v1';

  Future<List<RunRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final records = list
        .map((e) => RunRecord.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return records;
  }

  Future<void> save(RunRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final next = [record, ...current];
    await prefs.setString(
      _key,
      jsonEncode(next.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final next = (await load()).where((r) => r.id != id).toList();
    await prefs.setString(
      _key,
      jsonEncode(next.map((r) => r.toJson()).toList()),
    );
  }
}
