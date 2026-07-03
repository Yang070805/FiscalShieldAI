/// 预测结果数据模型 — 匹配后端 /predict 响应
class PredictionResult {
  final String city;
  final int year;
  final double riskScore; // 0-100
  final String riskLevel; // low/medium/high/critical
  final String trend; // rising/stable/declining
  final Map<String, dynamic> detail;
  final bool cached;

  PredictionResult({
    required this.city,
    required this.year,
    required this.riskScore,
    required this.riskLevel,
    required this.trend,
    this.detail = const {},
    this.cached = false,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      city: json['city'] ?? '',
      year: json['year'] ?? 0,
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0,
      riskLevel: json['risk_level'] ?? 'low',
      trend: json['trend'] ?? 'stable',
      detail: Map<String, dynamic>.from(json['detail'] ?? {}),
      cached: json['cached'] ?? false,
    );
  }

  /// 风险等级中文
  String get riskLevelCn {
    switch (riskLevel) {
      case 'critical': return '极高风险';
      case 'high': return '高风险';
      case 'medium': return '中等风险';
      case 'low': return '低风险';
      default: return '未知';
    }
  }

  /// 趋势中文
  String get trendCn {
    switch (trend) {
      case 'rising': return '上升';
      case 'declining': return '下降';
      case 'stable': return '稳定';
      default: return '未知';
    }
  }

  /// 风险等级对应颜色 (ARGB hex)
  String get riskColorHex {
    switch (riskLevel) {
      case 'critical': return '#D32F2F'; // 红
      case 'high': return '#F57C00';     // 橙
      case 'medium': return '#FBC02D';   // 黄
      case 'low': return '#388E3C';      // 绿
      default: return '#757575';         // 灰
    }
  }
}

/// 指标安全线
class IndicatorLimit {
  final String name;
  final double limit;
  final String unit;
  final bool lowerIsBetter;
  const IndicatorLimit(this.name, this.limit, this.unit, this.lowerIsBetter);
}

const List<IndicatorLimit> indicatorLimits = [
  IndicatorLimit('负债率', 60, '%', true),
  IndicatorLimit('债务率', 100, '%', true),
  IndicatorLimit('赤字率', 3, '%', true),
  IndicatorLimit('现金短期债务比', 1, '', false),
  IndicatorLimit('短期债务占比', 50, '%', true),
  IndicatorLimit('存贷比', 100, '%', true),
  IndicatorLimit('不良贷款率', 5, '%', true),
  IndicatorLimit('拨备覆盖率', 150, '%', false),
  IndicatorLimit('资本充足率', 10.5, '%', false),
];
