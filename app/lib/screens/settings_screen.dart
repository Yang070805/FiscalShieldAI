import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';

import '../config/theme_schemes.dart';
import '../widgets/ink_world.dart';
import '../widgets/glass_widgets.dart';
import '../main.dart';
import 'avatar_picker_screen.dart';

/// 设置页
class SettingsScreen extends StatelessWidget {
  final bool isGuest;
  const SettingsScreen({super.key, this.isGuest = false});

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
                      _item(Icons.phone_rounded, '绑定手机号', isGuest ? '未绑定' : '138****0000'),
                      _item(Icons.link_rounded, '绑定社交账号', '未绑定'),
                      _item(Icons.lock_rounded, '修改密码', ''),
                    ]),
                    const SizedBox(height: 16),
                    _section('个性化', [
                      _fontSizeItem(context),
                      _fontFamilyItem(context),
                      _themeItem(context),
                      _avatarItem(context),
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

  /// 头像设置项
  Widget _avatarItem(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AvatarPickerScreen()));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(Icons.face_rounded, size: 20, color: AppColors.sky),
          const SizedBox(width: 12),
          Text('头像设置', style: TextStyle(fontSize: 15, color: AppColors.paper)),
          const Spacer(),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.glassBorder)),
            child: ClipOval(child: Image.asset(themeNotifier.avatarPath, fit: BoxFit.cover)),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.paperDim),
        ]),
      ),
    );
  }

  /// 字体选择项
  Widget _fontFamilyItem(BuildContext context) {
    return InkWell(
      onTap: () => _showFontFamilyPicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(Icons.font_download_rounded, size: 20, color: AppColors.sky),
          const SizedBox(width: 12),
          Text('字体样式', style: TextStyle(fontSize: 15, color: AppColors.paper)),
          const Spacer(),
          Text(themeNotifier.fontFamilyLabel, style: TextStyle(fontSize: 13, color: AppColors.paperDim)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.paperDim),
        ]),
      ),
    );
  }

  void _showFontFamilyPicker(BuildContext context) {
    final labels = ['系统默认', '思源真黑', '思源宋体', '得意黑',
      '霞鹜文楷', '小米MiSans', '阿里巴巴普惠体', '庞门正道标题体',
      '站酷高端黑', '楷书'];
    final fontFamilies = [null, 'SourceHanSans', 'SourceHanSerif', 'SmileySans',
      'LXGWWenKai', 'MiSans', 'AlibabaPuHuiTi', 'PangMenBiaoDaoTi',
      'ZhanKuGaoDuanHei', 'STKaiti'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: AppColors.deepBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('字体样式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: 10,
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () async {
                    themeNotifier.setFontFamily(i);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('fontFamily', i);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: themeNotifier.fontFamilyLevel == i
                          ? AppColors.celadon.withOpacity(0.15)
                          : AppColors.glassWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: themeNotifier.fontFamilyLevel == i
                            ? AppColors.celadon.withOpacity(0.6)
                            : AppColors.glassBorder,
                        width: themeNotifier.fontFamilyLevel == i ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          i == 0 ? Icons.phone_android_rounded
                              : i == 1 ? Icons.font_download_rounded
                              : Icons.create_rounded,
                          color: themeNotifier.fontFamilyLevel == i ? AppColors.celadon : AppColors.paperDim,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(labels[i], style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: fontFamilies[i],
                          color: themeNotifier.fontFamilyLevel == i ? AppColors.celadon : AppColors.paper,
                          decoration: TextDecoration.none,
                        )),
                        const Spacer(),
                        if (themeNotifier.fontFamilyLevel == i)
                          Icon(Icons.check_circle_rounded, color: AppColors.celadon, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 字体大小切换项
  Widget _fontSizeItem(BuildContext context) {
    return InkWell(
      onTap: () => _showFontSizePicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(Icons.text_fields_rounded, size: 20, color: AppColors.sky),
          const SizedBox(width: 12),
          Text('字体大小', style: TextStyle(fontSize: 15, color: AppColors.paper)),
          const Spacer(),
          Text(themeNotifier.fontSizeLabel, style: TextStyle(fontSize: 13, color: AppColors.paperDim)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.paperDim),
        ]),
      ),
    );
  }

  void _showFontSizePicker(BuildContext context) {
    final labels = ['标准', '中号', '大号'];
    final scales = ['1.0x', '1.15x', '1.30x'];
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
            Text('字体大小', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
            const SizedBox(height: 16),
            for (int i = 0; i < 3; i++)
              GestureDetector(
                onTap: () async {
                  themeNotifier.setFontSize(i);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('fontSize', i);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: themeNotifier.fontSizeLevel == i
                        ? AppColors.celadon.withOpacity(0.15)
                        : AppColors.glassWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: themeNotifier.fontSizeLevel == i
                          ? AppColors.celadon.withOpacity(0.6)
                          : AppColors.glassBorder,
                      width: themeNotifier.fontSizeLevel == i ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        i == 0 ? Icons.text_fields_rounded
                            : i == 1 ? Icons.format_size
                            : Icons.text_increase_rounded,
                        color: themeNotifier.fontSizeLevel == i ? AppColors.celadon : AppColors.paperDim,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Text(labels[i], style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: themeNotifier.fontSizeLevel == i ? AppColors.celadon : AppColors.paper,
                        decoration: TextDecoration.none,
                      )),
                      const SizedBox(width: 8),
                      Text(scales[i], style: TextStyle(
                        fontSize: 12,
                        color: AppColors.paperDim,
                        decoration: TextDecoration.none,
                      )),
                      const Spacer(),
                      if (themeNotifier.fontSizeLevel == i)
                        Icon(Icons.check_circle_rounded, color: AppColors.celadon, size: 22),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
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
