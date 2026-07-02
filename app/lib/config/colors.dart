import 'package:flutter/material.dart';
import 'theme_schemes.dart';

/// 水墨·璃 配色系统 — 支持动态主题切换
///
/// 所有颜色是 static 字段，主题切换时 update() 更新。
/// 已有代码中 AppColors.xxx 无需修改（仍是 static 访问）。
class AppColors {
  /// 切换主题并更新所有颜色
  static void update(ThemeType type) {
    final s = schemeMap[type]!;
    celadon = s.primary;
    sky = s.accent;
    paper = s.textPrimary;
    paperMid = s.textSecondary;
    paperDim = s.textDim;
    deepBg = s.bgDeep;
    cardBg = s.bgLight;
    riskLow = s.riskLow;
    riskMedium = s.riskMedium;
    riskHigh = s.riskHigh;
    glassWhite = s.glassBg;
    glassBorder = s.glassBorder;
  }

  // ═══ 主色（动态）═══
  static Color celadon = const Color(0xFF6CA8AF);
  static Color sky = const Color(0xFFA3BBDB);

  // ═══ 文字（动态）═══
  static Color paper = const Color(0xFFD4E5EF);
  static Color paperMid = const Color(0xFFA3BBDB);
  static Color paperDim = const Color(0xFF576470);

  // ═══ 背景（动态）═══
  static Color deepBg = const Color(0xFF0A0E16);
  static Color cardBg = const Color(0xFF1A2847);

  // ═══ 风险色（动态）═══
  static Color riskLow = const Color(0xFF6CA8AF);
  static Color riskMedium = const Color(0xFFF29A76);
  static Color riskHigh = const Color(0xFFA81C2B);

  // ═══ 玻璃色（动态）═══
  static Color glassWhite = const Color(0x0FFFFFFF);
  static Color glassBorder = const Color(0x1AFFFFFF);

  // ═══ 固定色（不随主题变）═══
  static const Color glow = Color(0xFF757CBB);
  static const Color glassHover = Color(0x1FFFFFFF);

  // ═══ 五行色（固定，用于特殊装饰）═══
  static const Color tajian = Color(0xFF151D29);
  static const Color jingyuan = Color(0xFF31322C);
  static const Color huaqing = Color(0xFF1A2847);
  static const Color zhengqing = Color(0xFF6CA8AF);
  static const Color yuebai = Color(0xFFD4E5EF);
  static const Color qingshan = Color(0xFFA3BBDB);
  static const Color yuyangran = Color(0xFF576470);
  static const Color ziyan = Color(0xFF757CBB);
  static const Color daran = Color(0xFFA81C2B);
  static const Color wozhe = Color(0xFFDD6B7B);
  static const Color zhuyantuo = Color(0xFFF29A76);
  static const Color chunzhi = Color(0xFFC25160);
  static const Color gaoyu = Color(0xFFEFEFEF);
  static const Color yuse = Color(0xFFEAE4D1);
  static const Color huaQing = Color(0xFF1A2847);
  static const Color qingdai = Color(0xFF45465E);
  static const Color piaobi = Color(0xFFC0D695);
  static const Color warmApricot = Color(0xFFF29A76);
  static const Color teal = Color(0xFF6CA8AF);
  static const Color accentLight = Color(0xFFA3BBDB);
  static const Color accent = Color(0xFF6CA8AF);

  /// 墨色渐变
  static LinearGradient get inkGradient => LinearGradient(
    begin: const Alignment(-0.5, -1),
    end: const Alignment(0.5, 1),
    colors: [deepBg, jingyuan, cardBg],
  );

  /// 风险等级颜色
  static Color riskColor(String level) {
    if (level.contains('高') || level.contains('严重')) return riskHigh;
    if (level.contains('中等偏高')) return wozhe;
    if (level.contains('中等')) return riskMedium;
    if (level.contains('低')) return riskLow;
    return paperDim;
  }
}
