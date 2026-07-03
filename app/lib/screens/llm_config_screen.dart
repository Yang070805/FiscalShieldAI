import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../services/api_service.dart';

/// AI 模型配置页 — 参考 next-ai-draw-io 的 model-config-dialog
/// 左侧 Provider 列表 + 右侧配置面板
class LlmConfigScreen extends StatefulWidget {
  const LlmConfigScreen({super.key});

  @override
  State<LlmConfigScreen> createState() => _LlmConfigScreenState();
}

class _LlmConfigScreenState extends State<LlmConfigScreen> {
  final ApiService _api = ApiService();

  // Provider 列表
  final List<_ProviderItem> _providers = [
    _ProviderItem('bluelm', 'vivo 蓝心', Icons.smart_toy_rounded, 'https://api-ai.vivo.com.cn/v1/chat/completions', 'Doubao-Seed-2.0-mini', '默认推荐 · 比赛官方', recommendedModels: [
      {'name': 'Volc-DeepSeek-V3.2', 'desc': 'DeepSeek 深度推理'},
      {'name': 'Doubao-Seed-2.0-mini', 'desc': '豆包轻量版（默认）'},
      {'name': 'Doubao-Seed-2.0-pro', 'desc': '豆包专业版'},
      {'name': 'qwen3.5-plus', 'desc': '通义千问增强版'},
    ]),
    _ProviderItem('deepseek', 'DeepSeek', Icons.code_rounded, 'https://api.deepseek.com/v1/chat/completions', 'deepseek-chat', '高性价比 · 中文优秀', recommendedModels: [
      {'name': 'deepseek-chat', 'desc': '通用对话'},
      {'name': 'deepseek-reasoner', 'desc': '深度推理'},
    ]),
    _ProviderItem('qwen', '通义千问 (Qwen)', Icons.auto_awesome_rounded, 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions', 'qwen-turbo', '阿里云 · 多模态', recommendedModels: [
      {'name': 'qwen-turbo', 'desc': '快速响应'},
      {'name': 'qwen-plus', 'desc': '增强版'},
      {'name': 'qwen-max', 'desc': '旗舰版'},
    ]),
    _ProviderItem('doubao', '豆包 (Doubao)', Icons.bolt_rounded, 'https://ark.cn-beijing.volces.com/api/v3/chat/completions', 'doubao-lite-4k', '字节跳动 · 快速响应', recommendedModels: [
      {'name': 'doubao-lite-4k', 'desc': '轻量快速'},
      {'name': 'doubao-pro-32k', 'desc': '专业版'},
    ]),
    _ProviderItem('openai', 'OpenAI', Icons.chat_rounded, 'https://api.openai.com/v1/chat/completions', 'gpt-4o-mini', 'GPT-4o · 英文最强', recommendedModels: [
      {'name': 'gpt-4o-mini', 'desc': '高性价比'},
      {'name': 'gpt-4o', 'desc': '旗舰版'},
    ]),
    _ProviderItem('anthropic', 'Anthropic (Claude)', Icons.psychology_rounded, 'https://api.anthropic.com/v1/messages', 'claude-3-5-haiku-20241022', '推理能力强', recommendedModels: [
      {'name': 'claude-3-5-haiku-20241022', 'desc': '快速轻量'},
      {'name': 'claude-sonnet-4-20250514', 'desc': '均衡版'},
    ]),
    _ProviderItem('kimi', 'Kimi (Moonshot)', Icons.wb_sunny_rounded, 'https://api.moonshot.cn/v1/chat/completions', 'moonshot-v1-8k', '月之暗面 · 长文本', recommendedModels: [
      {'name': 'moonshot-v1-8k', 'desc': '8K上下文'},
      {'name': 'moonshot-v1-32k', 'desc': '32K长文本'},
    ]),
    _ProviderItem('glm', 'GLM (智谱)', Icons.auto_graph_rounded, 'https://open.bigmodel.cn/api/paas/v4/chat/completions', 'glm-4-flash', '智谱AI · 国产', recommendedModels: [
      {'name': 'glm-4-flash', 'desc': '快速版'},
      {'name': 'glm-4-plus', 'desc': '增强版'},
    ]),
  ];

  _ProviderItem? _selectedProvider;
  bool _showApiKey = false;
  final _apiKeyController = TextEditingController();
  final _appIdController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  String _testStatus = 'idle'; // idle / testing / success / error
  String _testMessage = '';

  // 每个 Provider 已配置的 Key
  Map<String, String> _configuredKeys = {};
  // 每个 Provider 已配置的 Base URL
  Map<String, String> _configuredUrls = {};
  // 当前选中的模型
  Map<String, String> _selectedModels = {};

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  String _accountPrefix = '';

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('loginPhone') ?? '';
    _accountPrefix = phone.isNotEmpty ? '${phone}_' : '';
    for (final p in _providers) {
      _configuredKeys[p.name] = prefs.getString('${_accountPrefix}llm_key_${p.name}') ?? '';
      _configuredUrls[p.name] = prefs.getString('${_accountPrefix}llm_url_${p.name}') ?? p.defaultUrl;
      _selectedModels[p.name] = prefs.getString('${_accountPrefix}llm_model_${p.name}') ?? p.defaultModel;
    }
    // 选中第一个已配置的 Provider，或默认第一个
    _selectedProvider = _providers.firstWhere(
      (p) => _configuredKeys[p.name]?.isNotEmpty == true,
      orElse: () => _providers.first,
    );
    _syncControllers();
    if (mounted) setState(() {});
  }

  void _syncControllers() async {
    if (_selectedProvider == null) return;
    final prefs = await SharedPreferences.getInstance();
    _apiKeyController.text = _configuredKeys[_selectedProvider!.name] ?? '';
    _appIdController.text = prefs.getString('${_accountPrefix}llm_appid_${_selectedProvider!.name}') ?? '';
    _baseUrlController.text = _configuredUrls[_selectedProvider!.name] ?? _selectedProvider!.defaultUrl;
    _modelController.text = _selectedModels[_selectedProvider!.name] ?? _selectedProvider!.defaultModel;
    _showApiKey = false;
    _testStatus = 'idle';
    _testMessage = '';
  }

  Future<void> _saveConfig() async {
    if (_selectedProvider == null) return;
    final prefs = await SharedPreferences.getInstance();
    final name = _selectedProvider!.name;
    await prefs.setString('${_accountPrefix}llm_key_$name', _apiKeyController.text.trim());
    await prefs.setString('${_accountPrefix}llm_appid_$name', _appIdController.text.trim());
    await prefs.setString('${_accountPrefix}llm_url_$name', _baseUrlController.text.trim());
    await prefs.setString('${_accountPrefix}llm_model_$name', _modelController.text.trim());
    _configuredKeys[name] = _apiKeyController.text.trim();
    _configuredUrls[name] = _baseUrlController.text.trim();
    _selectedModels[name] = _modelController.text.trim();

    // 同步到后端
    if (_apiKeyController.text.trim().isNotEmpty) {
      try {
        await _api.setApiKey(model: name, apiKey: _apiKeyController.text.trim());
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  Future<void> _testConnection() async {
    if (_apiKeyController.text.trim().isEmpty) {
      setState(() {
        _testStatus = 'error';
        _testMessage = '请先输入 API Key';
      });
      return;
    }

    setState(() {
      _testStatus = 'testing';
      _testMessage = '正在连接...';
    });

    try {
      final result = await _api.testLlmConnection(
        apiKey: _apiKeyController.text.trim(),
        model: _selectedProvider!.name,
        appId: _appIdController.text.trim().isNotEmpty ? _appIdController.text.trim() : null,
      );
      if (!mounted) return;
      setState(() {
        _testStatus = result['status'] == 'ok' ? 'success' : 'error';
        _testMessage = result['message'] ?? '未知错误';
      });
      // 保存配置
      if (result['status'] == 'ok') {
        await _saveConfig();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testStatus = 'error';
        _testMessage = '连接失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBg,
      body: SafeArea(
        child: Column(
          children: [
            // 顶栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_rounded, color: AppColors.paper),
                ),
                const SizedBox(width: 12),
                Icon(Icons.auto_awesome_rounded, color: AppColors.celadon, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI 模型配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                      Text('配置多个 AI 提供商和模型', style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
                    ],
                  ),
                ),
              ]),
            ),
            Divider(height: 1, color: AppColors.glassBorder),
            // 主体
            Expanded(
              child: Row(
                children: [
                  // 左侧 Provider 列表
                  _buildProviderSidebar(),
                  // 右侧配置面板
                  Expanded(child: _buildConfigPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSidebar() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('提供商', style: TextStyle(fontSize: 12, color: AppColors.paperDim, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _providers.length,
              itemBuilder: (ctx, i) {
                final p = _providers[i];
                final isSelected = _selectedProvider?.name == p.name;
                final isConfigured = (_configuredKeys[p.name]?.isNotEmpty == true);
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: AppColors.celadon.withOpacity(0.08),
                  leading: Icon(p.icon, size: 20, color: isSelected ? AppColors.celadon : AppColors.paperDim),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(p.displayName, style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? AppColors.celadon : AppColors.paper,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          decoration: TextDecoration.none,
                        )),
                      ),
                      if (isConfigured)
                        Icon(Icons.check_circle_rounded, size: 14, color: AppColors.celadon),
                    ],
                  ),
                  onTap: () {
                    setState(() => _selectedProvider = p);
                    _syncControllers();
                    setState(() {});
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigPanel() {
    if (_selectedProvider == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 48, color: AppColors.paperDim.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('配置 AI 提供商', style: TextStyle(fontSize: 16, color: AppColors.paperDim, decoration: TextDecoration.none)),
            const SizedBox(height: 4),
            Text('从列表中选择提供商以配置 API 密钥和模型', style: TextStyle(fontSize: 12, color: AppColors.paperDim.withOpacity(0.6)), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final p = _selectedProvider!;
    final isConfigured = (_configuredKeys[p.name]?.isNotEmpty == true);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider 标题
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.celadon.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(p.icon, size: 24, color: AppColors.celadon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.displayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                  Text(isConfigured ? '已配置' : '尚未配置模型', style: TextStyle(fontSize: 12, color: isConfigured ? AppColors.celadon : AppColors.paperDim)),
                ],
              ),
            ),
            if (isConfigured)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _configuredKeys[p.name] = '';
                    _apiKeyController.clear();
                  });
                  _saveConfig();
                },
                icon: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.riskHigh),
                label: Text('删除', style: TextStyle(color: AppColors.riskHigh, fontSize: 12)),
              ),
          ]),
          const SizedBox(height: 24),

          // 配置区域
          _configSection('配置', Icons.settings_rounded, [
            // 显示名称
            _buildLabel('显示名称'),
            TextField(
              controller: TextEditingController(text: p.displayName),
              enabled: false,
              style: TextStyle(color: AppColors.paperDim, fontSize: 14),
              decoration: _inputDecoration(''),
            ),
            const SizedBox(height: 16),

            // API Key
            _buildLabel('API 密钥'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: !_showApiKey,
                    style: TextStyle(color: AppColors.paper, fontSize: 14),
                    decoration: _inputDecoration('输入您的 API 密钥').copyWith(
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(_showApiKey ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: AppColors.paperDim),
                            onPressed: () => setState(() => _showApiKey = !_showApiKey),
                          ),
                          // 测试按钮
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            child: ElevatedButton(
                              onPressed: _testStatus == 'testing' ? null : _testConnection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _testStatus == 'success' ? AppColors.celadon : AppColors.sky,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: Size.zero,
                              ),
                              child: _testStatus == 'testing'
                                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text('测试', style: TextStyle(fontSize: 12, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    onChanged: (_) => _saveConfig(),
                  ),
                ),
              ],
            ),
            // 测试结果
            if (_testMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_testStatus == 'success' ? AppColors.celadon : AppColors.riskHigh).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (_testStatus == 'success' ? AppColors.celadon : AppColors.riskHigh).withOpacity(0.25)),
                ),
                child: Row(children: [
                  Icon(
                    _testStatus == 'success' ? Icons.check_circle_rounded : Icons.error_rounded,
                    size: 16,
                    color: _testStatus == 'success' ? AppColors.celadon : AppColors.riskHigh,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_testMessage, style: TextStyle(fontSize: 12, color: _testStatus == 'success' ? AppColors.celadon : AppColors.riskHigh))),
                ]),
              ),
            ],
            const SizedBox(height: 16),

            // AppID（仅 vivo 蓝心需要）
            if (p.name == 'bluelm') ...[
              _buildLabel('AppID（赛事官方提供）'),
              TextField(
                controller: _appIdController,
                style: TextStyle(color: AppColors.paper, fontSize: 14),
                decoration: _inputDecoration('如：2026091280'),
                onChanged: (_) => _saveConfig(),
              ),
              const SizedBox(height: 16),
            ],

            // Base URL
            _buildLabel('基础 URL（可选）'),
            TextField(
              controller: _baseUrlController,
              style: TextStyle(color: AppColors.paper, fontSize: 14),
              decoration: _inputDecoration(p.defaultUrl),
              onChanged: (_) => _saveConfig(),
            ),
          ]),
          const SizedBox(height: 24),

          // 模型选择
          _configSection('模型', Icons.psychology_rounded, [
            _buildLabel('当前模型'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _modelController,
                    style: TextStyle(color: AppColors.paper, fontSize: 14, fontFamily: 'JetBrainsMono'),
                    decoration: _inputDecoration(p.defaultModel),
                    onChanged: (_) => _saveConfig(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 推荐模型
            if (p.recommendedModels.isNotEmpty) ...[
              _buildLabel('推荐模型'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: p.recommendedModels.map((m) {
                  final isSelected = _modelController.text == m['name'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _modelController.text = m['name']!);
                      _saveConfig();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.celadon.withOpacity(0.12) : AppColors.cardBg.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.celadon.withOpacity(0.5) : AppColors.glassBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['name']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppColors.celadon : AppColors.paper, fontFamily: 'JetBrainsMono', decoration: TextDecoration.none)),
                          Text(m['desc']!, style: TextStyle(fontSize: 10, color: AppColors.paperDim)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ]),
          const SizedBox(height: 32),

          // 底部提示
          Center(
            child: Text('🔑 API 密钥存储在设备本地', style: TextStyle(fontSize: 11, color: AppColors.paperDim.withOpacity(0.5))),
          ),
        ],
      ),
    );
  }

  Widget _configSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: AppColors.paperDim),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 12, color: AppColors.paperDim, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.paperMid)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.paperDim.withOpacity(0.5), fontSize: 13),
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
        borderSide: BorderSide(color: AppColors.celadon.withOpacity(0.5)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _ProviderItem {
  final String name;
  final String displayName;
  final IconData icon;
  final String defaultUrl;
  final String defaultModel;
  final String description;
  final List<Map<String, String>> recommendedModels;

  _ProviderItem(
    this.name,
    this.displayName,
    this.icon,
    this.defaultUrl,
    this.defaultModel,
    this.description, {
    this.recommendedModels = const [],
  });
}
