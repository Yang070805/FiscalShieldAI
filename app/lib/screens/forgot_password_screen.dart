import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../widgets/ink_world.dart';
import '../widgets/glass_widgets.dart';

/// 忘记密码页
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _pwdController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();
  final _pwdFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _phoneFocused = false;
  bool _codeFocused = false;
  bool _pwdFocused = false;
  bool _confirmFocused = false;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() => setState(() => _phoneFocused = _phoneFocus.hasFocus));
    _codeFocus.addListener(() => setState(() => _codeFocused = _codeFocus.hasFocus));
    _pwdFocus.addListener(() => setState(() => _pwdFocused = _pwdFocus.hasFocus));
    _confirmFocus.addListener(() => setState(() => _confirmFocused = _confirmFocus.hasFocus));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _pwdController.dispose();
    _confirmController.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    _pwdFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _onReset() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final pwd = _pwdController.text;
    final confirm = _confirmController.text;

    if (phone.length != 11) { _showError('请输入11位手机号'); return; }
    if (code.length != 6) { _showError('请输入6位验证码'); return; }
    if (pwd.length < 6) { _showError('密码至少6位'); return; }
    if (pwd != confirm) { _showError('两次密码不一致'); return; }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // 从用户列表查找并更新密码
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString('users') ?? '[]';
    final users = List<Map<String, dynamic>>.from(
      (jsonDecode(usersJson) as List).map((e) => Map<String, dynamic>.from(e)),
    );

    final userIndex = users.indexWhere((u) => u['phone'] == phone);
    if (userIndex == -1) {
      setState(() => _isLoading = false);
      _showError('该手机号未注册');
      return;
    }

    users[userIndex]['pwd'] = pwd;
    await prefs.setString('users', jsonEncode(users));
    await prefs.commit();

    setState(() => _isLoading = false);
    _showSuccess('密码重置成功，请重新登录');
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
      child: InkWorld(
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
                    Text('重置密码', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        // 图标
                        Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.celadon.withOpacity(0.1),
                            border: Border.all(color: AppColors.celadon.withOpacity(0.3)),
                          ),
                          child: Icon(Icons.lock_reset_rounded, size: 36, color: AppColors.celadon),
                        ),
                        const SizedBox(height: 16),
                        Text('输入手机号和验证码\n设置新密码', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppColors.paperMid, height: 1.5, decoration: TextDecoration.none)),
                        const SizedBox(height: 30),
                        // 表单
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              _buildInput(_pwdController, '新密码（至少6位）', Icons.lock_rounded, TextInputType.visiblePassword,
                                obscure: _obscurePwd, focusNode: _pwdFocus, focused: _pwdFocused,
                                suffix: GestureDetector(
                                  onTap: () => setState(() => _obscurePwd = !_obscurePwd),
                                  child: Icon(_obscurePwd ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 20, color: _pwdFocused ? AppColors.celadon : AppColors.paperDim),
                                )),
                              const SizedBox(height: 14),
                              _buildInput(_confirmController, '确认新密码', Icons.lock_rounded, TextInputType.visiblePassword,
                                obscure: _obscureConfirm, focusNode: _confirmFocus, focused: _confirmFocused,
                                suffix: GestureDetector(
                                  onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  child: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 20, color: _confirmFocused ? AppColors.celadon : AppColors.paperDim),
                                )),
                              const SizedBox(height: 28),
                              // 重置按钮
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _onReset,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.celadon,
                                    disabledBackgroundColor: AppColors.glassWhite,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                                      : const Text('重置密码', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 4, decoration: TextDecoration.none)),
                                ),
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
