import 'package:flutter/material.dart';
import 'colors.dart';

/// 水墨·璃 主题 — 支持动态切换
class AppTheme {
  static TextStyle _style(double size, FontWeight weight, Color color, [double letterSpacing = 0]) {
    return TextStyle(fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing, decoration: TextDecoration.none);
  }

  /// 每次调用都生成新的 ThemeData（跟随当前主题）
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.dark(
        primary: AppColors.celadon,
        secondary: AppColors.sky,
        surface: AppColors.cardBg,
      ),
      textTheme: TextTheme(
        headlineLarge: _style(28, FontWeight.bold, AppColors.paper, 2),
        headlineMedium: _style(22, FontWeight.bold, AppColors.paper),
        titleLarge: _style(18, FontWeight.w600, AppColors.paper),
        titleMedium: _style(16, FontWeight.w500, AppColors.paper),
        bodyLarge: _style(16, FontWeight.normal, AppColors.paper),
        bodyMedium: _style(14, FontWeight.normal, AppColors.paperMid),
        bodySmall: _style(12, FontWeight.normal, AppColors.paperDim),
        labelLarge: _style(14, FontWeight.w600, AppColors.paper),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, letterSpacing: 2, decoration: TextDecoration.none),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.celadon,
          foregroundColor: AppColors.paper,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.sky, width: 1.5),
        ),
        labelStyle: TextStyle(color: AppColors.paperDim, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  /// 毛玻璃卡片装饰
  static BoxDecoration glassCard({double radius = 16, bool glow = false, Color? glowColor}) {
    return BoxDecoration(
      color: AppColors.glassWhite,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.glassBorder, width: 1),
      boxShadow: glow
          ? [BoxShadow(color: (glowColor ?? AppColors.celadon).withOpacity(0.12), blurRadius: 20, spreadRadius: 2)]
          : null,
    );
  }

  /// 深色卡片装饰
  static BoxDecoration darkCard({double radius = 16}) {
    return BoxDecoration(
      color: AppColors.cardBg.withOpacity(0.6),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.glassBorder, width: 0.5),
    );
  }
}
