import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../config/fonts.dart';
import '../widgets/ink_world.dart';
import '../widgets/glass_widgets.dart';

/// 注册页
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _pwdController = TextEditingController();
  final _pwdConfirmController = TextEditingController();
  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();
  final _nicknameFocus = FocusNode();
  final _pwdFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _phoneFocused = false;
  bool _codeFocused = false;
  bool _nicknameFocused = false;
  bool _pwdFocused = false;
  bool _confirmFocused = false;
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() => setState(() => _phoneFocused = _phoneFocus.hasFocus));
    _codeFocus.addListener(() => setState(() => _codeFocused = _codeFocus.hasFocus));
    _nicknameFocus.addListener(() => setState(() => _nicknameFocused = _nicknameFocus.hasFocus));
    _pwdFocus.addListener(() => setState(() => _pwdFocused = _pwdFocus.hasFocus));
    _confirmFocus.addListener(() => setState(() => _confirmFocused = _confirmFocus.hasFocus));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nicknameController.dispose();
    _pwdController.dispose();
    _pwdConfirmController.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    _nicknameFocus.dispose();
    _pwdFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _onRegister() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final nickname = _nicknameController.text.trim();
    final pwd = _pwdController.text;
    final confirm = _pwdConfirmController.text;

    if (_selectedRole == null) { _showError('请选择注册角色'); return; }
    if (phone.length != 11) { _showError('请输入11位手机号'); return; }
    if (code.length != 6) { _showError('请输入6位验证码'); return; }
    if (nickname.isEmpty) { _showError('请输入昵称'); return; }
    if (pwd.length < 6) { _showError('密码至少6位'); return; }
    if (pwd != confirm) { _showError('两次密码不一致'); return; }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // 保存用户列表（JSON）
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString('users') ?? '[]';
    final users = List<Map<String, dynamic>>.from(
      (jsonDecode(usersJson) as List).map((e) => Map<String, dynamic>.from(e)),
    );

    // 检查手机号是否已注册
    final exists = users.any((u) => u['phone'] == phone);
    if (exists) {
      setState(() => _isLoading = false);
      _showError('该手机号已注册');
      return;
    }

    // 添加新用户
    users.add({
      'phone': phone,
      'pwd': pwd,
      'nickname': nickname,
      'role': _selectedRole!,
    });
    await prefs.setString('users', jsonEncode(users));

    setState(() => _isLoading = false);
    _showSuccess('注册成功，请登录');
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) Navigator.pop(context);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.riskHigh, duration: const Duration(seconds: 2)),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.celadon, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: InkWorld(
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
                    Text('注册账号', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Logo
                        Image.asset('assets/images/logo_transparent.png', width: 60, height: 60, fit: BoxFit.contain),
                        const SizedBox(height: 30),
                        // 注册表单
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('创建账号', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                              const SizedBox(height: 16),
                              // 角色选择
                              Text('选择角色', style: TextStyle(fontSize: 13, color: AppColors.paperDim, decoration: TextDecoration.none)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _roleOption('政务版', Icons.account_balance_rounded, AppColors.celadon),
                                  const SizedBox(width: 8),
                                  _roleOption('企业版', Icons.business_rounded, AppColors.sky),
                                  const SizedBox(width: 8),
                                  _roleOption('民用版', Icons.person_rounded, AppColors.teal),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const SizedBox(height: 24),
                              _buildInput(_phoneController, '手机号', Icons.phone_rounded, TextInputType.phone,
                                focusNode: _phoneFocus, focused: _phoneFocused, maxLength: 11),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(child: _buildInput(_codeController, '验证码', Icons.verified_rounded, TextInputType.number,
                                    focusNode: _codeFocus, focused: _codeFocused, maxLength: 6)),
                                  const SizedBox(width: 12),
                                  _buildCodeBtn(),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildInput(_nicknameController, '昵称', Icons.person_rounded, TextInputType.text,
                                focusNode: _nicknameFocus, focused: _nicknameFocused),
                              const SizedBox(height: 14),
                              _buildInput(_pwdController, '密码（至少6位）', Icons.lock_rounded, TextInputType.visiblePassword,
                                obscure: _obscurePwd, focusNode: _pwdFocus, focused: _pwdFocused,
                                suffix: GestureDetector(
                                  onTap: () => setState(() => _obscurePwd = !_obscurePwd),
                                  child: Icon(_obscurePwd ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 20, color: _pwdFocused ? AppColors.celadon : AppColors.paperDim),
                                )),
                              const SizedBox(height: 14),
                              _buildInput(_pwdConfirmController, '确认密码', Icons.lock_rounded, TextInputType.visiblePassword,
                                obscure: _obscureConfirm, focusNode: _confirmFocus, focused: _confirmFocused,
                                suffix: GestureDetector(
                                  onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  child: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 20, color: _confirmFocused ? AppColors.celadon : AppColors.paperDim),
                                )),
                              const SizedBox(height: 28),
                              // 注册按钮
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _onRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.celadon,
                                    disabledBackgroundColor: AppColors.glassWhite,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                                      : const Text('注  册', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 4, decoration: TextDecoration.none)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // 去登录
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('已有账号？', style: TextStyle(fontSize: 13, color: AppColors.paperDim, decoration: TextDecoration.none)),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Text('去登录', style: TextStyle(fontSize: 13, color: AppColors.celadon, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _roleOption(String role, IconData icon, Color color) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.5) : AppColors.glassBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: isSelected ? color : AppColors.paperDim),
              const SizedBox(height: 4),
              Text(role, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? color : AppColors.paperDim, decoration: TextDecoration.none)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController c, String label, IconData icon, TextInputType type,
      {bool obscure = false, Widget? suffix, FocusNode? focusNode, bool focused = false, int? maxLength}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? AppColors.celadon.withOpacity(0.6) : AppColors.glassBorder,
          width: focused ? 1.5 : 1,
        ),
        boxShadow: focused ? [BoxShadow(color: AppColors.celadon.withOpacity(0.1), blurRadius: 8)] : null,
      ),
      child: TextField(
        controller: c,
        focusNode: focusNode,
        keyboardType: type,
        obscureText: obscure,
        maxLength: maxLength,
        style: TextStyle(color: AppColors.paper, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: focused ? AppColors.celadon : AppColors.paperDim),
          prefixIcon: Icon(icon, size: 20, color: focused ? AppColors.celadon : AppColors.paperDim),
          suffixIcon: suffix,
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCodeBtn() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: () {
          final phone = _phoneController.text.trim();
          if (phone.length != 11) {
            _showError('请先输入11位手机号');
            return;
          }
          _showError('验证码已发送（模拟）');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.celadon.withOpacity(0.3),
          foregroundColor: AppColors.sky,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('获取验证码', style: TextStyle(fontSize: 13, decoration: TextDecoration.none)),
      ),
    );
  }
}
