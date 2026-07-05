import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../models/prediction.dart';
import '../services/api_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/ink_bar_chart.dart';
import 'chat_panel.dart';
import 'upload_screen.dart';
import '../main.dart'; // routeObserver

/// 仪表盘 — 三角色差异化 + LLM 聊天面板
class DashboardTab extends StatefulWidget {
  final String role;
  final bool isGuest;
  const DashboardTab({super.key, required this.role, this.isGuest = false});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with RouteAware {
  final ApiService _api = ApiService();

  // ── 政务版状态 ──
  String _city = '南京';
  int _year = 2026;
  bool _loading = false;
  bool _showReport = false;
  PredictionResult? _result;
  String? _reportContent;
  String? _error;
  List<String> _cities = ['南京', '苏州', '无锡', '常州', '镇江']; // 默认值，会从后端覆盖
  final List<int> _years = [2026, 2025, 2024, 2023];

  // ── 企业版状态 ──
  String? _company;
  String? _period;
  final List<String> _companies = [];
  final List<String> _periods = [];

  // ── 民用版状态 ──
  String _searchQuery = '';
  List<Map<String, dynamic>> _publicData = [];
  bool _loadingPublic = false;
  Set<String> _favoriteCities = {};
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  // ── 政务版监控状态 ──
  Map<String, dynamic>? _monitorOverview;
  List<Map<String, dynamic>> _recentAlerts = [];
  // ── 搜索防抖 ──
  var _searchTimer;

  @override
  void initState() {
    super.initState();
    _loadCities();
    if (widget.role == 'citizen') {
      _loadPublicData();
      _loadFavorites();
    }
    if (widget.role == 'gov') {
      _loadMonitorOverview();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    _checkLlmConfig();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// 从其他页面返回时重新检查 LLM 配置
  @override
  void didPopNext() {
    _checkLlmConfig();
  }

  /// 加载公开数据（民用端）
  Future<void> _loadPublicData() async {
    setState(() => _loadingPublic = true);
    try {
      final result = await _api.getPublicData();
      setState(() => _publicData = List<Map<String, dynamic>>.from(result));
    } catch (_) {}
    setState(() => _loadingPublic = false);
  }

  /// 从后端加载城市列表
  Future<void> _loadCities() async {
    try {
      final cities = await _api.getCities();
      if (cities.isNotEmpty) {
        setState(() => _cities = cities);
      }
    } catch (_) {
      // 保持默认列表
    }
  }

  /// 加载收藏列表
  Future<void> _loadFavorites() async {
    try {
      final favs = await _api.getFavorites();
      setState(() => _favoriteCities = favs.map((f) => f['city'] as String).toSet());
    } catch (_) {}
  }

  /// 切换收藏
  Future<void> _toggleFavorite(String city) async {
    try {
      if (_favoriteCities.contains(city)) {
        await _api.removeFavorite(city);
        setState(() => _favoriteCities.remove(city));
      } else {
        await _api.addFavorite(city);
        setState(() => _favoriteCities.add(city));
      }
    } catch (_) {}
  }

  /// 搜索
  Future<void> _doSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await _api.search(query);
      final predictions = List<Map<String, dynamic>>.from(result['predictions'] ?? []);
      setState(() => _searchResults = predictions);
    } catch (_) {}
    setState(() => _searching = false);
  }

  /// 加载监控概览（政务端）
  Future<void> _loadMonitorOverview() async {
    try {
      final overview = await _api.getMonitorOverview();
      setState(() => _monitorOverview = overview);
      final alerts = await _api.getAlerts();
      setState(() => _recentAlerts = alerts.take(5).toList());
    } catch (_) {}
  }

  /// 调用预测 API
  Future<void> _predict() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _reportContent = null;
      _showReport = false;
    });
    try {
      final data = await _api.predict(city: _city, year: _year);
      setState(() => _result = PredictionResult.fromJson(data));
    } on ApiException catch (e) {
      if (e.code == 401) {
        _showLoginPrompt();
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '预测失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// 加载 AI 报告（懒加载）
  Future<void> _loadReport() async {
    if (_reportContent != null) return;
    try {
      final data = await _api.getReport(city: _city, year: _year);
      setState(() => _reportContent = data['content'] ?? '暂无报告');
    } on ApiException catch (e) {
      setState(() => _reportContent = '报告生成失败: ${e.message}');
    } catch (e) {
      setState(() => _reportContent = '报告生成失败: $e');
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('需要登录'),
        content: Text('请先登录后使用预测功能'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 切换到登录页 — 通过 MainScreen 的回调
            },
            child: Text('去登录'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(),
              const SizedBox(height: 16),
              if (widget.role == 'gov') _buildGovView(),
              if (widget.role == 'enterprise') _buildEnterpriseView(),
              if (widget.role == 'citizen') _buildCivilianView(),
              if (_error != null) ...[const SizedBox(height: 16), _buildError()],
              const SizedBox(height: 80), // 给悬浮按钮留空间
            ],
          ),
        ),
        // ── LLM 聊天悬浮按钮 ──
        Positioned(
          right: 16,
          bottom: 16,
          child: _buildChatFab(),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // 通用组件
  // ══════════════════════════════════════════════════════

  Widget _buildSectionTitle() {
    final titles = {
      'gov': '财政风险监测中心',
      'enterprise': '企业风险分析平台',
      'citizen': '公共数据查询',
    };
    final subtitles = {
      'gov': '实时监控 · 智能预警 · 合规报告',
      'enterprise': '风险评估 · 趋势分析 · 决策支持',
      'citizen': '城市 & 企业公开数据 · 透明监督',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titles[widget.role] ?? '仪表盘',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none)),
        const SizedBox(height: 4),
        Text(subtitles[widget.role] ?? '',
            style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
      ],
    );
  }

  bool _hasLlmConfig = false;

  Future<void> _checkLlmConfig() async {
    await Future.delayed(const Duration(milliseconds: 300)); // 短暂等待 loginPhone 加载
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('loginPhone') ?? '';
    final prefix = phone.isNotEmpty ? '${phone}_' : '';
    final providers = ['bluelm', 'deepseek', 'qwen', 'doubao', 'openai', 'anthropic', 'kimi', 'glm'];
    bool hasKey = false;
    for (final p in providers) {
      final key = prefs.getString('${prefix}llm_key_$p') ?? '';
      if (key.isNotEmpty) {
        hasKey = true;
        break;
      }
    }
    if (mounted) setState(() => _hasLlmConfig = hasKey);
  }

  Widget _buildChatFab() {
    final isDisabled = !_hasLlmConfig;
    return GestureDetector(
      onTap: isDisabled ? () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.deepBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.glassBorder)),
            title: Row(children: [
              Icon(Icons.warning_rounded, color: AppColors.warmApricot, size: 22),
              const SizedBox(width: 8),
              Text('未配置模型', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
            ]),
            content: Text('请先在 设置 → AI 模配 → 模型配置 中配置 AI 模型和 API Key', style: TextStyle(color: AppColors.paperMid)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('知道了', style: TextStyle(color: AppColors.celadon)),
              ),
            ],
          ),
        );
      } : () => _showChatPanel(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isDisabled ? null : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.celadon, AppColors.sky],
          ),
          color: isDisabled ? AppColors.glassBorder : null,
          boxShadow: isDisabled ? null : [
            BoxShadow(color: AppColors.celadon.withOpacity(0.3), blurRadius: 16, spreadRadius: 2),
          ],
        ),
        child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  void _showChatPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatPanel(
        role: widget.role,
        contextCity: widget.role != 'enterprise' ? _city : null,
        contextCompany: widget.role == 'enterprise' ? _company : null,
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.riskHigh.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.riskHigh.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: AppColors.riskHigh, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_error!, style: TextStyle(color: AppColors.riskHigh, fontSize: 13))),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  // 政务版 — 城市财政风险监测
  // ══════════════════════════════════════════════════════

  Widget _buildGovView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGovInputCard(),
        const SizedBox(height: 16),
        _buildMonitorCard(),
        const SizedBox(height: 16),
        _buildUploadEntry(),
        const SizedBox(height: 16),
        // 城市统计卡片
        _buildCityStatsCard(),
        const SizedBox(height: 16),
        // 预测结果
        if (_result != null) ...[
          _buildRiskOverview(),
          const SizedBox(height: 12),
          _buildTrendBanner(),
          const SizedBox(height: 16),
          _buildDetailTable(),
          const SizedBox(height: 16),
          _buildBarChart(),
        ] else ...[
          _buildEmptyState(
            icon: Icons.analytics_rounded,
            title: '暂无预测数据',
            subtitle: '选择城市和年份，点击「预测」按钮开始分析',
          ),
        ],
        const SizedBox(height: 16),
        // AI 报告 — 始终可点击
        _buildReportToggle(),
        if (_showReport) ...[
          const SizedBox(height: 8),
          _buildReportContent(),
        ],
        const SizedBox(height: 16),
        // 快捷分析
        _buildQuickAnalysisCard(),
      ],
    );
  }

  Widget _buildGovInputCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _dropdown<String>('城市', _city, _cities, (v) => setState(() => _city = v!), (v) => v)),
              const SizedBox(width: 12),
              Expanded(child: _dropdown<int>('年份', _year, _years, (v) => setState(() => _year = v!), (v) => '$v年')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _predict,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: Size.zero,
              ),
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('预测', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  /// 风险监控卡片（政务端）
  Widget _buildMonitorCard() {
    final normal = _monitorOverview?['normal'] ?? 0;
    final warning = _monitorOverview?['warning'] ?? 0;
    final critical = _monitorOverview?['critical'] ?? 0;
    final unresolved = _monitorOverview?['unresolved_alerts'] ?? 0;
    final scanned = _monitorOverview?['total_scanned'] ?? 0;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.shield_rounded, size: 18, color: AppColors.celadon),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('风险监控', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                Text('赤字率·债务率·负债率·风险评分', style: TextStyle(fontSize: 10, color: AppColors.paperDim)),
              ],
            ),
            const Spacer(),
            if (unresolved > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.riskHigh.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text('$unresolved 条告警', style: TextStyle(fontSize: 11, color: AppColors.riskHigh)),
              ),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              _monitorStat('正常', normal, AppColors.riskLow),
              const SizedBox(width: 12),
              _monitorStat('预警', warning, AppColors.warmApricot),
              const SizedBox(width: 12),
              _monitorStat('异常', critical, AppColors.riskHigh),
              const SizedBox(width: 12),
              _monitorStat('已扫描', scanned, AppColors.sky),
            ],
          ),
          if (_recentAlerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.glassBorder),
            const SizedBox(height: 8),
            Row(children: [
              Text('最近告警', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showAllAlerts(),
                child: Text('查看全部 →', style: TextStyle(fontSize: 11, color: AppColors.sky)),
              ),
            ]),
            const SizedBox(height: 6),
            ..._recentAlerts.take(3).map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(
                  a['level'] == 'critical' ? Icons.error_rounded : Icons.warning_rounded,
                  size: 14,
                  color: a['level'] == 'critical' ? AppColors.riskHigh : AppColors.warmApricot,
                ),
                const SizedBox(width: 6),
                // 显示城市+指标+消息
                Expanded(child: Text(
                  '${a['city'] ?? ''} · ${a['message'] ?? ''}',
                  style: TextStyle(fontSize: 11, color: AppColors.paperMid), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            )),
          ],
        ],
      ),
    );
  }

  Widget _monitorStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color, fontFamily: 'JetBrainsMono', decoration: TextDecoration.none)),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
        ]),
      ),
    );
  }

  Widget _buildUploadEntry() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      glow: true,
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UploadScreen()));
      },
        child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.celadon.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.cloud_upload_rounded, color: AppColors.celadon, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('数据上报', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                const SizedBox(height: 2),
                Text('上传财政数据，可选择公开或仅内部使用', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.paperDim, size: 20),
        ],
      ),
    );
  }

  /// 风险概览 — 单卡展示综合风险
  Widget _buildRiskOverview() {
    final r = _result!;
    final Color riskColor;
    switch (r.riskLevel) {
      case 'critical':
        riskColor = AppColors.riskHigh;
        break;
      case 'high':
        riskColor = AppColors.warmApricot;
        break;
      case 'medium':
        riskColor = AppColors.zhuyantuo;
        break;
      default:
        riskColor = AppColors.riskLow;
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 风险分数大数字
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                r.riskScore.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: riskColor,
                  fontFamily: 'JetBrainsMono',
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('风险评分', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
                  Text(r.riskLevelCn, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: riskColor, decoration: TextDecoration.none)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: r.riskScore / 100,
              minHeight: 6,
              backgroundColor: AppColors.cardBg,
              valueColor: AlwaysStoppedAnimation(riskColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: TextStyle(fontSize: 10, color: AppColors.paperDim)),
              Text('50', style: TextStyle(fontSize: 10, color: AppColors.paperDim)),
              Text('100', style: TextStyle(fontSize: 10, color: AppColors.paperDim)),
            ],
          ),
          if (r.cached) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cached_rounded, size: 12, color: AppColors.paperDim),
                const SizedBox(width: 4),
                Text('缓存结果', style: TextStyle(fontSize: 10, color: AppColors.paperDim)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 趋势横幅
  Widget _buildTrendBanner() {
    final r = _result!;
    final String trendText;
    final IconData trendIcon;
    final Color trendColor;

    switch (r.trend) {
      case 'rising':
        trendText = '风险呈上升趋势，建议关注';
        trendIcon = Icons.trending_up_rounded;
        trendColor = AppColors.riskHigh;
        break;
      case 'declining':
        trendText = '风险呈下降趋势，形势向好';
        trendIcon = Icons.trending_down_rounded;
        trendColor = AppColors.riskLow;
        break;
      default:
        trendText = '风险保持稳定';
        trendIcon = Icons.trending_flat_rounded;
        trendColor = AppColors.paperDim;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: trendColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(trendIcon, color: trendColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_city} ${_year}年财政风险${r.trendCn} — $trendText',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: trendColor),
            ),
          ),
        ],
      ),
    );
  }

  /// 详细指标表（从 detail 字段读取）
  Widget _buildDetailTable() {
    final detail = _result!.detail;
    if (detail.isEmpty) return const SizedBox();

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Expanded(flex: 3, child: Text('指标', style: TextStyle(fontSize: 12, color: AppColors.paperDim))),
              Expanded(flex: 2, child: Text('数值', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.paperDim))),
            ]),
          ),
          Divider(height: 1, color: AppColors.glassBorder),
          ...detail.entries.map((e) => _detailRow(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _detailRow(String key, dynamic value) {
    String displayValue;
    if (value is double) {
      displayValue = value.toStringAsFixed(2);
    } else if (value is num) {
      displayValue = value.toString();
    } else {
      displayValue = value?.toString() ?? '--';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(children: [
        Expanded(flex: 3, child: Text(key, style: TextStyle(fontSize: 13, color: AppColors.paper))),
        Expanded(flex: 2, child: Text(displayValue, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper, fontFamily: 'JetBrainsMono'))),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  // 企业版 — 企业财务风险分析
  // ══════════════════════════════════════════════════════

  Widget _buildEnterpriseView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEnterpriseInputCard(),
        const SizedBox(height: 16),
        _buildEnterpriseUploadEntry(),
        const SizedBox(height: 16),
        _buildEmptyState(
          icon: Icons.business_rounded,
          title: '暂无企业数据',
          subtitle: '请先上传企业财报，系统将自动分析财务健康度',
          actionLabel: '上传财报',
          onAction: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UploadScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildEnterpriseInputCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: _companies.isEmpty
          ? Row(
              children: [
                Icon(Icons.business_rounded, size: 20, color: AppColors.paperDim),
                const SizedBox(width: 10),
                Text('请先上传企业财报', style: TextStyle(fontSize: 14, color: AppColors.paperDim)),
              ],
            )
          : Row(
              children: [
                Expanded(child: _dropdown<String>('企业', _company ?? _companies.first, _companies, (v) => setState(() => _company = v), (v) => v)),
                const SizedBox(width: 12),
                Expanded(child: _dropdown<String>('周期', _period ?? _periods.first, _periods, (v) => setState(() => _period = v), (v) => v)),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('分析', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEnterpriseUploadEntry() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UploadScreen()));
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.sky.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.upload_file_rounded, color: AppColors.sky, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('上传企业财报', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                const SizedBox(height: 2),
                Text('支持 Excel / PDF，自动提取关键指标', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.paperDim, size: 20),
        ],
      ),
      ),
    ),
    );
  }

  // ══════════════════════════════════════════════════════
  // 民用版 — 公共数据查询
  // ══════════════════════════════════════════════════════

  Widget _buildCivilianView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBox(),
        const SizedBox(height: 20),
        // 搜索结果
        if (_searching)
          Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky))
        else if (_searchResults.isNotEmpty) ...[
          Row(children: [
            Text('搜索结果', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() { _searchResults = []; _searchQuery = ''; }),
              child: Text('清除', style: TextStyle(fontSize: 12, color: AppColors.sky)),
            ),
          ]),
          const SizedBox(height: 12),
          ..._searchResults.map((d) => _publicDataCard(d)),
          const SizedBox(height: 20),
        ],
        // 公开数据
        if (_loadingPublic)
          Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky))
        else if (_publicData.isEmpty && _searchResults.isEmpty)
          _buildEmptyState(
            icon: Icons.public_rounded,
            title: '暂无公开数据',
            subtitle: '政务端和企业端上传数据并选择「公开」后，将在此展示',
          )
        else if (_searchResults.isEmpty) ...[
          Text('公开数据', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
          const SizedBox(height: 12),
          ..._publicData.map((d) => _publicDataCard(d)),
        ],
      ],
    );
  }

  Widget _publicDataCard(Map<String, dynamic> d) {
    final city = d['city'] ?? '';
    final score = (d['risk_score'] as num?)?.toDouble() ?? 0;
    final level = d['risk_level'] ?? 'unknown';
    final isFav = _favoriteCities.contains(city);
    final Color levelColor;
    switch (level) {
      case 'critical': levelColor = AppColors.riskHigh; break;
      case 'high': levelColor = AppColors.warmApricot; break;
      case 'medium': levelColor = AppColors.zhuyantuo; break;
      default: levelColor = AppColors.riskLow;
    }
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: levelColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.location_city_rounded, size: 20, color: levelColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${city} ${d['year'] ?? ''}年', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
              Text('风险评分: ${score.toStringAsFixed(1)} · 趋势: ${d['trend'] ?? '-'}', style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
            ],
          ),
        ),
        // 收藏按钮
        GestureDetector(
          onTap: () => _toggleFavorite(city),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 20,
              color: isFav ? AppColors.riskHigh : AppColors.paperDim,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: levelColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
          child: Text(level, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: levelColor)),
        ),
      ]),
    );
  }

  Widget _buildSearchBox() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.paperDim, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _searchTimer?.cancel();
                _searchTimer = Timer(Duration(milliseconds: 400), () => _doSearch(v));
              },
              style: TextStyle(color: AppColors.paper, fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索城市、企业、指标...',
                hintStyle: TextStyle(color: AppColors.paperDim.withOpacity(0.6)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Icon(Icons.mic_rounded, color: AppColors.paperDim, size: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.celadon.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.celadon.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.paperDim), textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // 通用组件
  // ══════════════════════════════════════════════════════

  Widget _dropdown<T>(String label, T value, List<T> items, ValueChanged<T?> onChanged, String Function(T) text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBg.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: AppColors.cardBg,
            underline: const SizedBox(),
            style: TextStyle(color: AppColors.paper, fontSize: 14),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(text(e)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    final detail = _result!.detail;
    if (detail.isEmpty) return const SizedBox();

    final colors = [AppColors.zhengqing, AppColors.qingshan, AppColors.ziyan, AppColors.zhuyantuo, AppColors.piaobi, AppColors.celadon, AppColors.wozhe, AppColors.daran, AppColors.qingdai];
    final entries = detail.entries.where((e) => e.value is num).toList();
    final bars = <BarData>[];
    for (int i = 0; i < entries.length && i < 9; i++) {
      final val = (entries[i].value as num).toDouble();
      bars.add(BarData(
        label: entries.length > 8 ? entries[i].key.substring(0, min(4, entries[i].key.length)) : entries[i].key,
        value: val,
        color: colors[i % colors.length],
      ));
    }
    if (bars.isEmpty) return const SizedBox();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('指标概览', style: TextStyle(fontFamily: 'STKaiti', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
          const SizedBox(height: 12),
          Center(child: InkBarChart(data: bars, maxWidth: MediaQuery.of(context).size.width - 80, maxHeight: 200)),
        ],
      ),
    );
  }

  Widget _buildReportToggle() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () {
        setState(() => _showReport = !_showReport);
        if (_showReport) _loadReport();
      },
      child: Row(children: [
        Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.sky),
        const SizedBox(width: 8),
        Text('AI 分析报告', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
        const Spacer(),
        AnimatedRotation(turns: _showReport ? 0.5 : 0, duration: Duration(milliseconds: 200), child: Icon(Icons.expand_more_rounded, color: AppColors.paperDim)),
      ]),
    );
  }

  Widget _buildReportContent() {
    if (_reportContent == null) {
      return GlassCard(
        padding: const EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky)),
      );
    }
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.sky),
            const SizedBox(width: 6),
            Text('由蓝心大模型生成', style: TextStyle(fontSize: 11, color: AppColors.sky)),
          ]),
          const SizedBox(height: 12),
          ..._parseReport(_reportContent!),
        ],
      ),
    );
  }

  // 城市统计数据
  List<Map<String, dynamic>> _cityStats = [];

  Widget _buildCityStatsCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _api.getCityStats(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox();
        final stats = snap.data!;
        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.sky),
                const SizedBox(width: 8),
                Text('数据概览', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
              ]),
              const SizedBox(height: 12),
              Row(
                children: stats.take(4).map((s) => Expanded(
                  child: _statMiniCard(s['city'], '${s['count']}条', '${(s['avg_score'] ?? 0).toStringAsFixed(0)}分'),
                )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statMiniCard(String city, String count, String score) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(children: [
        Text(city, style: TextStyle(fontSize: 11, color: AppColors.paperDim, decoration: TextDecoration.none)),
        const SizedBox(height: 4),
        Text(count, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.celadon, decoration: TextDecoration.none)),
        const SizedBox(height: 2),
        Text('均分 $score', style: TextStyle(fontSize: 10, color: AppColors.paperDim)),
      ]),
    );
  }

  // 快捷分析卡片
  Widget _buildQuickAnalysisCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.speed_rounded, size: 18, color: AppColors.warmApricot),
            const SizedBox(width: 8),
            Text('快捷分析', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _quickAction(Icons.show_chart_rounded, '趋势预测', AppColors.celadon, () => _predict())),
            const SizedBox(width: 8),
            Expanded(child: _quickAction(Icons.auto_awesome_rounded, 'AI报告', AppColors.sky, () { setState(() => _showReport = true); _loadReport(); })),
            const SizedBox(width: 8),
            Expanded(child: _quickAction(Icons.warning_rounded, '风险扫描', AppColors.warmApricot, () => _scanRisk())),
          ]),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, decoration: TextDecoration.none)),
        ]),
      ),
    );
  }

  void _scanRisk() async {
    try {
      final result = await _api.triggerScan(city: _city);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '扫描完成'), backgroundColor: AppColors.celadon, duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描失败: $e'), backgroundColor: AppColors.riskHigh, duration: Duration(seconds: 2)),
        );
      }
    }
  }

  void _showAllAlerts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            Row(children: [
              Icon(Icons.warning_rounded, color: AppColors.warmApricot, size: 22),
              const SizedBox(width: 8),
              Text('全部告警', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close_rounded, color: AppColors.paperDim)),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: _recentAlerts.isEmpty
                  ? Center(child: Text('暂无告警', style: TextStyle(color: AppColors.paperDim)))
                  : ListView.builder(
                      itemCount: _recentAlerts.length,
                      itemBuilder: (ctx, i) {
                        final a = _recentAlerts[i];
                        final isCritical = a['level'] == 'critical';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isCritical ? AppColors.riskHigh : AppColors.warmApricot).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: (isCritical ? AppColors.riskHigh : AppColors.warmApricot).withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            Icon(isCritical ? Icons.error_rounded : Icons.warning_rounded, size: 18, color: isCritical ? AppColors.riskHigh : AppColors.warmApricot),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${a['city'] ?? ''}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                              Text(a['message'] ?? '', style: TextStyle(fontSize: 12, color: AppColors.paperMid)),
                            ])),
                            Text(a['level'] ?? '', style: TextStyle(fontSize: 11, color: isCritical ? AppColors.riskHigh : AppColors.warmApricot)),
                          ]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _parseReport(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 6));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(padding: EdgeInsets.only(top: 10, bottom: 4), child: Text(line.substring(3), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none))));
      } else if (line.startsWith('### ')) {
        widgets.add(Padding(padding: EdgeInsets.only(top: 8, bottom: 3), child: Text(line.substring(4), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none))));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(Padding(padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('•  ', style: TextStyle(color: AppColors.sky)),
          Expanded(child: _richText(line.substring(2))),
        ])));
      } else if (RegExp(r'^\d+\.').hasMatch(line)) {
        final m = RegExp(r'^(\d+\.)\s*(.*)').firstMatch(line);
        if (m != null) widgets.add(Padding(padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m.group(1)} ', style: TextStyle(color: AppColors.sky, fontWeight: FontWeight.bold)),
          Expanded(child: _richText(m.group(2)!)),
        ])));
      } else {
        widgets.add(_richText(line));
      }
    }
    return widgets;
  }

  Widget _richText(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start), style: TextStyle(fontSize: 13, color: AppColors.paperMid, height: 1.6)));
      spans.add(TextSpan(text: m.group(1), style: TextStyle(fontSize: 13, color: AppColors.paper, fontWeight: FontWeight.bold, height: 1.6)));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: TextStyle(fontSize: 13, color: AppColors.paperMid, height: 1.6)));
    return RichText(text: TextSpan(children: spans));
  }
}

int min(int a, int b) => a < b ? a : b;
