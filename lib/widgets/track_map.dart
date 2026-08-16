import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/run_record.dart';
import '../theme.dart';
import '../utils/coord_converter.dart';

/// 轨迹地图。高德栅格瓦片作底图，轨迹用强调色发光线绘制。
///
/// 底图默认叠一层暗色滤镜，让彩色瓦片压暗，保持整体深色调性。
class TrackMap extends StatelessWidget {
  const TrackMap({
    super.key,
    required this.track,
    this.interactive = true,
    this.showStartEnd = true,
    this.dimBackground = true,
  });

  final List<TrackPoint> track;

  /// 是否允许手势缩放拖动。列表缩略图场景应关闭。
  final bool interactive;
  final bool showStartEnd;
  final bool dimBackground;

  /// 轨迹点转为高德坐标系下的地图点。
  List<LatLng> get _points => track.map((p) {
        final c = CoordConverter.wgs84ToGcj02(p.lat, p.lng);
        return LatLng(c.lat, c.lng);
      }).toList();

  @override
  Widget build(BuildContext context) {
    final points = _points;
    if (points.length < 2) {
      return const _MapPlaceholder();
    }

    final bounds = LatLngBounds.fromPoints(points);

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(36),
            ),
            interactionOptions: InteractionOptions(
              flags: interactive
                  ? (InteractiveFlag.pinchZoom | InteractiveFlag.drag)
                  : InteractiveFlag.none,
            ),
            backgroundColor: AppColors.surface,
          ),
          children: [
            TileLayer(
              // 高德栅格瓦片。style=7 为标准路网图，视觉最干净。
              urlTemplate:
                  'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
              subdomains: const ['1', '2', '3', '4'],
              userAgentPackageName: 'com.reep.reep',
              tileBuilder: dimBackground ? _dimTileBuilder : null,
            ),
            // 外层粗线做发光扩散，内层细线做主体。
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 9,
                  color: AppColors.accent.withValues(alpha: 0.18),
                ),
                Polyline(
                  points: points,
                  strokeWidth: 4,
                  color: AppColors.accent,
                ),
              ],
            ),
            if (showStartEnd)
              MarkerLayer(
                markers: [
                  Marker(
                    point: points.first,
                    width: 14,
                    height: 14,
                    child: const _EndpointDot(filled: false),
                  ),
                  Marker(
                    point: points.last,
                    width: 14,
                    height: 14,
                    child: const _EndpointDot(filled: true),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  /// 把彩色瓦片压暗并降低饱和，融入深色主题。
  static Widget _dimTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
  ) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.28, 0.30, 0.10, 0, 6, //
        0.24, 0.34, 0.10, 0, 6, //
        0.24, 0.30, 0.16, 0, 8, //
        0, 0, 0, 1, 0, //
      ]),
      child: tileWidget,
    );
  }
}

class _EndpointDot extends StatelessWidget {
  const _EndpointDot({required this.filled});

  /// true 为终点（实心），false 为起点（空心）。
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.accent : AppColors.bg,
        border: Border.all(color: AppColors.accent, width: 2.5),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Text(
        '轨迹点不足，无法绘制',
        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
      ),
    );
  }
}
