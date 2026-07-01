import 'package:flutter/material.dart';

/// 水墨·璃 配色系统 — 基于 shuimo-ui 五行配色
class AppColors {
  // ── 水·冬（主色调） ──
  static const Color tajian = Color(0xFF151D29);      // 獭见 · 最深墨
  static const Color jingyuan = Color(0xFF31322C);     // 京元 · 深墨
  static const Color huaqing = Color(0xFF1A2847);      // 花青 · 墨蓝
  static const Color zhengqing = Color(0xFF6CA8AF);    // 正青 · 青瓷（主色）
  static const Color yuebai = Color(0xFFD4E5EF);       // 月白 · 文字主色
  static const Color qingshan = Color(0xFFA3BBDB);     // 晴山 · 文字次色
  static const Color yuyangran = Color(0xFF576470);    // 育阳染 · 文字辅助
  static const Color ziyan = Color(0xFF757CBB);        // 紫苑 · 紫调点缀

  // ── 火·夏（风险/警示） ──
  static const Color daran = Color(0xFFA81C2B);        // 大繎 · 朱砂红
  static const Color wozhe = Color(0xFFDD6B7B);        // 渥赭 · 暖红
  static const Color zhuyantuo = Color(0xFFF29A76);    // 朱颜酡 · 暖杏
  static const Color chunzhi = Color(0xFFC25160);      // 唇脂 · 深粉

  // ── 金·秋（点缀/背景） ──
  static const Color gaoyu = Color(0xFFEFEFEF);        // 缟羽 · 纯白
  static const Color yuse = Color(0xFFEAE4D1);         // 玉色 · 暖白
  static const Color huaQing = Color(0xFF1A2847);      // 花青 · 深蓝

  // ── 木·春（辅助） ──
  static const Color qingdai = Color(0xFF45465E);      // 青黛 · 灰紫
  static const Color piaobi = Color(0xFFC0D695);       // 缥碧 · 浅绿

  // ── 语义色（基于五行） ──
  static const Color riskLow = Color(0xFF6CA8AF);      // 正青 · 安全
  static const Color riskMedium = Color(0xFFF29A76);   // 朱颜酡 · 中等
  static const Color riskHigh = Color(0xFFA81C2B);     // 大繎 · 高风险
  static const Color accent = Color(0xFF6CA8AF);       // 正青 · 强调
  static const Color accentLight = Color(0xFFA3BBDB);  // 晴山 · 浅强调

  // ── 便捷别名 ──
  static const Color paper = yuebai;           // 文字主色
  static const Color paperMid = qingshan;      // 文字次色
  static const Color paperDim = yuyangran;     // 文字辅助
  static const Color deepBg = tajian;          // 深色背景
  static const Color cardBg = huaqing;         // 卡片背景
  static const Color celadon = zhengqing;      // 青瓷蓝
  static const Color sky = qingshan;           // 天蓝
  static const Color glow = ziyan;             // 紫苑光效
  static const Color warmApricot = zhuyantuo;  // 暖杏
  static const Color teal = zhengqing;         // 正青

  // ── 玻璃色 ──
  static const Color glassWhite = Color(0x0FFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color glassHover = Color(0x1FFFFFFF);

  // ── 墨色渐变 ──
  static const LinearGradient inkGradient = LinearGradient(
    begin: Alignment(-0.5, -1),
    end: Alignment(0.5, 1),
    colors: [tajian, jingyuan, huaqing],
  );

  /// 风险等级颜色
  static Color riskColor(String level) {
    if (level.contains('高') || level.contains('严重')) return riskHigh;
    if (level.contains('中等偏高')) return wozhe;
    if (level.contains('中等')) return riskMedium;
    if (level.contains('低')) return riskLow;
    return yuyangran;
  }
}
