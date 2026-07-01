import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/prediction.dart';
import '../services/api_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/ink_bar_chart.dart';

/// 仪表盘 — 预测 + 风险卡片 + 指标表 + AI 报告
class DashboardTab extends StatefulWidget {
  final String role;
  final bool isGuest;
  const DashboardTab({super.key, required this.role, this.isGuest = false});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final ApiService _api = ApiService();
  String _city = '南京';
  int _year = 2026;
  bool _loading = false;
  bool _showReport = false;
  PredictionResult? _result;
  String? _error;

  final List<String> _cities = ['南京', '苏州', '无锡', '常州', '镇江'];
  final List<int> _years = [2026, 2025, 2024, 2023];

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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputCard(),
          const SizedBox(height: 16),
          if (_result != null) _buildWarningBanner(),
          if (_result != null) const SizedBox(height: 16),
          _buildRiskCards(),
          const SizedBox(height: 16),
          if (_result != null) _buildMetricsTable(),
          if (_result != null) const SizedBox(height: 16),
          // 3D 柱形图（参考 XCL-Charts）
          if (_result != null) _buildBarChart(),
          if (_result != null) const SizedBox(height: 16),
          _buildReportToggle(),
          if (_showReport && _result?.aiReport != null) ...[
            const SizedBox(height: 8),
            _buildReportContent(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            _buildError(),
          ],
          if (_result?.performance != null) ...[
            const SizedBox(height: 8),
            _buildPerf(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── 输入区 ──
  Widget _buildInputCard() {
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

  Widget _dropdown<T>(String label, T value, List<T> items, ValueChanged<T?> onChanged, String Function(T) text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.paperDim)),
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
            style: const TextStyle(color: AppColors.paper, fontSize: 14),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(text(e)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ── 预警横幅 ──
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

  // ── 风险卡片 ──
  Widget _buildRiskCards() {
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

  // ── 指标表 ──
  Widget _buildMetricsTable() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 表头
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
        Expanded(flex: 3, child: Text(limit.name, style: const TextStyle(fontSize: 13, color: AppColors.paper))),
        Expanded(flex: 2, child: Text(value != null ? '${value.toStringAsFixed(1)}${limit.unit}' : '--', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value != null ? AppColors.paper : AppColors.paperDim))),
        Expanded(flex: 2, child: Text(limit.lowerIsBetter ? '<${limit.limit}${limit.unit}' : '>${limit.limit}${limit.unit}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.paperDim))),
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
          child: Text(status, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sc)),
        )),
      ]),
    );
  }

  // ── 3D 柱形图 ──
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
          const Text('指标概览', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
          const SizedBox(height: 12),
          Center(child: InkBarChart(data: bars, maxWidth: MediaQuery.of(context).size.width - 80, maxHeight: 200)),
        ],
      ),
    );
  }

  // ── AI 报告 ──
  Widget _buildReportToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showReport = !_showReport),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.sky),
          const SizedBox(width: 8),
          const Text('AI 分析报告', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
          const Spacer(),
          AnimatedRotation(turns: _showReport ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: const Icon(Icons.expand_more_rounded, color: AppColors.paperDim)),
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
            const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.sky),
            const SizedBox(width: 6),
            const Text('由蓝心大模型生成', style: TextStyle(fontSize: 11, color: AppColors.sky)),
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
        widgets.add(Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(line.substring(3), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none))));
      } else if (line.startsWith('### ')) {
        widgets.add(Padding(padding: const EdgeInsets.only(top: 8, bottom: 3), child: Text(line.substring(4), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none))));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(Padding(padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('•  ', style: TextStyle(color: AppColors.sky)),
          Expanded(child: _richText(line.substring(2))),
        ])));
      } else if (RegExp(r'^\d+\.').hasMatch(line)) {
        final m = RegExp(r'^(\d+\.)\s*(.*)').firstMatch(line);
        if (m != null) widgets.add(Padding(padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m.group(1)} ', style: const TextStyle(color: AppColors.sky, fontWeight: FontWeight.bold)),
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
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start), style: const TextStyle(fontSize: 13, color: AppColors.paperMid, height: 1.6)));
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontSize: 13, color: AppColors.paper, fontWeight: FontWeight.bold, height: 1.6)));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: const TextStyle(fontSize: 13, color: AppColors.paperMid, height: 1.6)));
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.riskHigh.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.riskHigh.withOpacity(0.25))),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.riskHigh, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.riskHigh, fontSize: 13))),
      ]),
    );
  }

  Widget _buildPerf() {
    final p = _result!.performance!;
    return Center(
      child: Text('推理 ${p.inferenceTimeMs.toStringAsFixed(1)}ms · ${p.device.toUpperCase()}', style: const TextStyle(fontSize: 11, color: AppColors.paperDim)),
    );
  }
}
