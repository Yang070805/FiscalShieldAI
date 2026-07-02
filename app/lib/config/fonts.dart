import 'package:flutter/material.dart';

/// 字体常量
/// 品牌名: 行书(STXingkai) + 花体(GreatVibes)
/// 标题: 楷书(STKaiti/SimKai)
/// 正文: 系统默认
/// 数据: 等宽(JetBrainsMono)
class AppFonts {
  // ── 品牌字体 ──
  static const String brandCN = 'STXingkai';    // 行书·中文品牌名
  static const String brandEN = 'GreatVibes';   // 花体·英文品牌名

  // ── 标题字体 ──
  static const String headingCN = 'STKaiti';    // 楷书·中文标题
  static const String headingCNFallback = 'SimKai'; // 楷书备用

  // ── 数据字体 ──
  static const String mono = 'JetBrainsMono';   // 等宽·数字/指标

  // ── 便捷样式 ──

  /// 品牌中文名样式（行书）
  static const TextStyle brandCNStyle = TextStyle(
    fontFamily: brandCN,
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 6,
    decoration: TextDecoration.none,
  );

  /// 品牌英文名样式（花体）
  static const TextStyle brandENStyle = TextStyle(
    fontFamily: brandEN,
    fontSize: 18,
    color: Color(0xFFA3BBDB), // 晴山
    letterSpacing: 2,
    decoration: TextDecoration.none,
  );

  /// 大标题样式（楷书）
  static TextStyle headingLarge = TextStyle(
    fontFamily: headingCN,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: const Color(0xFFD4E5EF), // 月白
    decoration: TextDecoration.none,
  );

  /// 中标题样式（楷书）
  static TextStyle headingMedium = TextStyle(
    fontFamily: headingCN,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: const Color(0xFFD4E5EF),
    decoration: TextDecoration.none,
  );

  /// 小标题样式（楷书）
  static TextStyle headingSmall = TextStyle(
    fontFamily: headingCN,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: const Color(0xFFA3BBDB), // 晴山
    decoration: TextDecoration.none,
  );

  /// 数据样式（等宽）
  static const TextStyle dataStyle = TextStyle(
    fontFamily: mono,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFFD4E5EF),
    decoration: TextDecoration.none,
  );

  /// 数据粗体样式（等宽）
  static const TextStyle dataBoldStyle = TextStyle(
    fontFamily: mono,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Color(0xFFD4E5EF),
    decoration: TextDecoration.none,
  );

  /// 大数字样式（等宽，用于风险百分比）
  static const TextStyle numberLarge = TextStyle(
    fontFamily: mono,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.none,
  );
}
