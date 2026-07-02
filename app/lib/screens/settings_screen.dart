import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';

import '../config/theme_schemes.dart';
import '../widgets/ink_world.dart';
import '../widgets/glass_widgets.dart';
import '../main.dart';
import 'avatar_picker_screen.dart';

/// 设置页
class SettingsScreen extends StatefulWidget {
  final bool isGuest;
  const SettingsScreen({super.key, this.isGuest = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // LLM 配置
  bool _llmEnabled = false;
  String _selectedModel = 'vivo蓝心';
  final _apiKeyController = TextEditingController();
  final _endpointController = TextEditingController();

  final List<_LlmModel> _models = [
    _LlmModel('vivo蓝心', 'BlueLM API', Icons.smart_toy_rounded, '默认推荐 · 比赛官方'),
    _LlmModel('DeepSeek', 'DeepSeek API', Icons.code_rounded, '高性价比 · 中文优秀'),
    _LlmModel('通义千问', 'Qwen API', Icons.auto_awesome_rounded, '阿里云 · 多模态'),
    _LlmModel('豆包', 'Doubao API', Icons.bolt_rounded, '字节跳动 · 快速响应'),
    _LlmModel('ChatGPT', 'OpenAI API', Icons.chat_rounded, 'GPT-4o · 英文最强'),
    _LlmModel('Claude', 'Anthropic API', Icons.psychology_rounded, '推理能力强'),
  ];

  @override
  void initState() {
    super.initState();
    _loadLlmConfig();
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
                    // ── AI 模型配置 ──
                    _section('AI 模配', [
                      _llmToggleItem(),
                      if (_llmEnabled) ...[
                        _divider(),
                        _llmModelItem(),
                        _divider(),
                        _llmApiKeyItem(),
                        _divider(),
                        _llmEndpointItem(),
                        _divider(),
                        _llmTestItem(),
                      ],
                    ]),
                    const SizedBox(height: 16),
                    _section('账号与安全', [
                      _item(Icons.phone_rounded, '绑定手机号', widget.isGuest ? '未绑定' : '138****0000'),
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

  Widget _divider() => Divider(height: 1, indent: 48, color: AppColors.glassBorder);

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

  Widget _llmModelItem() {
    return InkWell(
      onTap: _showModelPicker,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(Icons.smart_toy_rounded, size: 20, color: AppColors.sky),
          const SizedBox(width: 12),
          Text('模型选择', style: TextStyle(fontSize: 15, color: AppColors.paper)),
          const Spacer(),
          Text(_selectedModel, style: TextStyle(fontSize: 13, color: AppColors.celadon, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
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
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: BoxDecoration(
          color: AppColors.deepBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择模型', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
            const SizedBox(height: 6),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.key_rounded, size: 20, color: AppColors.sky),
            const SizedBox(width: 12),
            Text('API Key', style: TextStyle(fontSize: 15, color: AppColors.paper)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
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

  Widget _llmTestItem() {
    return InkWell(
      onTap: () {
        if (_apiKeyController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('请先填写 API Key'), backgroundColor: AppColors.riskHigh, duration: const Duration(seconds: 2)),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接测试（待后端实现）'), backgroundColor: AppColors.sky, duration: const Duration(seconds: 2)),
        );
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
