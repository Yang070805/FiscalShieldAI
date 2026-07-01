import 'package:flutter/material.dart';
import '../config/colors.dart';
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
                  child: const Icon(Icons.arrow_back_rounded, color: AppColors.paper),
                ),
                const SizedBox(width: 12),
                const Text('设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
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
                      _item(Icons.palette_rounded, '主题颜色', '水墨蓝'),
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
          child: Text(title, style: const TextStyle(fontSize: 13, color: AppColors.paperDim)),
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
          Text(label, style: const TextStyle(fontSize: 15, color: AppColors.paper)),
          const Spacer(),
          if (trailing.isNotEmpty)
            Text(trailing, style: const TextStyle(fontSize: 13, color: AppColors.paperDim)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.paperDim),
        ]),
      ),
    );
  }
}
