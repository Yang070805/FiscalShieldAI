import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../config/theme_schemes.dart';
import '../widgets/glass_widgets.dart';
import 'avatar_picker_screen.dart';
import 'settings_screen.dart';

/// 个人中心
class ProfileTab extends StatefulWidget {
  final String role;
  final bool isGuest;
  const ProfileTab({super.key, required this.role, this.isGuest = false});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String _nickname = 'FiscalShield AI用户';
  String _phone = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final loginPhone = prefs.getString('loginPhone') ?? '';
    final loginRole = prefs.getString('loginRole') ?? widget.role;
    final usersJson = prefs.getString('users') ?? '[]';
    final users = List<Map<String, dynamic>>.from(
      (jsonDecode(usersJson) as List).map((e) => Map<String, dynamic>.from(e)),
    );
    final user = users.cast<Map<String, dynamic>?>().firstWhere(
      (u) => u?['phone'] == loginPhone,
      orElse: () => null,
    );
    if (mounted) {
      setState(() {
        _nickname = user?['nickname'] ?? 'FiscalShield AI用户';
        _phone = loginPhone;
        _role = loginRole;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // 头像
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AvatarPickerScreen()));
            },
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.celadon.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.celadon.withOpacity(0.3),
                      blurRadius: 24,
                      spreadRadius: 4)
                ],
              ),
              child: ClipOval(
                child: themeNotifier.avatarName == 'custom'
                    ? Image.file(File(themeNotifier.avatarPath),
                        fit: BoxFit.cover)
                    : Image.asset(themeNotifier.avatarPath, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(_nickname,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.paper,
                  decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text('$_role · ${_phone.isNotEmpty ? _phone : '未登录'}',
              style: TextStyle(fontSize: 13, color: AppColors.paperMid)),
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
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(isGuest: widget.isGuest)));
              }),
              _divider(),
              _menuItem(Icons.info_outline_rounded, '关于', () {}),
              _divider(),
              _menuItem(Icons.logout_rounded, '退出登录', () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('loginPhone');
                await prefs.remove('loginRole');
                await prefs.remove('users');
                themeNotifier.setTheme(ThemeType.inkBlue);
                themeNotifier.setFontSize(0);
                themeNotifier.setFontFamily(0);
                themeNotifier.setAvatar('bamboo');
                themeNotifier.setCustomAvatarPath('');
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                }
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
