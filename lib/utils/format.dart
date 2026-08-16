String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String formatDistance(double meters) => (meters / 1000).toStringAsFixed(2);

/// 配速格式化：秒/公里 -> "5'30""
String formatPace(double? secPerKm) {
  if (secPerKm == null || secPerKm.isInfinite || secPerKm.isNaN) return '--\'--"';
  final total = secPerKm.round();
  final m = total ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return "$m'$s\"";
}

String formatDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(target).inDays;
  final time =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  if (diff == 0) return '今天 $time';
  if (diff == 1) return '昨天 $time';
  return '${dt.month}月${dt.day}日 $time';
}
