import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:location/location.dart';

import '../models/run_record.dart';

enum RunState { idle, running, paused, finished }

/// 跑步会话：负责计时、GPS 采样、距离累计。
class RunSession extends ChangeNotifier {
  RunState _state = RunState.idle;
  Duration _elapsed = Duration.zero;
  double _distanceMeters = 0;
  double? _currentSpeedMps;
  DateTime? _startedAt;
  String? _error;

  final List<TrackPoint> _track = [];
  Timer? _ticker;
  StreamSubscription<LocationData>? _positionSub;
  LocationData? _lastLocation;

  final Location _location = Location();

  RunState get state => _state;
  Duration get elapsed => _elapsed;
  double get distanceMeters => _distanceMeters;
  double get distanceKm => _distanceMeters / 1000;
  List<TrackPoint> get track => List.unmodifiable(_track);
  DateTime? get startedAt => _startedAt;
  String? get error => _error;
  bool get hasGpsFix => _lastLocation != null;

  /// 实时配速（秒/公里）。速度过低或无信号时为 null。
  double? get currentPaceSecPerKm {
    final speed = _currentSpeedMps;
    if (speed == null || speed < 0.5) return null;
    return 1000 / speed;
  }

  /// 平均配速（秒/公里）。
  double? get avgPaceSecPerKm {
    if (_distanceMeters < 50 || _elapsed.inSeconds == 0) return null;
    return _elapsed.inSeconds / distanceKm;
  }

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      final requested = await _location.requestService();
      if (!requested) {
        _error = '请先打开手机定位服务';
        notifyListeners();
        return false;
      }
    }

    var permission = await _location.hasPermission();
    if (permission != PermissionStatus.granted) {
      permission = await _location.requestPermission();
    }
    if (permission != PermissionStatus.granted) {
      _error = '需要定位权限才能记录轨迹';
      notifyListeners();
      return false;
    }

    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _error = null;
    return true;
  }

  Future<void> start() async {
    if (_state == RunState.running) return;
    if (!await _ensurePermission()) return;

    _state = RunState.running;
    _startedAt = DateTime.now();
    _elapsed = Duration.zero;
    _distanceMeters = 0;
    _track.clear();
    _lastLocation = null;
    notifyListeners();

    _startTicker();
    _startPositionStream();
  }

  void pause() {
    if (_state != RunState.running) return;
    _state = RunState.paused;
    _ticker?.cancel();
    notifyListeners();
  }

  void resume() {
    if (_state != RunState.paused) return;
    _state = RunState.running;
    _lastLocation = null;
    _startTicker();
    notifyListeners();
  }

  /// 结束并返回本次记录；调用方负责持久化。
  RunRecord finish() {
    _ticker?.cancel();
    _positionSub?.cancel();
    _positionSub = null;
    _state = RunState.finished;
    notifyListeners();

    return RunRecord(
      id: (_startedAt ?? DateTime.now()).millisecondsSinceEpoch.toString(),
      startedAt: _startedAt ?? DateTime.now(),
      duration: _elapsed,
      distanceMeters: _distanceMeters,
      track: List.of(_track),
    );
  }

  void reset() {
    _ticker?.cancel();
    _positionSub?.cancel();
    _positionSub = null;
    _state = RunState.idle;
    _elapsed = Duration.zero;
    _distanceMeters = 0;
    _currentSpeedMps = null;
    _startedAt = null;
    _lastLocation = null;
    _track.clear();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _startPositionStream() {
    _positionSub?.cancel();
    _positionSub = _location.onLocationChanged.listen(_onLocation);
  }

  void _onLocation(LocationData location) {
    if (location.accuracy != null && location.accuracy! > 30) return;
    if (_state != RunState.running) {
      _lastLocation = null;
      return;
    }

    _currentSpeedMps = location.speed != null && location.speed! >= 0
        ? location.speed
        : null;

    final last = _lastLocation;
    if (last != null) {
      final delta = _haversine(
        last.latitude ?? 0,
        last.longitude ?? 0,
        location.latitude ?? 0,
        location.longitude ?? 0,
      );
      final dt = _timeDiffSeconds(last, location);
      if (delta >= 2 && (dt <= 0 || delta / dt < 50)) {
        _distanceMeters += delta;
      }
    }

    _lastLocation = location;
    _track.add(
      TrackPoint(
        lat: location.latitude ?? 0,
        lng: location.longitude ?? 0,
        timestamp: _locationDataToDateTime(location),
      ),
    );
    notifyListeners();
  }

  /// Haversine 公式计算两点间距离（米）。
  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  static double _timeDiffSeconds(LocationData a, LocationData b) {
    final ta = a.time;
    final tb = b.time;
    if (ta == null || tb == null) return 0;
    return (tb - ta) / 1000;
  }

  static DateTime _locationDataToDateTime(LocationData loc) {
    final t = loc.time;
    if (t != null) return DateTime.fromMillisecondsSinceEpoch(t.toInt());
    return DateTime.now();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}
