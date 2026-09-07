import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 模块类型。
enum WorkoutModuleType { warmUp, run, rest, coolDown }

/// 模块计量单位。
enum WorkoutModuleUnit { minutes, meters }

/// 训练计划中的一个模块（如"跑 800m"、"休息 2min"）。
class WorkoutModule {
  const WorkoutModule({
    required this.type,
    required this.unit,
    required this.value,
  });

  final WorkoutModuleType type;
  final WorkoutModuleUnit unit;
  final double value;

  /// 显示标签，如 "跑 800m"、"休息 2min"。
  String get label {
    final typeLabel = switch (type) {
      WorkoutModuleType.warmUp => '热身',
      WorkoutModuleType.run => '跑',
      WorkoutModuleType.rest => '休息',
      WorkoutModuleType.coolDown => '放松',
    };
    final unitLabel = switch (unit) {
      WorkoutModuleUnit.minutes => 'min',
      WorkoutModuleUnit.meters => 'm',
    };
    final displayValue = value == value.toInt().toDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$typeLabel $displayValue$unitLabel';
  }

  /// 总时长（秒）。按 unit 换算。
  double get durationSeconds {
    return switch (unit) {
      WorkoutModuleUnit.minutes => value * 60,
      WorkoutModuleUnit.meters => 0, // 距离模块时长由实际速度决定
    };
  }

  /// 总距离（米）。按 unit 换算。
  double get distanceMeters {
    return switch (unit) {
      WorkoutModuleUnit.meters => value,
      WorkoutModuleUnit.minutes => 0, // 时间模块距离由实际速度决定
    };
  }

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'unit': unit.index,
    'value': value,
  };

  factory WorkoutModule.fromJson(Map<String, dynamic> json) => WorkoutModule(
    type: WorkoutModuleType.values[json['type'] as int],
    unit: WorkoutModuleUnit.values[json['unit'] as int],
    value: (json['value'] as num).toDouble(),
  );
}

/// 一个完整的训练计划。
class WorkoutPlan {
  const WorkoutPlan({required this.name, required this.modules, this.id});

  /// 唯一标识。新建时为 null，保存后由仓库分配。
  final String? id;
  final String name;
  final List<WorkoutModule> modules;

  WorkoutPlan copyWith({
    String? id,
    String? name,
    List<WorkoutModule>? modules,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      modules: modules ?? this.modules,
    );
  }

  /// 计划总时长（秒），仅计算时间模块。
  double get totalDurationSeconds {
    return modules.fold(0, (sum, m) => sum + m.durationSeconds);
  }

  /// 计划总距离（米），仅计算距离模块。
  double get totalDistanceMeters {
    return modules.fold(0, (sum, m) => sum + m.distanceMeters);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'modules': modules.map((m) => m.toJson()).toList(),
  };

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) => WorkoutPlan(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '未命名计划',
    modules: (json['modules'] as List<dynamic>)
        .map((e) => WorkoutModule.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// 训练计划仓库。
class WorkoutPlanRepository {
  static const _key = 'reep_workout_plans_v1';

  Future<List<WorkoutPlan>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => WorkoutPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<WorkoutPlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(plans.map((p) => p.toJson()).toList()),
    );
  }

  /// 新增计划，返回分配了 id 的新计划。
  Future<WorkoutPlan> add(WorkoutPlan plan) async {
    final plans = await load();
    final saved = plan.copyWith(
      id: plan.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    );
    await save([...plans, saved]);
    return saved;
  }

  /// 按 id 更新计划；不存在则新增。
  Future<WorkoutPlan> upsert(WorkoutPlan plan) async {
    final plans = await load();
    final index = plans.indexWhere((p) => p.id != null && p.id == plan.id);
    if (index >= 0) {
      plans[index] = plan;
      await save(plans);
      return plan;
    }
    return add(plan);
  }

  Future<void> removeById(String id) async {
    final plans = await load();
    plans.removeWhere((p) => p.id == id);
    await save(plans);
  }
}
