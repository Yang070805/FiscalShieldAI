import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../widgets/glass_widgets.dart';
import 'settings_screen.dart';

/// 个人中心
class ProfileTab extends StatelessWidget {
  final String role;
  final bool isGuest;
  const ProfileTab({super.key, required this.role, this.isGuest = false});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // 头像
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.celadon, AppColors.sky]),
              boxShadow: [BoxShadow(color: AppColors.celadon.withOpacity(0.3), blurRadius: 24, spreadRadius: 4)],
            ),
            child: const Icon(Icons.person_rounded, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text('FiscalShield AI用户', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text('$role · 南京', style: TextStyle(fontSize: 13, color: AppColors.paperMid)),
          const SizedBox(height: 28),
          // 统计
          Row(
            children: [
              Expanded(child: _statCard('预测次数', '0')),
              const SizedBox(width: 10),
              Expanded(child: _statCard('收藏数', '0')),
              const SizedBox(width: 10),
              Expanded(child: _statCard('注册时间', '未注册')),
            ],
          ),
          const SizedBox(height: 20),
          // 菜单
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _menuItem(Icons.swap_horiz_rounded, '切换身份', () {}),
              _divider(),
              _menuItem(Icons.settings_rounded, '设置', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(isGuest: isGuest)));
              }),
              _divider(),
              _menuItem(Icons.info_outline_rounded, '关于', () {}),
              _divider(),
              _menuItem(Icons.logout_rounded, '退出登录', () {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
              }, isDestructive: true),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(value, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.sky, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    final color = isDestructive ? AppColors.riskHigh : AppColors.paper;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: color))),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.paperDim),
        ]),
      ),
    );
  }

  Widget _divider() => Divider(height: 1, indent: 48, color: AppColors.glassBorder);
}
