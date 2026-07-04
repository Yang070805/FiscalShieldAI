import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/glass_widgets.dart';

/// LLM 聊天面板 — 底部弹出，半屏高度
class ChatPanel extends StatefulWidget {
  final String role;
  final String? contextCity;
  final String? contextCompany;

  const ChatPanel({
    super.key,
    required this.role,
    this.contextCity,
    this.contextCompany,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  String _selectedProvider = 'bluelm';
  String _selectedModel = 'Doubao-Seed-2.0-mini';
  List<Map<String, dynamic>> _availableModels = [];

  @override
  void initState() {
    super.initState();
    _loadProvider();
    // 欢迎消息
    final contextHint = widget.contextCity != null
        ? '当前城市：${widget.contextCity}'
        : widget.contextCompany != null
            ? '当前企业：${widget.contextCompany}'
            : '';
    _messages.add(_ChatMessage(
      role: 'assistant',
      content: '你好！我是 FiscalShield AI 智能助手。\n$contextHint\n\n你可以问我关于财政风险、数据分析、预测解读等问题。',
    ));
  }

  Future<void> _loadProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('loginPhone') ?? '';
    final prefix = phone.isNotEmpty ? '${phone}_' : '';
    final providers = ['bluelm', 'deepseek', 'qwen', 'doubao', 'openai', 'anthropic', 'kimi', 'glm'];
    final providerNames = {'bluelm': 'vivo 蓝心', 'deepseek': 'DeepSeek', 'qwen': '通义千问', 'doubao': '豆包', 'openai': 'OpenAI', 'anthropic': 'Claude', 'kimi': 'Kimi', 'glm': 'GLM'};
    final defaultModels = {'bluelm': 'Doubao-Seed-2.0-mini', 'deepseek': 'deepseek-chat', 'qwen': 'qwen-turbo', 'doubao': 'doubao-lite-4k', 'openai': 'gpt-4o-mini', 'anthropic': 'claude-3-5-haiku-20241022', 'kimi': 'moonshot-v1-8k', 'glm': 'glm-4-flash'};
    final models = <Map<String, dynamic>>[];
    for (final p in providers) {
      final key = prefs.getString('${prefix}llm_key_$p') ?? '';
      if (key.isNotEmpty) {
        final model = prefs.getString('${prefix}llm_model_$p') ?? defaultModels[p] ?? '';
        models.add({'provider': p, 'name': providerNames[p] ?? p, 'model': model});
      }
    }
    if (models.isEmpty) {
      models.add({'provider': 'bluelm', 'name': 'vivo 蓝心', 'model': 'Doubao-Seed-2.0-mini'});
    }
    final savedProvider = prefs.getString('${prefix}chat_provider') ?? '';
    final savedModelName = prefs.getString('${prefix}chat_model') ?? '';
    Map<String, dynamic>? selected;
    if (savedProvider.isNotEmpty && savedModelName.isNotEmpty) {
      selected = models.firstWhere(
        (m) => m['provider'] == savedProvider && m['model'] == savedModelName,
        orElse: () => models.first,
      );
    } else {
      selected = models.first;
    }
    setState(() {
      _availableModels = models;
      _selectedProvider = selected!['provider'];
      _selectedModel = selected['model'];
    });
  }

  void _switchModel(Map<String, dynamic> model) async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('loginPhone') ?? '';
    final prefix = phone.isNotEmpty ? '${phone}_' : '';
    await prefs.setString('${prefix}chat_provider', model['provider']);
    await prefs.setString('${prefix}chat_model', model['model']);
    await prefs.commit(); // 确保持久化
    setState(() {
      _selectedProvider = model['provider'];
      _selectedModel = model['model'];
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int? _chatId; // 当前对话ID，用于续接

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    _streamReply(text);
  }

  /// SSE 流式调用后端 LLM
  void _streamReply(String message) async {
    final api = ApiService();
    String fullReply = '';
    final assistantIndex = _messages.length;

    // 先加一个空消息占位
    setState(() {
      _messages.add(_ChatMessage(role: 'assistant', content: ''));
    });

    try {
      await for (final event in api.chatStream(
        message: message,
        chatId: _chatId,
        city: widget.contextCity,
        model: _selectedProvider,  // 传 provider key，不是 model name
      )) {
        if (!mounted) return;
        if (event.type == 'start') {
          _chatId = event.chatId;
        } else if (event.type == 'chunk') {
          fullReply += event.content ?? '';
          setState(() {
            _messages[assistantIndex] = _ChatMessage(role: 'assistant', content: fullReply);
          });
          _scrollToBottom();
        } else if (event.type == 'done') {
          // 完成
        } else if (event.type == 'error') {
          fullReply = event.content ?? '请求失败';
          setState(() {
            _messages[assistantIndex] = _ChatMessage(role: 'assistant', content: '⚠️ $fullReply');
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: '⚠️ 连接失败：$e\n\n请检查后端是否启动，以及网络是否通畅。',
        );
      });
    } finally {
      if (mounted) setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _showModelSelector() {
    final providerNames = {'bluelm': 'vivo 蓝心', 'deepseek': 'DeepSeek', 'qwen': '通义千问', 'doubao': '豆包', 'openai': 'OpenAI', 'anthropic': 'Claude', 'kimi': 'Kimi', 'glm': 'GLM'};
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
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
              Icon(Icons.auto_awesome_rounded, color: AppColors.celadon, size: 20),
              const SizedBox(width: 8),
              Text('选择模型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
            ]),
            const SizedBox(height: 4),
            Text('当前: ${providerNames[_selectedProvider] ?? _selectedProvider} / $_selectedModel', style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _availableModels.length,
                itemBuilder: (ctx, i) {
                  final m = _availableModels[i];
                  final isSelected = m['provider'] == _selectedProvider && m['model'] == _selectedModel;
                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: AppColors.celadon.withOpacity(0.08),
                    leading: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      size: 18,
                      color: isSelected ? AppColors.celadon : AppColors.paperDim,
                    ),
                    title: Text(m['model'], style: TextStyle(fontSize: 13, fontFamily: 'JetBrainsMono', color: isSelected ? AppColors.celadon : AppColors.paper, decoration: TextDecoration.none)),
                    subtitle: Text(providerNames[m['provider']] ?? m['provider'], style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
                    onTap: () {
                      _switchModel(m);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.deepBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            children: [
              // ── 拖拽指示器 + 标题 ──
              _buildHeader(),
              // ── 聊天消息列表 ──
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == _messages.length) return _buildTypingIndicator();
                    return _buildMessageBubble(_messages[i]);
                  },
                ),
              ),
              // ── 输入区 ──
              _buildInputArea(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final contextLabel = widget.contextCity ?? widget.contextCompany ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.paperDim.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.celadon, size: 20),
              const SizedBox(width: 8),
              Text('AI 助手', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
              const SizedBox(width: 8),
              // 模型选择器
              GestureDetector(
                onTap: _showModelSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.celadon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.celadon.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedModel, style: TextStyle(fontSize: 11, color: AppColors.celadon, fontFamily: 'JetBrainsMono')),
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more_rounded, size: 14, color: AppColors.celadon),
                    ],
                  ),
                ),
              ),
              if (contextLabel.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.celadon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(contextLabel, style: TextStyle(fontSize: 11, color: AppColors.celadon)),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded, color: AppColors.paperDim, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.celadon.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.celadon),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.celadon.withOpacity(0.15) : AppColors.glassWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isUser ? AppColors.celadon.withOpacity(0.3) : AppColors.glassBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.content, style: TextStyle(fontSize: 14, color: AppColors.paper, height: 1.5, decoration: TextDecoration.none)),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.sky.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_rounded, size: 16, color: AppColors.sky),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.celadon.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.celadon),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0), const SizedBox(width: 4),
                _dot(1), const SizedBox(width: 4),
                _dot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (_, v, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.celadon.withOpacity(v),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 快捷问题按钮
            GestureDetector(
              onTap: _showQuickQuestions,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.glassWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Icon(Icons.bolt_rounded, size: 20, color: AppColors.sky),
              ),
            ),
            const SizedBox(width: 10),
            // 输入框
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.glassWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: AppColors.paper, fontSize: 14),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: '问我任何问题...',
                    hintStyle: TextStyle(color: AppColors.paperDim.withOpacity(0.5)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 发送按钮
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.celadon, AppColors.sky],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.send_rounded, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickQuestions() {
    final questions = _getQuickQuestions();
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
            Text('快捷问题', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
            const SizedBox(height: 12),
            ...questions.map((q) => GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _controller.text = q;
                _sendMessage();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.glassWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.sky),
                    const SizedBox(width: 10),
                    Expanded(child: Text(q, style: TextStyle(fontSize: 13, color: AppColors.paper))),
                    Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.paperDim),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<String> _getQuickQuestions() {
    switch (widget.role) {
      case 'gov':
        return [
          '分析当前城市的财政风险',
          '未来3年趋势预测',
          '有哪些政策建议？',
          '赤字率偏高怎么办？',
        ];
      case 'enterprise':
        return [
          '分析当前企业的财务健康度',
          '与同行业对比如何？',
          '有哪些经营风险？',
          '现金流是否充足？',
        ];
      default:
        return [
          '南京的财政风险如何？',
          '哪些城市风险较低？',
          '华为最近的财务数据怎么样？',
          '如何理解赤字率？',
        ];
    }
  }
}

class _ChatMessage {
  final String role;
  final String content;
  _ChatMessage({required this.role, required this.content});
}
