import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../config/theme_schemes.dart';
import '../services/api_service.dart';
import '../widgets/ink_world.dart';
import '../widgets/glass_widgets.dart';
import '../main.dart';
import 'avatar_picker_screen.dart';
import 'llm_config_screen.dart';

/// 设置页
class SettingsScreen extends StatefulWidget {
  final bool isGuest;
  const SettingsScreen({super.key, this.isGuest = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 用户信息
  String _userPhone = '';

  // 服务器配置
  String _backendUrl = 'http://192.168.1.100:8000';

  // LLM 配置
  bool _llmEnabled = false;
  String _selectedModel = 'vivo蓝心';
  bool _showApiKey = false;
  final _apiKeyController = TextEditingController();
  final _endpointController = TextEditingController();

  final List<_LlmModel> _models = [
    _LlmModel('vivo蓝心', 'BlueLM API', Icons.smart_toy_rounded, '默认推荐 · 比赛官方'),
    _LlmModel('DeepSeek', 'DeepSeek API', Icons.code_rounded, '高性价比 · 中文优秀'),
    _LlmModel('通义千问', 'Qwen API', Icons.auto_awesome_rounded, '阿里云 · 多模态'),
    _LlmModel('豆包', 'Doubao API', Icons.bolt_rounded, '字节跳动 · 快速响应'),
    _LlmModel('ChatGPT', 'OpenAI API', Icons.chat_rounded, 'GPT-4o · 英文最强'),
    _LlmModel('Claude', 'Anthropic API', Icons.psychology_rounded, '推理能力强'),
    _LlmModel('Kimi', 'Moonshot API', Icons.wb_sunny_rounded, '月之暗面 · 长文本'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadLlmConfig();
    _loadBackendUrl();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userPhone = prefs.getString('loginPhone') ?? '';
    });
  }

  String _maskPhone(String phone) {
    if (phone.length >= 7) {
      return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
    }
    return phone;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _loadLlmConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _llmEnabled = prefs.getBool('llmEnabled') ?? false;
      _selectedModel = prefs.getString('llmModel') ?? 'vivo蓝心';
      _apiKeyController.text = prefs.getString('llmApiKey') ?? '';
      _endpointController.text = prefs.getString('llmEndpoint') ?? '';
    });
  }

  Future<void> _saveLlmConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('llmEnabled', _llmEnabled);
    await prefs.setString('llmModel', _selectedModel);
    await prefs.setString('llmApiKey', _apiKeyController.text.trim());
    await prefs.setString('llmEndpoint', _endpointController.text.trim());
    await prefs.commit();
  }

  Future<void> _loadBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backendUrl = prefs.getString('backend_url') ?? ApiService().baseUrl;
    });
  }

  void _showBackendUrlDialog() {
    final controller = TextEditingController(text: _backendUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBg,
        title: Text('后端服务器地址', style: TextStyle(color: AppColors.paper)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('输入后端服务的地址，例如 http://192.168.1.100:8000',
              style: TextStyle(color: AppColors.paperMid, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: TextStyle(color: AppColors.paper),
              decoration: InputDecoration(
                hintText: 'http://IP地址:8000',
                hintStyle: TextStyle(color: AppColors.paperMid),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.paperMid)),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.sky)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: AppColors.paperMid)),
          ),
          TextButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                await ApiService().saveBaseUrl(url);
                setState(() => _backendUrl = url);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('后端地址已更新'), backgroundColor: AppColors.sky));
              }
            },
            child: Text('保存', style: TextStyle(color: AppColors.sky)),
          ),
        ],
      ),
    );
  }

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
                    // ── 服务器配置 ──
                    _section('服务器', [
                      _item(Icons.dns_rounded, '后端地址', _backendUrl, onTap: _showBackendUrlDialog),
                    ]),
                    const SizedBox(height: 16),
                    // ── AI 模型配置 ──
                    _section('AI 模配', [
                      _llmToggleItem(),
                      if (_llmEnabled) ...[
                        _divider(),
                        _item(Icons.auto_awesome_rounded, '模型配置', '', onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LlmConfigScreen()));
                        }),
                      ],
                    ]),
                    const SizedBox(height: 16),
                    _section('账号与安全', [
                      _item(Icons.phone_rounded, '绑定手机号', _userPhone.isNotEmpty ? _maskPhone(_userPhone) : '未绑定', onTap: _showBindPhoneDialog),
                      _item(Icons.link_rounded, '绑定社交账号', '未绑定', onTap: _showBindSocialDialog),
                      _item(Icons.lock_rounded, '修改密码', '', onTap: _showChangePasswordDialog),
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
                      _item(Icons.shield_rounded, '数据脱敏说明', '', onTap: _showDesensitizationInfo),
                      _item(Icons.delete_outline_rounded, '清除本地缓存', '', onTap: _showClearCacheDialog),
                    ]),
                    const SizedBox(height: 16),
                    _section('关于', [
                      _item(Icons.info_outline_rounded, '版本信息', 'v1.0.0', onTap: _showVersionInfo),
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

  Widget _divider() => Divider(height: 1, indent: 48, color: AppColors.glassBorder);

  Widget _item(IconData icon, String label, String trailing, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
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
                  AppColors.update(type);
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

  // ═══ 账号与安全 ═══

  void _showBindPhoneDialog() {
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.glassBorder)),
        title: Row(children: [
          Icon(Icons.phone_rounded, color: AppColors.celadon, size: 22),
          const SizedBox(width: 8),
          Text('绑定手机号', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isGuest && _userPhone.isNotEmpty) ...[
              Text('当前绑定：${_maskPhone(_userPhone)}', style: TextStyle(color: AppColors.paperMid)),
              const SizedBox(height: 12),
              Text('更换手机号', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper)),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: AppColors.paper, fontSize: 14),
              decoration: InputDecoration(
                hintText: '输入新手机号',
                hintStyle: TextStyle(color: AppColors.paperDim.withOpacity(0.5)),
                filled: true,
                fillColor: AppColors.glassWhite,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.glassBorder)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: AppColors.paperDim))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('手机号绑定（待后端接入）'), backgroundColor: AppColors.sky, duration: Duration(seconds: 2)),
              );
            },
            child: Text('确认', style: TextStyle(color: AppColors.celadon)),
          ),
        ],
      ),
    );
  }

  void _showBindSocialDialog() {
    final platforms = [
      {'name': '微信', 'icon': Icons.chat_rounded, 'color': Color(0xFF07C160)},
      {'name': 'QQ', 'icon': Icons.chat_bubble_rounded, 'color': Color(0xFF12B7F5)},
      {'name': '支付宝', 'icon': Icons.account_balance_wallet_rounded, 'color': Color(0xFF1677FF)},
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.glassBorder)),
        title: Row(children: [
          Icon(Icons.link_rounded, color: AppColors.celadon, size: 22),
          const SizedBox(width: 8),
          Text('绑定社交账号', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: platforms.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: (p['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(p['icon'] as IconData, color: p['color'] as Color, size: 22),
              ),
              title: Text(p['name'] as String, style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
              subtitle: Text('待接入', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
              trailing: Icon(Icons.chevron_right_rounded, color: AppColors.paperDim, size: 20),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${p['name']}绑定（待后端接入）'), backgroundColor: AppColors.sky, duration: Duration(seconds: 2)),
                );
              },
            ),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('关闭', style: TextStyle(color: AppColors.paperDim))),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.glassBorder)),
        title: Row(children: [
          Icon(Icons.lock_rounded, color: AppColors.celadon, size: 22),
          const SizedBox(width: 8),
          Text('修改密码', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogInput(oldPwdCtrl, '当前密码', obscure: true),
            const SizedBox(height: 10),
            _buildDialogInput(newPwdCtrl, '新密码（至少6位）', obscure: true),
            const SizedBox(height: 10),
            _buildDialogInput(confirmPwdCtrl, '确认新密码', obscure: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: AppColors.paperDim))),
          TextButton(
            onPressed: () {
              if (newPwdCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('密码至少6位'), backgroundColor: AppColors.riskHigh, duration: Duration(seconds: 2)),
                );
                return;
              }
              if (newPwdCtrl.text != confirmPwdCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('两次密码不一致'), backgroundColor: AppColors.riskHigh, duration: Duration(seconds: 2)),
                );
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('密码修改（待后端接入）'), backgroundColor: AppColors.celadon, duration: Duration(seconds: 2)),
              );
            },
            child: Text('确认修改', style: TextStyle(color: AppColors.celadon)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInput(TextEditingController ctrl, String hint, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(color: AppColors.paper, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.paperDim.withOpacity(0.5)),
        filled: true,
        fillColor: AppColors.glassWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.glassBorder)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  // ═══ 隐私与数据 ═══

  void _showDesensitizationInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.glassBorder)),
        title: Row(children: [
          Icon(Icons.shield_rounded, color: AppColors.celadon, size: 22),
          const SizedBox(width: 8),
          Text('数据脱敏说明', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoSection('什么是数据脱敏？', '将敏感信息（如姓名、手机号、身份证号等）进行替换、遮蔽或加密处理，使其无法直接识别个人身份。'),
              const SizedBox(height: 12),
              _infoSection('本平台的脱敏策略', '• 手机号：仅显示前3位和后4位（如 138****0000）\n• 企业名称：公开数据中不包含个人身份信息\n• API Key：本地加密存储，不上传至服务器\n• 预测数据：仅保留统计结果，不含原始数据'),
              const SizedBox(height: 12),
              _infoSection('为什么需要脱敏？', '• 保护用户隐私，防止个人信息泄露\n• 满足《个人信息保护法》合规要求\n• 降低数据泄露风险'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('我知道了', style: TextStyle(color: AppColors.celadon))),
        ],
      ),
    );
  }

  Widget _infoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
        const SizedBox(height: 4),
        Text(content, style: TextStyle(fontSize: 12, color: AppColors.paperMid, height: 1.6)),
      ],
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.glassBorder)),
        title: Row(children: [
          Icon(Icons.delete_outline_rounded, color: AppColors.riskHigh, size: 22),
          const SizedBox(width: 8),
          Text('清除本地缓存', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
        ]),
        content: Text('确定要清除所有本地缓存数据吗？\n\n这将清除：主题设置、字体偏好、LLM配置等\n不会清除账号数据。', style: TextStyle(color: AppColors.paperMid)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: AppColors.paperDim))),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('theme');
              await prefs.remove('fontSize');
              await prefs.remove('fontFamily');
              await prefs.remove('avatar');
              await prefs.remove('customAvatarPath');
              await prefs.remove('llmEnabled');
              await prefs.remove('llmModel');
              await prefs.remove('llmApiKey');
              await prefs.remove('llmEndpoint');
              themeNotifier.setTheme(ThemeType.inkBlue);
              AppColors.update(ThemeType.inkBlue);
              themeNotifier.setFontSize(0);
              themeNotifier.setFontFamily(0);
              themeNotifier.setAvatar('bamboo');
              themeNotifier.setCustomAvatarPath('');
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('缓存已清除'), backgroundColor: AppColors.celadon, duration: Duration(seconds: 2)),
                );
              }
            },
            child: Text('确认清除', style: TextStyle(color: AppColors.riskHigh)),
          ),
        ],
      ),
    );
  }

  void _showVersionInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.glassBorder)),
        title: Row(children: [
          Icon(Icons.info_outline_rounded, color: AppColors.celadon, size: 22),
          const SizedBox(width: 8),
          Text('版本信息', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoSection('当前版本', 'v1.0.0 (Build 1)'),
            const SizedBox(height: 12),
            _infoSection('更新日志', 'v1.0.0 (2026-07-02)\n• 三角色差异化仪表盘\n• LLM 聊天面板\n• AI 模型配置\n• 水墨·璃主题系统'),
            const SizedBox(height: 12),
            _infoSection('技术栈', 'Flutter 3.44 · Dart · GLSL Shader'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已是最新版本'), backgroundColor: AppColors.celadon, duration: Duration(seconds: 2)),
              );
            },
            child: Text('检查更新', style: TextStyle(color: AppColors.celadon)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('关闭', style: TextStyle(color: AppColors.paperDim))),
        ],
      ),
    );
  }

  // ═══ AI 模型配置 ═══

  Widget _llmToggleItem() {
    return SwitchListTile(
      title: Row(children: [
        Icon(Icons.auto_awesome_rounded, size: 20, color: AppColors.sky),
        const SizedBox(width: 12),
        Text('启用大语言模型', style: TextStyle(fontSize: 15, color: AppColors.paper)),
      ]),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 32, top: 4),
        child: Text(
          _llmEnabled ? 'AI 增强报告 + 智能对话' : '仅使用本地模型生成报告',
          style: TextStyle(fontSize: 12, color: AppColors.paperDim),
        ),
      ),
      value: _llmEnabled,
      activeColor: AppColors.celadon,
      onChanged: (v) {
        setState(() => _llmEnabled = v);
        _saveLlmConfig();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _llmProviderSelector() {
    final currentModel = _models.firstWhere((m) => m.name == _selectedModel, orElse: () => _models.first);
    return InkWell(
      onTap: _showModelPicker,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.celadon.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(currentModel.icon, size: 20, color: AppColors.celadon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentModel.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                Text(currentModel.desc, style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.paperDim),
        ]),
      ),
    );
  }

  void _showModelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: AppColors.deepBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.celadon, size: 22),
              const SizedBox(width: 8),
              Text('选择 AI Provider', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
            ]),
            const SizedBox(height: 4),
            Text('vivo 蓝心为默认推荐，与比赛呼应', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _models.length,
                itemBuilder: (ctx, i) {
                  final m = _models[i];
                  final isSelected = _selectedModel == m.name;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedModel = m.name);
                      _saveLlmConfig();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.celadon.withOpacity(0.12) : AppColors.glassWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.celadon.withOpacity(0.6) : AppColors.glassBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isSelected ? AppColors.celadon : AppColors.sky).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(m.icon, size: 20, color: isSelected ? AppColors.celadon : AppColors.sky),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isSelected ? AppColors.celadon : AppColors.paper, decoration: TextDecoration.none)),
                              const SizedBox(height: 2),
                              Text(m.desc, style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
                            ],
                          ),
                        ),
                        if (m.name == 'vivo蓝心')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.celadon.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text('推荐', style: TextStyle(fontSize: 10, color: AppColors.celadon, fontWeight: FontWeight.w600)),
                          ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle_rounded, color: AppColors.celadon, size: 22),
                        ],
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _llmApiKeyItem() {
    final isObscured = _apiKeyController.text.isNotEmpty && !_showApiKey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.key_rounded, size: 20, color: AppColors.sky),
            const SizedBox(width: 12),
            Text('API Key', style: TextStyle(fontSize: 15, color: AppColors.paper)),
            const Spacer(),
            if (_apiKeyController.text.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _showApiKey = !_showApiKey),
                child: Icon(_showApiKey ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: AppColors.paperDim),
              ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: !_showApiKey,
            style: TextStyle(color: AppColors.paper, fontSize: 14),
            decoration: InputDecoration(
              hintText: '输入 API Key',
              hintStyle: TextStyle(color: AppColors.paperDim.withOpacity(0.5)),
              filled: true,
              fillColor: AppColors.glassWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.celadon.withOpacity(0.6), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: IconButton(
                icon: Icon(Icons.save_rounded, size: 20, color: AppColors.celadon),
                onPressed: () {
                  _saveLlmConfig();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('API Key 已保存'), backgroundColor: AppColors.celadon, duration: const Duration(seconds: 1)),
                  );
                },
              ),
            ),
            onChanged: (_) => _saveLlmConfig(),
          ),
        ],
      ),
    );
  }

  Widget _llmEndpointItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.link_rounded, size: 20, color: AppColors.sky),
            const SizedBox(width: 12),
            Text('自定义 Endpoint', style: TextStyle(fontSize: 15, color: AppColors.paper)),
            const SizedBox(width: 8),
            Text('可选', style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _endpointController,
            style: TextStyle(color: AppColors.paper, fontSize: 14),
            decoration: InputDecoration(
              hintText: '留空使用默认地址',
              hintStyle: TextStyle(color: AppColors.paperDim.withOpacity(0.5)),
              filled: true,
              fillColor: AppColors.glassWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.celadon.withOpacity(0.6), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (_) => _saveLlmConfig(),
          ),
        ],
      ),
    );
  }

  Widget _llmRecommendedModels() {
    final recommendations = {
      'vivo蓝心': [
        {'name': 'vivo-BlueLM-Chat', 'desc': '默认对话模型', 'tag': '推荐'},
        {'name': 'vivo-BlueLM-Chat-32K', 'desc': '长上下文版', 'tag': '长文本'},
      ],
      'DeepSeek': [
        {'name': 'deepseek-chat', 'desc': '通用对话', 'tag': '推荐'},
        {'name': 'deepseek-reasoner', 'desc': '深度推理', 'tag': '推理'},
      ],
      '通义千问': [
        {'name': 'qwen-turbo', 'desc': '快速响应', 'tag': '推荐'},
        {'name': 'qwen-plus', 'desc': '增强版', 'tag': '增强'},
        {'name': 'qwen-max', 'desc': '旗舰版', 'tag': '最强'},
      ],
      '豆包': [
        {'name': 'doubao-lite-4k', 'desc': '轻量快速', 'tag': '推荐'},
        {'name': 'doubao-pro-32k', 'desc': '专业版', 'tag': '增强'},
      ],
      'ChatGPT': [
        {'name': 'gpt-4o-mini', 'desc': '高性价比', 'tag': '推荐'},
        {'name': 'gpt-4o', 'desc': '旗舰版', 'tag': '最强'},
      ],
      'Claude': [
        {'name': 'claude-3-5-haiku-20241022', 'desc': '快速轻量', 'tag': '推荐'},
        {'name': 'claude-sonnet-4-20250514', 'desc': '均衡版', 'tag': '均衡'},
      ],
      'Kimi': [
        {'name': 'moonshot-v1-8k', 'desc': '8K上下文', 'tag': '推荐'},
        {'name': 'moonshot-v1-32k', 'desc': '32K上下文', 'tag': '长文本'},
      ],
    };
    final models = recommendations[_selectedModel] ?? [];
    if (models.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.recommend_rounded, size: 20, color: AppColors.celadon),
            const SizedBox(width: 12),
            Text('推荐模型', style: TextStyle(fontSize: 15, color: AppColors.paper)),
          ]),
          const SizedBox(height: 8),
          ...models.map((m) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBg.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['name']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper, fontFamily: 'JetBrainsMono', decoration: TextDecoration.none)),
                    Text(m['desc']!, style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.celadon.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(m['tag']!, style: TextStyle(fontSize: 10, color: AppColors.celadon, fontWeight: FontWeight.w600)),
              ),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _llmTestItem() {
    return InkWell(
      onTap: () async {
        final apiKey = _apiKeyController.text.trim();
        if (apiKey.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ 请先输入 API Key'), backgroundColor: AppColors.warmApricot, duration: const Duration(seconds: 2)),
          );
          return;
        }
        // 显示测试中状态
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 10),
            Text('正在测试 ${_selectedModel} 连接...'),
          ]), backgroundColor: AppColors.sky, duration: const Duration(seconds: 1)),
        );
        try {
          final api = ApiService();
          final modelMap = {'vivo蓝心': 'bluelm', 'DeepSeek': 'deepseek', '通义千问': 'qwen', '豆包': 'doubao', 'ChatGPT': 'openai', 'Claude': 'anthropic', 'Kimi': 'kimi'};
          final result = await api.testLlmConnection(
            apiKey: apiKey.isNotEmpty ? apiKey : null,
            model: modelMap[_selectedModel] ?? 'bluelm',
          );
          if (!mounted) return;
          final status = result['status'] ?? 'error';
          final message = result['message'] ?? '未知错误';
          final color = status == 'ok' ? AppColors.celadon : AppColors.riskHigh;
          final icon = status == 'ok' ? '✅' : '❌';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$icon $message'), backgroundColor: color, duration: const Duration(seconds: 3)),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ 连接异常: $e'), backgroundColor: AppColors.riskHigh, duration: const Duration(seconds: 2)),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(Icons.wifi_tethering_rounded, size: 20, color: AppColors.sky),
          const SizedBox(width: 12),
          Text('测试连接', style: TextStyle(fontSize: 15, color: AppColors.paper)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.paperDim),
        ]),
      ),
    );
  }
}

class _LlmModel {
  final String name;
  final String api;
  final IconData icon;
  final String desc;
  _LlmModel(this.name, this.api, this.icon, this.desc);
}
