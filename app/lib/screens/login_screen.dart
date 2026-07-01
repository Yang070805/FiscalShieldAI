import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../widgets/ink_world.dart';
import '../widgets/glass_widgets.dart';
import 'main_screen.dart';

/// 登录页 — 三角色 + 账号密码
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _selectedRole;
  final _phoneController = TextEditingController();
  final _pwdController = TextEditingController();
  final _codeController = TextEditingController();
  bool _obscurePwd = true;

  final List<_RoleData> _roles = [
    _RoleData('政务版', Icons.account_balance_rounded, '标准化 · 高合规', AppColors.celadon),
    _RoleData('企业版', Icons.business_rounded, '团队协作 · 深度分析', AppColors.sky),
    _RoleData('民用版', Icons.person_rounded, '轻量易用 · 隐私优先', AppColors.teal),
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _pwdController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_selectedRole == null) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => MainScreen(role: _selectedRole!),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _onGuest() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainScreen(role: '民用版', isGuest: true),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWorld(
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
              const SizedBox(height: 60),
              // 标题
              const Text('财智哨兵', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.paper, letterSpacing: 4, decoration: TextDecoration.none)),
              const SizedBox(height: 6),
              Text('地方财政风险智能预警系统', style: TextStyle(fontSize: 13, color: AppColors.paperMid)),
              const SizedBox(height: 40),
              // 登录卡片
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 角色选择
                    const Text('选择版本', style: TextStyle(fontSize: 14, color: AppColors.paperDim)),
                    const SizedBox(height: 12),
                    Row(
                      children: _roles.map((r) => Expanded(child: _buildRoleChip(r))).toList(),
                    ),
                    const SizedBox(height: 24),
                    // 手机号
                    _buildInput(_phoneController, '手机号', Icons.phone_rounded, TextInputType.phone),
                    const SizedBox(height: 14),
                    // 密码
                    _buildInput(_pwdController, '密码', Icons.lock_rounded, TextInputType.visiblePassword, obscure: _obscurePwd, suffix: IconButton(
                      icon: Icon(_obscurePwd ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: AppColors.paperDim),
                      onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                    )),
                    const SizedBox(height: 14),
                    // 验证码
                    Row(
                      children: [
                        Expanded(child: _buildInput(_codeController, '验证码', Icons.verified_rounded, TextInputType.number)),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.celadon.withOpacity(0.3),
                              foregroundColor: AppColors.sky,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: const Text('获取验证码', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // 登录按钮
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _selectedRole != null ? _onLogin : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.celadon,
                          disabledBackgroundColor: AppColors.glassWhite,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _selectedRole != null ? '登  录' : '请选择版本',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 游客入口
              GestureDetector(
                onTap: _onGuest,
                child: Text('游客模式（限时体验）', style: TextStyle(fontSize: 13, color: AppColors.sky.withOpacity(0.7))),
              ),
              const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(_RoleData r) {
    final isSelected = _selectedRole == r.name;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = r.name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? r.color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? r.color.withOpacity(0.5) : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(r.icon, size: 26, color: isSelected ? r.color : AppColors.paperDim),
            const SizedBox(height: 6),
            Text(r.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? r.color : AppColors.paperDim)),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController c, String label, IconData icon, TextInputType type, {bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: c,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.paper, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.paperDim),
        suffixIcon: suffix,
      ),
    );
  }
}

class _RoleData {
  final String name;
  final IconData icon;
  final String desc;
  final Color color;
  _RoleData(this.name, this.icon, this.desc, this.color);
}
