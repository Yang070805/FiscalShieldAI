import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';

import '../config/theme_schemes.dart';
import '../widgets/ink_world.dart';
import '../widgets/glass_widgets.dart';

/// 设置页
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWorld(
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
          children: [
            // 顶栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_rounded, color: AppColors.paper),
                ),
                const SizedBox(width: 12),
                Text('设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _section('账号与安全', [
                      _item(Icons.phone_rounded, '绑定手机号', '138****0000'),
                      _item(Icons.link_rounded, '绑定社交账号', '未绑定'),
                      _item(Icons.lock_rounded, '修改密码', ''),
                    ]),
                    const SizedBox(height: 16),
                    _section('个性化', [
                      _item(Icons.text_fields_rounded, '字体大小', '标准'),
                      _themeItem(context),
                      _item(Icons.face_rounded, '头像设置', ''),
                    ]),
                    const SizedBox(height: 16),
                    _section('隐私与数据', [
                      _item(Icons.shield_rounded, '数据脱敏说明', ''),
                      _item(Icons.delete_outline_rounded, '清除本地缓存', '12.3 MB'),
                    ]),
                    const SizedBox(height: 16),
                    _section('关于', [
                      _item(Icons.info_outline_rounded, '版本信息', 'v1.0.0'),
                    ]),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: TextStyle(fontSize: 13, color: AppColors.paperDim)),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _item(IconData icon, String label, String trailing) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.sky),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 15, color: AppColors.paper)),
          const Spacer(),
          if (trailing.isNotEmpty)
            Text(trailing, style: TextStyle(fontSize: 13, color: AppColors.paperDim)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.paperDim),
        ]),
      ),
    );
  }

  /// 主题切换项
  Widget _themeItem(BuildContext context) {
    final current = themeNotifier.type;
    final s = schemeMap[current]!;
    return InkWell(
      onTap: () => _showThemePicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(Icons.palette_rounded, size: 20, color: AppColors.sky),
          const SizedBox(width: 12),
          Text('主题颜色', style: TextStyle(fontSize: 15, color: AppColors.paper)),
          const Spacer(),
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(shape: BoxShape.circle, color: s.primary),
          ),
          const SizedBox(width: 8),
          Text(s.label, style: TextStyle(fontSize: 13, color: AppColors.paperDim)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.paperDim),
        ]),
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.deepBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择主题', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
            const SizedBox(height: 16),
            ...ThemeType.values.map((type) {
              final s = schemeMap[type]!;
              final isSelected = themeNotifier.type == type;
              return GestureDetector(
                onTap: () async {
                  themeNotifier.setTheme(type);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('theme', type.name);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? s.primary.withOpacity(0.15) : AppColors.glassWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? s.primary.withOpacity(0.6) : AppColors.glassBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [s.bgDeep, s.bgMid, s.bgLight],
                          ),
                        ),
                        child: Center(
                          child: Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: s.primary)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(s.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isSelected ? s.primary : AppColors.paper, decoration: TextDecoration.none)),
                      const Spacer(),
                      if (isSelected) Icon(Icons.check_circle_rounded, color: s.primary, size: 22),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
