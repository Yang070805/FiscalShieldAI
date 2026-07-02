import 'package:flutter/material.dart';

/// 全局主题管理器
final ThemeNotifier themeNotifier = ThemeNotifier();
/// AppTheme.currentTheme 切换时，AppColors 的字段自动更新。

/// 主题切换管理
class ThemeNotifier extends ChangeNotifier {
  ThemeType _type = ThemeType.inkBlue;
  ThemeType get type => _type;

  // 字体大小：0=标准, 1=中号, 2=大号
  int _fontSizeLevel = 0;
  int get fontSizeLevel => _fontSizeLevel;

  // 字体：0=系统默认, 1~9 各字体
  int _fontFamilyLevel = 0;
  int get fontFamilyLevel => _fontFamilyLevel;
  String get fontFamily {
    const fonts = ['', 'SourceHanSans', 'SourceHanSerif', 'SmileySans',
      'LXGWWenKai', 'MiSans', 'AlibabaPuHuiTi', 'PangMenBiaoDaoTi',
      'ZhanKuGaoDuanHei', 'STKaiti'];
    return fonts[_fontFamilyLevel.clamp(0, 9)];
  }
  String get fontFamilyLabel {
    const labels = ['系统默认', '思源真黑', '思源宋体', '得意黑',
      '霞鹜文楷', '小米MiSans', '阿里巴巴普惠体', '庞门正道标题体',
      '站酷高端黑', '楷书'];
    return labels[_fontFamilyLevel.clamp(0, 9)];
  }
  double get textScale {
    switch (_fontSizeLevel) {
      case 1: return 1.15;
      case 2: return 1.30;
      default: return 1.0;
    }
  }
  String get fontSizeLabel {
    switch (_fontSizeLevel) {
      case 1: return '中号';
      case 2: return '大号';
      default: return '标准';
    }
  }

  void setTheme(ThemeType type) {
    _type = type;
    notifyListeners();
  }

  void setFontSize(int level) {
    _fontSizeLevel = level.clamp(0, 2);
    notifyListeners();
  }

  void setFontFamily(int level) {
    _fontFamilyLevel = level.clamp(0, 9);
    notifyListeners();
  }
}

enum ThemeType {
  inkBlue,    // 水墨蓝
  amberGold,  // 琥珀金
  jadeGreen,  // 翡翠青
}

/// 配色数据
class SchemeData {
  final String label;
  final Color primary, accent;
  final Color textPrimary, textSecondary, textDim;
  final Color bgDeep, bgMid, bgLight;
  final Color riskLow, riskMedium, riskHigh;
  final Color glassBg, glassBorder;
  final List<Color> inkGradient;

  const SchemeData({
    required this.label,
    required this.primary, required this.accent,
    required this.textPrimary, required this.textSecondary, required this.textDim,
    required this.bgDeep, required this.bgMid, required this.bgLight,
    required this.riskLow, required this.riskMedium, required this.riskHigh,
    required this.glassBg, required this.glassBorder,
    required this.inkGradient,
  });
}

/// 三套配色
const Map<ThemeType, SchemeData> schemeMap = {
  ThemeType.inkBlue: SchemeData(
    label: '水墨蓝',
    primary: Color(0xFF6CA8AF), accent: Color(0xFFA3BBDB),
    textPrimary: Color(0xFFD4E5EF), textSecondary: Color(0xFFA3BBDB), textDim: Color(0xFF576470),
    bgDeep: Color(0xFF0A0E16), bgMid: Color(0xFF151D29), bgLight: Color(0xFF1A2847),
    riskLow: Color(0xFF6CA8AF), riskMedium: Color(0xFFF29A76), riskHigh: Color(0xFFA81C2B),
    glassBg: Color(0x0FFFFFFF), glassBorder: Color(0x1AFFFFFF),
    inkGradient: [Color(0xFF0A0E16), Color(0xFF151D29), Color(0xFF1A2847)],
  ),
  ThemeType.amberGold: SchemeData(
    label: '琥珀金',
    primary: Color(0xFFD4A84B), accent: Color(0xFFE8C878),
    textPrimary: Color(0xFFF0E6D0), textSecondary: Color(0xFFD4C4A0), textDim: Color(0xFF8A7E68),
    bgDeep: Color(0xFF121008), bgMid: Color(0xFF1E1A10), bgLight: Color(0xFF2A2418),
    riskLow: Color(0xFF7BAE6A), riskMedium: Color(0xFFE8A84B), riskHigh: Color(0xFFC43E2A),
    glassBg: Color(0x0FFFFFFF), glassBorder: Color(0x1AFFFFFF),
    inkGradient: [Color(0xFF121008), Color(0xFF1E1A10), Color(0xFF2A2418)],
  ),
  ThemeType.jadeGreen: SchemeData(
    label: '翡翠青',
    primary: Color(0xFF5CB89A), accent: Color(0xFF8ED4BE),
    textPrimary: Color(0xFFE0F0EA), textSecondary: Color(0xFFA0D0C0), textDim: Color(0xFF607870),
    bgDeep: Color(0xFF080E0C), bgMid: Color(0xFF0F1A16), bgLight: Color(0xFF162620),
    riskLow: Color(0xFF5CB89A), riskMedium: Color(0xFFE8B84B), riskHigh: Color(0xFFC43E2A),
    glassBg: Color(0x0FFFFFFF), glassBorder: Color(0x1AFFFFFF),
    inkGradient: [Color(0xFF080E0C), Color(0xFF0F1A16), Color(0xFF162620)],
  ),
};
