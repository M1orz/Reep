import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:location/location.dart';

import '../models/run_record.dart';
import '../models/workout_plan.dart';

enum RunState { idle, running, paused, finished }

/// 训练模块状态。
enum ModulePhase { active, completed }

/// 当前正在执行的训练模块信息。
class ActiveModule {
  ActiveModule({
    required this.index,
    required this.module,
    required this.phase,
  });

  final int index;
  final WorkoutModule module;
  ModulePhase phase;

  /// 当前模块已用时间（秒）。
  double elapsedInModule = 0;

  /// 当前模块已跑距离（米）。
  double distanceInModule = 0;

  /// 当前模块的进度（0.0 ~ 1.0）。
  double get progress {
    if (phase == ModulePhase.completed) return 1.0;
    final dur = module.durationSeconds;
    final dist = module.distanceMeters;
    if (dur > 0) return (elapsedInModule / dur).clamp(0.0, 1.0);
    if (dist > 0) return (distanceInModule / dist).clamp(0.0, 1.0);
    return 0.0;
  }

  bool get isComplete {
    if (phase == ModulePhase.completed) return true;
    final dur = module.durationSeconds;
    final dist = module.distanceMeters;
    if (dur > 0 && elapsedInModule >= dur) return true;
    if (dist > 0 && distanceInModule >= dist) return true;
    return false;
  }
}

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

  /// 当前训练计划（null 表示自由跑）。
  WorkoutPlan? _workoutPlan;

  /// 当前正在执行的模块索引。
  int _currentModuleIndex = 0;

  /// 上一个模块完成的时间点（用于计算模块内 elapsed）。
  DateTime? _moduleStartTime;

  /// 上一个模块完成时已跑距离（用于计算模块内 distance）。
  double _moduleStartDistance = 0;

  /// 当前模块已用时间（秒）。
  double _currentModuleElapsed = 0;

  RunState get state => _state;
  Duration get elapsed => _elapsed;
  double get distanceMeters => _distanceMeters;
  double get distanceKm => _distanceMeters / 1000;
  List<TrackPoint> get track => List.unmodifiable(_track);
  DateTime? get startedAt => _startedAt;
  String? get error => _error;
  bool get hasGpsFix => _lastLocation != null;

  /// 当前训练计划。
  WorkoutPlan? get workoutPlan => _workoutPlan;

  /// 是否在使用训练计划。
  bool get isWorkout =>
      _workoutPlan != null && _workoutPlan!.modules.isNotEmpty;

  /// 当前模块信息（仅在训练模式下有效）。
  ActiveModule? get activeModule {
    if (!isWorkout) return null;
    final plan = _workoutPlan!;
    if (_currentModuleIndex >= plan.modules.length) return null;
    final module = plan.modules[_currentModuleIndex];
    return ActiveModule(
      index: _currentModuleIndex,
      module: module,
      phase: ModulePhase.active,
    );
  }

  /// 已完成模块数。
  int get completedModuleCount {
    if (!isWorkout) return 0;
    return _currentModuleIndex;
  }

  /// 总模块数。
  int get totalModuleCount {
    if (!isWorkout) return 0;
    return _workoutPlan!.modules.length;
  }

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

  /// 设置训练计划。在 start() 之前调用。
  void setWorkoutPlan(WorkoutPlan? plan) {
    _workoutPlan = plan;
    notifyListeners();
  }

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      _error = '请先打开手机定位服务';
      notifyListeners();
      return false;
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

    // 初始化训练模块进度。
    if (isWorkout) {
      _currentModuleIndex = 0;
      _moduleStartTime = DateTime.now();
      _moduleStartDistance = 0;
    }

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

    // 恢复时重置模块计时，避免暂停期间被计入。
    if (isWorkout) {
      _moduleStartTime = DateTime.now();
      _moduleStartDistance = _distanceMeters;
    }

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
    _workoutPlan = null;
    _currentModuleIndex = 0;
    _moduleStartTime = null;
    _moduleStartDistance = 0;
    _track.clear();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);

      // 训练模式：推进当前模块计时。
      if (isWorkout) {
        _advanceModuleTimer(const Duration(seconds: 1));
      }

      notifyListeners();
    });
  }

  /// 每秒钟调用，检查当前模块是否完成并推进到下一个。
  void _advanceModuleTimer(Duration delta) {
    if (!isWorkout) return;
    final plan = _workoutPlan!;
    if (_currentModuleIndex >= plan.modules.length) return;

    final module = plan.modules[_currentModuleIndex];

    // 时间模块：累加已用时间。
    if (module.unit == WorkoutModuleUnit.minutes && _moduleStartTime != null) {
      final elapsed = DateTime.now().difference(_moduleStartTime!).inSeconds;
      _currentModuleElapsed = elapsed.toDouble();
    }

    // 检查是否完成。
    final active = ActiveModule(
      index: _currentModuleIndex,
      module: module,
      phase: ModulePhase.active,
    );
    active.elapsedInModule = _currentModuleElapsed;
    active.distanceInModule = _distanceMeters - _moduleStartDistance;

    if (active.isComplete) {
      _currentModuleIndex++;
      _moduleStartTime = DateTime.now();
      _moduleStartDistance = _distanceMeters;
      _currentModuleElapsed = 0;

      notifyListeners();
    }
  }

  /// 检查当前距离模块是否已完成。
  void _checkModuleDistanceComplete() {
    if (!isWorkout) return;
    final plan = _workoutPlan!;
    if (_currentModuleIndex >= plan.modules.length) return;

    final module = plan.modules[_currentModuleIndex];
    if (module.unit != WorkoutModuleUnit.meters) return;

    final active = ActiveModule(
      index: _currentModuleIndex,
      module: module,
      phase: ModulePhase.active,
    );
    active.distanceInModule = _distanceMeters - _moduleStartDistance;

    if (active.isComplete) {
      _currentModuleIndex++;
      _moduleStartTime = DateTime.now();
      _moduleStartDistance = _distanceMeters;
      _currentModuleElapsed = 0;
      notifyListeners();
    }
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

        // 训练模式：检查距离模块是否完成。
        if (isWorkout) {
          _checkModuleDistanceComplete();
        }
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
