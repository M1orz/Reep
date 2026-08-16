import 'package:flutter/material.dart';

/// 全局设计令牌：深色底 + 单一强调色，克制的层级与大量留白。
class AppColors {
  static const bg = Color(0xFF0A0A0B);
  static const surface = Color(0xFF15161A);
  static const surfaceHigh = Color(0xFF1E2026);
  static const accent = Color(0xFFC8FF3D);
  static const textPrimary = Color(0xFFF2F3F5);
  static const textSecondary = Color(0xFF8A8D96);
  static const textTertiary = Color(0xFF5A5D66);
  static const danger = Color(0xFFFF5A5A);
}

class AppRadius {
  static const card = 24.0;
  static const chip = 100.0;
}

/// 大号数据展示专用样式：等宽数字，紧凑字距。
const kTabularFigures = [FontFeature.tabularFigures()];

ThemeData buildAppTheme() {
  const base = ColorScheme.dark(
    surface: AppColors.bg,
    primary: AppColors.accent,
    onPrimary: Color(0xFF0A0A0B),
    secondary: AppColors.accent,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 76,
        height: 1.0,
        fontWeight: FontWeight.w300,
        letterSpacing: -3,
        color: AppColors.textPrimary,
        fontFeatures: kTabularFigures,
      ),
      displayMedium: TextStyle(
        fontSize: 44,
        height: 1.05,
        fontWeight: FontWeight.w300,
        letterSpacing: -1.5,
        color: AppColors.textPrimary,
        fontFeatures: kTabularFigures,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.6,
        color: AppColors.textTertiary,
      ),
    ),
  );
}
