import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../config/theme_schemes.dart';
import '../widgets/glass_widgets.dart';
import '../services/api_service.dart';
import 'about_screen.dart';
import 'avatar_picker_screen.dart';
import 'settings_screen.dart';

/// 个人中心
class ProfileTab extends StatefulWidget {
  final String role;
  final bool isGuest;
  final ValueChanged<String>? onRoleSwitch;
  const ProfileTab({super.key, required this.role, this.isGuest = false, this.onRoleSwitch});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ApiService _api = ApiService();
  String _nickname = 'FiscalShield AI用户';
  String _phone = '';
  String _role = '';
  String _createdAt = '';

  // code → 中文名
  static const Map<String, String> _roleNames = {
    'gov': '政务版',
    'enterprise': '企业版',
    'citizen': '民用版',
  };

  String _displayName(String code) => _roleNames[code] ?? code;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final loginPhone = prefs.getString('loginPhone') ?? '';
    final loginRole = prefs.getString('loginRole') ?? widget.role;
    final nickname = prefs.getString('loginNickname') ?? '';
    final createdAt = prefs.getString('loginCreatedAt') ?? '';
    if (mounted) {
      setState(() {
        _nickname = nickname.isNotEmpty ? nickname : 'FiscalShield AI用户';
        _phone = loginPhone;
        _role = loginRole;
        _createdAt = createdAt;
      });
    }
  }

  void _showRoleSwitchDialog() async {
    final prefs = await SharedPreferences.getInstance();
    // 读取注册角色（后端返回的角色 code）
    final registeredRole = prefs.getString('loginRegisteredRole') ?? prefs.getString('loginRole') ?? 'citizen';

    final availableRoles = <Map<String, dynamic>>[];

    if (registeredRole == 'gov') {
      availableRoles.add({'code': 'gov', 'icon': Icons.account_balance_rounded, 'desc': '财政风险监测', 'enabled': true});
      availableRoles.add({'code': 'citizen', 'icon': Icons.person_rounded, 'desc': '公共数据查询', 'enabled': true});
      availableRoles.add({'code': 'enterprise', 'icon': Icons.business_rounded, 'desc': '无权限', 'enabled': false});
    } else if (registeredRole == 'enterprise') {
      availableRoles.add({'code': 'enterprise', 'icon': Icons.business_rounded, 'desc': '企业风险分析', 'enabled': true});
      availableRoles.add({'code': 'citizen', 'icon': Icons.person_rounded, 'desc': '公共数据查询', 'enabled': true});
      availableRoles.add({'code': 'gov', 'icon': Icons.account_balance_rounded, 'desc': '无权限', 'enabled': false});
    } else {
      availableRoles.add({'code': 'citizen', 'icon': Icons.person_rounded, 'desc': '公共数据查询', 'enabled': true});
      availableRoles.add({'code': 'gov', 'icon': Icons.account_balance_rounded, 'desc': '无权限', 'enabled': false});
      availableRoles.add({'code': 'enterprise', 'icon': Icons.business_rounded, 'desc': '无权限', 'enabled': false});
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.glassBorder)),
        title: Row(children: [
          Icon(Icons.swap_horiz_rounded, color: AppColors.celadon, size: 22),
          const SizedBox(width: 8),
          Text('切换身份', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableRoles.map((r) {
            final code = r['code'] as String;
            final isEnabled = r['enabled'] as bool;
            final isCurrent = code == _role;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isEnabled && !isCurrent ? () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('loginRole', code);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      setState(() => _role = code);
                      widget.onRoleSwitch?.call(code);
                    }
                  } : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.celadon.withOpacity(0.12)
                          : AppColors.glassWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.celadon.withOpacity(0.5)
                            : isEnabled
                                ? AppColors.glassBorder
                                : AppColors.glassBorder.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(r['icon'] as IconData, size: 22, color: isCurrent ? AppColors.celadon : isEnabled ? AppColors.paperDim : AppColors.paperDim.withOpacity(0.3)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_displayName(code), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isCurrent ? AppColors.celadon : isEnabled ? AppColors.paper : AppColors.paperDim.withOpacity(0.5), decoration: TextDecoration.none)),
                              Text(r['desc'] as String, style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
                            ],
                          ),
                        ),
                        if (isCurrent)
                          Text('当前', style: TextStyle(fontSize: 12, color: AppColors.celadon, fontWeight: FontWeight.w600)),
                        if (!isEnabled && !isCurrent)
                          Icon(Icons.lock_rounded, size: 16, color: AppColors.paperDim.withOpacity(0.3)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: AppColors.paperDim)),
          ),
        ],
      ),
    );
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
          Text('${_displayName(_role)} · ${_phone.isNotEmpty ? _phone : '未登录'}',
              style: TextStyle(fontSize: 13, color: AppColors.paperMid)),
          const SizedBox(height: 28),
          // 统计
          Row(
            children: [
              Expanded(child: _statCard('预测次数', '0')),
              const SizedBox(width: 10),
              Expanded(child: _statCard('收藏数', '0')),
              const SizedBox(width: 10),
              Expanded(child: _statCard('注册时间', _createdAt.isNotEmpty ? _createdAt.substring(5, 10) : '未注册')),
            ],
          ),
          const SizedBox(height: 20),
          // 菜单
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _menuItem(Icons.swap_horiz_rounded, '切换身份', () => _showRoleSwitchDialog()),
              _divider(),
              _menuItem(Icons.settings_rounded, '设置', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(isGuest: widget.isGuest)));
              }),
              _divider(),
              _menuItem(Icons.info_outline_rounded, '关于', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
              }),
              _divider(),
              _menuItem(Icons.logout_rounded, '退出登录', () async {
                await _api.logout();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('loginPhone');
                await prefs.remove('loginRole');
                await prefs.remove('loginRegisteredRole');
                await prefs.remove('loginNickname');
                await prefs.remove('loginUserPhone');
                await prefs.remove('loginCreatedAt');
                await prefs.remove('auth_token');
                themeNotifier.setTheme(ThemeType.inkBlue);
                AppColors.update(ThemeType.inkBlue);
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: value.length > 6 ? 14 : 20, fontWeight: FontWeight.bold, color: AppColors.sky, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
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
