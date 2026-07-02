import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/prediction.dart';
import '../services/api_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/ink_bar_chart.dart';
import 'chat_panel.dart';

/// 仪表盘 — 三角色差异化 + LLM 聊天面板
class DashboardTab extends StatefulWidget {
  final String role;
  final bool isGuest;
  const DashboardTab({super.key, required this.role, this.isGuest = false});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final ApiService _api = ApiService();

  // ── 政务版状态 ──
  String _city = '南京';
  int _year = 2026;
  bool _loading = false;
  bool _showReport = false;
  PredictionResult? _result;
  String? _error;
  final List<String> _cities = ['南京', '苏州', '无锡', '常州', '镇江'];
  final List<int> _years = [2026, 2025, 2024, 2023];

  // ── 企业版状态 ──
  String? _company;
  String? _period;
  final List<String> _companies = [];
  final List<String> _periods = [];

  // ── 民用版状态 ──
  String _searchQuery = '';

  Future<void> _predict() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final r = await _api.predictByCity(city: _city, year: _year, report: true);
      setState(() => _result = r);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '预测失败: $e');
    } finally {
      setState(() => _loading = false);
    }
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
              if (widget.role == '政务版') _buildGovView(),
              if (widget.role == '企业版') _buildEnterpriseView(),
              if (widget.role == '民用版') _buildCivilianView(),
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
      '政务版': '财政风险监测中心',
      '企业版': '企业风险分析平台',
      '民用版': '公共数据查询',
    };
    final subtitles = {
      '政务版': '实时监控 · 智能预警 · 合规报告',
      '企业版': '风险评估 · 趋势分析 · 决策支持',
      '民用版': '城市 & 企业公开数据 · 透明监督',
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

  Widget _buildChatFab() {
    return GestureDetector(
      onTap: () => _showChatPanel(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.celadon, AppColors.sky],
          ),
          boxShadow: [
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
        contextCity: widget.role != '企业版' ? _city : null,
        contextCompany: widget.role == '企业版' ? _company : null,
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
        // 输入区：城市 + 年份 + 预测按钮
        _buildGovInputCard(),
        const SizedBox(height: 16),
        // 数据上报入口
        _buildUploadEntry(),
        const SizedBox(height: 16),
        // 有结果时：展示完整分析
        if (_result != null) ...[
          _buildWarningBanner(),
          const SizedBox(height: 12),
          _buildGovRiskCards(),
          const SizedBox(height: 16),
          _buildMetricsTable(),
          const SizedBox(height: 16),
          _buildBarChart(),
          const SizedBox(height: 16),
          _buildReportToggle(),
          if (_showReport && _result?.aiReport != null) ...[
            const SizedBox(height: 8),
            _buildReportContent(),
          ],
        ] else ...[
          // 无结果时：空状态引导
          _buildEmptyState(
            icon: Icons.analytics_rounded,
            title: '暂无预测数据',
            subtitle: '选择城市和年份，点击「预测」按钮开始分析',
          ),
        ],
      ],
    );
  }

  Widget _buildGovInputCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _dropdown<String>('城市', _city, _cities, (v) => setState(() => _city = v!), (v) => v)),
          const SizedBox(width: 12),
          Expanded(child: _dropdown<int>('年份', _year, _years, (v) => setState(() => _year = v!), (v) => '$v年')),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _predict,
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('预测', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadEntry() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      glow: true,
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

  Widget _buildGovRiskCards() {
    if (_result == null) {
      return Row(children: [
        Expanded(child: RiskCard.empty(title: '财政风险')),
        const SizedBox(width: 8),
        Expanded(child: RiskCard.empty(title: '金融风险')),
        const SizedBox(width: 8),
        Expanded(child: RiskCard.empty(title: '综合风险')),
      ]);
    }
    return Row(children: [
      Expanded(child: RiskCard(title: '财政风险', level: _result!.fiscalRisk.level, confidence: _result!.fiscalRisk.confidencePercent, color: AppColors.riskColor(_result!.fiscalRisk.level))),
      const SizedBox(width: 8),
      Expanded(child: RiskCard(title: '金融风险', level: _result!.financeRisk.level, confidence: _result!.financeRisk.confidencePercent, color: AppColors.riskColor(_result!.financeRisk.level))),
      const SizedBox(width: 8),
      Expanded(child: RiskCard(title: '综合风险', level: _result!.overallRisk.level, confidence: _result!.overallRisk.confidencePercent, color: AppColors.riskColor(_result!.overallRisk.level))),
    ]);
  }

  // ══════════════════════════════════════════════════════
  // 企业版 — 企业财务风险分析
  // ══════════════════════════════════════════════════════

  Widget _buildEnterpriseView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 输入区：企业名 + 分析周期
        _buildEnterpriseInputCard(),
        const SizedBox(height: 16),
        // 数据上传入口
        _buildEnterpriseUploadEntry(),
        const SizedBox(height: 16),
        // 空状态引导
        _buildEmptyState(
          icon: Icons.business_rounded,
          title: '暂无企业数据',
          subtitle: '请先上传企业财报，系统将自动分析财务健康度',
          actionLabel: '上传财报',
          onAction: () {},
        ),
      ],
    );
  }

  Widget _buildEnterpriseInputCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: _companies.isEmpty
          ? Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.business_rounded, size: 20, color: AppColors.paperDim),
                    const SizedBox(width: 10),
                    Text('请先上传企业财报', style: TextStyle(fontSize: 14, color: AppColors.paperDim)),
                  ],
                ),
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
    return GlassCard(
      padding: const EdgeInsets.all(16),
      glow: true,
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
    );
  }



  // ══════════════════════════════════════════════════════
  // 民用版 — 公共数据查询（城市 + 企业）
  // ══════════════════════════════════════════════════════

  Widget _buildCivilianView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 搜索框
        _buildSearchBox(),
        const SizedBox(height: 20),
        // 空状态引导
        _buildEmptyState(
          icon: Icons.public_rounded,
          title: '暂无公开数据',
          subtitle: '政务端和企业端上传数据并选择公开后，将在此展示',
        ),
      ],
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
              onChanged: (v) => setState(() => _searchQuery = v),
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
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // 通用组件（下拉框、图表、报告）
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

  Widget _buildWarningBanner() {
    final w = _result!.warning;
    final c = AppColors.sky;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: c, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.level, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c)),
                Text(w.message, style: TextStyle(fontSize: 12, color: c.withOpacity(0.7)), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsTable() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Expanded(flex: 3, child: Text('指标', style: TextStyle(fontSize: 12, color: AppColors.paperDim))),
              Expanded(flex: 2, child: Text('当前值', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.paperDim))),
              Expanded(flex: 2, child: Text('安全线', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.paperDim))),
              Expanded(flex: 2, child: Text('状态', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.paperDim))),
            ]),
          ),
          Divider(height: 1, color: AppColors.glassBorder),
          ...indicatorLimits.asMap().entries.map((e) {
            final limit = e.value;
            final val = _result!.metrics[limit.name];
            return _metricRow(limit, val);
          }),
        ],
      ),
    );
  }

  Widget _metricRow(IndicatorLimit limit, double? value) {
    final bool safe;
    final String status;
    final Color sc;
    if (value == null) {
      safe = true; status = '--'; sc = AppColors.paperDim;
    } else if (limit.lowerIsBetter) {
      safe = value < limit.limit; status = safe ? '正常' : '警戒'; sc = safe ? AppColors.riskLow : AppColors.riskHigh;
    } else {
      safe = value > limit.limit; status = safe ? '正常' : '偏低'; sc = safe ? AppColors.riskLow : AppColors.warmApricot;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(children: [
        Expanded(flex: 3, child: Text(limit.name, style: TextStyle(fontSize: 13, color: AppColors.paper))),
        Expanded(flex: 2, child: Text(value != null ? '${value.toStringAsFixed(1)}${limit.unit}' : '--', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value != null ? AppColors.paper : AppColors.paperDim))),
        Expanded(flex: 2, child: Text(limit.lowerIsBetter ? '<${limit.limit}${limit.unit}' : '>${limit.limit}${limit.unit}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.paperDim))),
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
          child: Text(status, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sc)),
        )),
      ]),
    );
  }

  Widget _buildBarChart() {
    final metrics = _result!.metrics;
    final colors = [AppColors.zhengqing, AppColors.qingshan, AppColors.ziyan, AppColors.zhuyantuo, AppColors.piaobi, AppColors.celadon, AppColors.wozhe, AppColors.daran, AppColors.qingdai];
    final entries = metrics.entries.toList();
    final bars = <BarData>[];
    for (int i = 0; i < entries.length && i < 9; i++) {
      bars.add(BarData(
        label: entries[i].key.replaceAll('(%)', '').replaceAll('率', ''),
        value: entries[i].value,
        color: colors[i % colors.length],
      ));
    }
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
    if (_result == null) return const SizedBox();
    return GestureDetector(
      onTap: () => setState(() => _showReport = !_showReport),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.sky),
          const SizedBox(width: 8),
          Text('AI 分析报告', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
          const Spacer(),
          AnimatedRotation(turns: _showReport ? 0.5 : 0, duration: Duration(milliseconds: 200), child: Icon(Icons.expand_more_rounded, color: AppColors.paperDim)),
        ]),
      ),
    );
  }

  Widget _buildReportContent() {
    final report = _result!.aiReport!;
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
          ..._parseReport(report),
        ],
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
