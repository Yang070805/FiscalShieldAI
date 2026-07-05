import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../config/fonts.dart';
import '../config/theme_schemes.dart';
import '../widgets/ink_world.dart';
import '../widgets/glass_widgets.dart';
import '../services/api_service.dart';
import 'main_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

/// 登录页 — 三角色 + 账号密码 + 后端认证
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _api = ApiService();
  String? _selectedRole;
  final _phoneController = TextEditingController();
  final _pwdController = TextEditingController();
  final _codeController = TextEditingController();
  bool _obscurePwd = true;
  bool _agreed = false;
  bool _isLoading = false;

  // 聚焦状态
  final _phoneFocus = FocusNode();
  final _pwdFocus = FocusNode();
  final _codeFocus = FocusNode();
  bool _phoneFocused = false;
  bool _pwdFocused = false;
  bool _codeFocused = false;

  // 角色名映射（UI名 → 后端code）
  static const Map<String, String> _roleNameToCode = {
    '政务版': 'gov',
    '企业版': 'enterprise',
    '民用版': 'citizen',
  };
  static const Map<String, String> _roleCodeToName = {
    'gov': '政务版',
    'enterprise': '企业版',
    'citizen': '民用版',
  };

  final List<_RoleData> _roles = [
    _RoleData('政务版', Icons.account_balance_rounded, '标准化 · 高合规', AppColors.celadon),
    _RoleData('企业版', Icons.business_rounded, '团队协作 · 深度分析', AppColors.sky),
    _RoleData('民用版', Icons.person_rounded, '轻量易用 · 隐私优先', AppColors.teal),
  ];

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() => setState(() => _phoneFocused = _phoneFocus.hasFocus));
    _pwdFocus.addListener(() => setState(() => _pwdFocused = _pwdFocus.hasFocus));
    _codeFocus.addListener(() => setState(() => _codeFocused = _codeFocus.hasFocus));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pwdController.dispose();
    _codeController.dispose();
    _phoneFocus.dispose();
    _pwdFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  /// 登录 — 调后端 API
  void _onLogin() async {
    if (_selectedRole == null || !_agreed) return;

    final phone = _phoneController.text.trim();
    final pwd = _pwdController.text;

    // 表单验证
    if (phone.length != 11) {
      _showError('请输入11位手机号');
      return;
    }
    if (pwd.length < 6) {
      _showError('密码至少6位');
      return;
    }
    // 验证码（开发阶段可选）

    setState(() => _isLoading = true);

    try {
      final result = await _api.login(phone: phone, password: pwd);

      if (result['success'] != true) {
        if (!mounted) return;
        _showError(result['message'] ?? '登录失败');
        return;
      }

      final data = result['data'];
      final userRole = data['user']['role'] ?? 'citizen';
      final displayName = _roleCodeToName[userRole] ?? '民用版';
      final selectedCode = _roleNameToCode[_selectedRole!]!;

      // 检查角色权限（政务→政务+民用，企业→企业+民用，民用→仅民用）
      bool allowed = false;
      if (userRole == 'gov' && (selectedCode == 'gov' || selectedCode == 'citizen')) {
        allowed = true;
      } else if (userRole == 'enterprise' && (selectedCode == 'enterprise' || selectedCode == 'citizen')) {
        allowed = true;
      } else if (userRole == 'citizen' && selectedCode == 'citizen') {
        allowed = true;
      }

      if (!allowed) {
        if (!mounted) return;
        _showRoleMismatch(displayName);
        return;
      }

      // 保存用户信息到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('loginPhone', phone);
      await prefs.setString('loginRole', _selectedRole!);
      await prefs.setString('loginRegisteredRole', userRole);
      await prefs.setString('loginNickname', data['user']['nickname'] ?? '');
      await prefs.setString('loginUserPhone', data['user']['phone'] ?? phone);
      await prefs.setString('loginCreatedAt', data['user']['created_at'] ?? '');
      // 企业信息
      final enterpriseId = data['user']['enterprise_id'];
      final enterpriseRole = data['user']['enterprise_role'];
      if (enterpriseId != null) {
        await prefs.setInt('enterpriseId', enterpriseId);
        await prefs.setString('enterpriseRole', enterpriseRole ?? 'member');
      } else {
        await prefs.remove('enterpriseId');
        await prefs.remove('enterpriseRole');
      }
      await prefs.commit(); // 确保持久化

      if (!mounted) return;
      _showLoginSuccess(_selectedRole!);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 401) {
        _showError('手机号或密码错误');
      } else {
        _showError(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('网络错误，请检查后端是否启动');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLoginSuccess(String role) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.glassBorder)),
        title: Row(children: [
          Icon(Icons.check_circle_rounded, color: AppColors.celadon, size: 22),
          const SizedBox(width: 8),
          Text('登录成功', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
        ]),
        content: Text('当前角色：$role', style: TextStyle(color: AppColors.paperMid, decoration: TextDecoration.none)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToMain();
            },
            child: Text('进入系统', style: TextStyle(color: AppColors.celadon, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showRoleMismatch(String registeredRole) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.glassBorder)),
        title: Row(children: [
          Icon(Icons.block_rounded, color: AppColors.riskHigh, size: 22),
          const SizedBox(width: 8),
          Text('登录失败', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
        ]),
        content: Text('您的账号为「$registeredRole」，无法使用「$_selectedRole」登录。\n\n请切换到正确的角色后重试。', style: TextStyle(color: AppColors.paperMid, decoration: TextDecoration.none)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('知道了', style: TextStyle(color: AppColors.celadon, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _navigateToMain() {
    // 用后端返回的角色 code，而不是 UI 选择的名称
    final selectedCode = _roleNameToCode[_selectedRole!] ?? 'citizen';
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => MainScreen(role: selectedCode),
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
        pageBuilder: (_, __, ___) => const MainScreen(role: 'citizen', isGuest: true),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.glassBorder)),
        title: Row(children: [
          Icon(Icons.error_outline_rounded, color: AppColors.riskHigh, size: 22),
          const SizedBox(width: 8),
          Text('提示', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
        ]),
        content: Text(msg, style: TextStyle(color: AppColors.paperMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('确定', style: TextStyle(color: AppColors.celadon)),
          ),
        ],
      ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // Logo
                  Image.asset(
                    'assets/images/logo_transparent.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  // 标题
                  Text('FiscalShield AI', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.paper, letterSpacing: 4, decoration: TextDecoration.none)),
                  const SizedBox(height: 6),
                  Text('地方财政风险智能预警系统', style: AppFonts.headingSmall),
                  const SizedBox(height: 40),
                  // 登录卡片
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 角色选择
                        Text('选择登录角色', style: TextStyle(fontSize: 13, color: AppColors.paperDim, decoration: TextDecoration.none)),
                        const SizedBox(height: 8),
                        Row(
                          children: _roles.map((r) => Expanded(child: _buildRoleChip(r))).toList(),
                        ),
                        const SizedBox(height: 24),
                        // 手机号
                        _buildInput(_phoneController, '手机号', Icons.phone_rounded, TextInputType.phone,
                            focusNode: _phoneFocus, focused: _phoneFocused, maxLength: 11),
                        const SizedBox(height: 14),
                        // 密码
                        _buildInput(_pwdController, '密码', Icons.lock_rounded, TextInputType.visiblePassword,
                            obscure: _obscurePwd, focusNode: _pwdFocus, focused: _pwdFocused,
                            suffix: GestureDetector(
                              onTap: () => setState(() => _obscurePwd = !_obscurePwd),
                              child: Icon(_obscurePwd ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 20, color: _pwdFocused ? AppColors.celadon : AppColors.paperDim),
                            )),
                        const SizedBox(height: 14),
                        // 验证码
                        Row(
                          children: [
                            Expanded(child: _buildInput(_codeController, '验证码', Icons.verified_rounded, TextInputType.number,
                                focusNode: _codeFocus, focused: _codeFocused, maxLength: 6)),
                            const SizedBox(width: 12),
                            _buildCodeBtn(),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // 登录按钮
                        _buildLoginBtn(),
                        const SizedBox(height: 16),
                        // 忘记密码 | 去注册
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                              child: Text('忘记密码', style: TextStyle(fontSize: 13, color: AppColors.sky, decoration: TextDecoration.none)),
                            ),
                            Container(width: 1, height: 14, margin: const EdgeInsets.symmetric(horizontal: 16), color: AppColors.glassBorder),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                              child: Text('去注册', style: TextStyle(fontSize: 13, color: AppColors.celadon, decoration: TextDecoration.none)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 服务协议
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _agreed = !_agreed),
                        child: Icon(_agreed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            size: 18, color: _agreed ? AppColors.celadon : AppColors.paperDim),
                      ),
                      const SizedBox(width: 6),
                      Text('我已阅读并同意', style: TextStyle(fontSize: 12, color: AppColors.paperDim, decoration: TextDecoration.none)),
                      GestureDetector(
                        onTap: () {},
                        child: Text('《服务协议》', style: TextStyle(fontSize: 12, color: AppColors.sky, decoration: TextDecoration.none)),
                      ),
                      Text('和', style: TextStyle(fontSize: 12, color: AppColors.paperDim, decoration: TextDecoration.none)),
                      GestureDetector(
                        onTap: () {},
                        child: Text('《隐私政策》', style: TextStyle(fontSize: 12, color: AppColors.sky, decoration: TextDecoration.none)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 游客入口
                  GestureDetector(
                    onTap: _onGuest,
                    child: Text('游客模式（限时体验）', style: TextStyle(fontSize: 13, color: AppColors.sky.withOpacity(0.7), decoration: TextDecoration.none)),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
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
            Text(r.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? r.color : AppColors.paperDim, decoration: TextDecoration.none)),
          ],
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

  Widget _buildLoginBtn() {
    final canLogin = _selectedRole != null && _agreed && !_isLoading;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: canLogin ? _onLogin : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.celadon,
          disabledBackgroundColor: AppColors.glassWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Text(
          _selectedRole != null ? '登  录' : '请选择角色',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 4, decoration: TextDecoration.none),
        ),
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
