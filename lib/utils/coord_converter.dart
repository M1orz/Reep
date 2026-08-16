import 'dart:math' as math;

/// WGS-84（GPS 原始坐标）与 GCJ-02（国测局 / 高德坐标）互转。
///
/// 国内地图底图均使用 GCJ-02 加密坐标，若把 GPS 原始坐标直接绘制在高德底图上，
/// 轨迹会整体偏移数百米。所有进入地图渲染的坐标都必须先经过此转换。
class CoordConverter {
  static const _pi = math.pi;
  static const _a = 6378245.0; // 克拉索夫斯基椭球长半轴
  static const _ee = 0.00669342162296594323; // 偏心率平方

  /// 判断是否在国内。国外坐标无需偏移。
  static bool _outOfChina(double lat, double lng) {
    return lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;
  }

  static double _transformLat(double x, double y) {
    var ret = -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * _pi) + 20.0 * math.sin(2.0 * x * _pi)) *
        2.0 /
        3.0;
    ret += (20.0 * math.sin(y * _pi) + 40.0 * math.sin(y / 3.0 * _pi)) * 2.0 / 3.0;
    ret += (160.0 * math.sin(y / 12.0 * _pi) + 320 * math.sin(y * _pi / 30.0)) *
        2.0 /
        3.0;
    return ret;
  }

  static double _transformLng(double x, double y) {
    var ret =
        300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * _pi) + 20.0 * math.sin(2.0 * x * _pi)) *
        2.0 /
        3.0;
    ret += (20.0 * math.sin(x * _pi) + 40.0 * math.sin(x / 3.0 * _pi)) * 2.0 / 3.0;
    ret +=
        (150.0 * math.sin(x / 12.0 * _pi) + 300.0 * math.sin(x / 30.0 * _pi)) *
            2.0 /
            3.0;
    return ret;
  }

  /// GPS 原始坐标 -> 高德坐标。
  static ({double lat, double lng}) wgs84ToGcj02(double lat, double lng) {
    if (_outOfChina(lat, lng)) return (lat: lat, lng: lng);

    var dLat = _transformLat(lng - 105.0, lat - 35.0);
    var dLng = _transformLng(lng - 105.0, lat - 35.0);
    final radLat = lat / 180.0 * _pi;
    var magic = math.sin(radLat);
    magic = 1 - _ee * magic * magic;
    final sqrtMagic = math.sqrt(magic);
    dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * _pi);
    dLng = (dLng * 180.0) / (_a / sqrtMagic * math.cos(radLat) * _pi);

    return (lat: lat + dLat, lng: lng + dLng);
  }
}
