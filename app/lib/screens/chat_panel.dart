import 'package:flutter/material.dart';
import '../config/colors.dart';
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

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    // 模拟 LLM 回复（后端接入后替换）
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final reply = _generateMockReply(text);
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', content: reply));
        _isTyping = false;
      });
      _scrollToBottom();
    });
  }

  String _generateMockReply(String question) {
    final q = question.toLowerCase();
    if (q.contains('风险') || q.contains('risk')) {
      return '根据当前数据分析：\n\n• **财政风险**：赤字率处于警戒线附近，需关注\n• **债务率**：整体可控，但增速较快\n• **建议**：优化支出结构，控制新增债务\n\n如需详细报告，可在仪表盘查看 AI 分析报告。';
    } else if (q.contains('预测') || q.contains('趋势')) {
      return '基于 ST-GNN + LightTCN 双引擎模型预测：\n\n• 未来 3 年 GDP 增速预计维持在 4.5%-5.5%\n• 财政收入增速可能放缓\n• 债务率需持续监控\n\n⚠️ 预测结果仅供参考，实际受政策和市场影响。';
    } else if (q.contains('政策') || q.contains('建议')) {
      return '综合分析建议：\n\n1. **优化支出结构**：减少非必要开支，保障重点领域\n2. **拓宽收入来源**：培育新税源，提高税收效率\n3. **控制债务规模**：合理安排举债节奏，防范风险\n4. **加强绩效管理**：提高财政资金使用效益';
    } else {
      return '收到你的问题：「$question」\n\n这是一个好问题！后端 LLM 接入后，我会基于真实数据给出更精准的分析。\n\n目前为演示模式，你可以尝试问我：\n• 某城市的财政风险如何？\n• 未来趋势预测\n• 政策建议';
    }
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
      case '政务版':
        return [
          '分析当前城市的财政风险',
          '未来3年趋势预测',
          '有哪些政策建议？',
          '赤字率偏高怎么办？',
        ];
      case '企业版':
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
