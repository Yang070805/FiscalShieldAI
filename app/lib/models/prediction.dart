/// API 响应数据模型
class PredictionResult {
  final String city;
  final int year;
  final RiskInfo fiscalRisk;
  final RiskInfo financeRisk;
  final RiskInfo overallRisk;
  final WarningInfo warning;
  final Map<String, double> metrics;
  final String explanation;
  final PerformanceInfo? performance;
  final String? aiReport;

  PredictionResult({
    required this.city,
    required this.year,
    required this.fiscalRisk,
    required this.financeRisk,
    required this.overallRisk,
    required this.warning,
    required this.metrics,
    required this.explanation,
    this.performance,
    this.aiReport,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      city: json['city'] ?? '',
      year: json['year'] ?? 0,
      fiscalRisk: RiskInfo.fromJson(json['fiscal_risk'] ?? {}),
      financeRisk: RiskInfo.fromJson(json['finance_risk'] ?? {}),
      overallRisk: RiskInfo.fromJson(json['overall_risk'] ?? {}),
      warning: WarningInfo.fromJson(json['warning'] ?? {}),
      metrics: Map<String, double>.from(
        (json['metrics'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      explanation: json['explanation'] ?? '',
      performance: json['performance'] != null ? PerformanceInfo.fromJson(json['performance']) : null,
      aiReport: json['ai_report'],
    );
  }
}

class RiskInfo {
  final String level;
  final int levelIndex;
  final double confidence;
  final List<double> probabilityDistribution;

  RiskInfo({required this.level, required this.levelIndex, required this.confidence, required this.probabilityDistribution});

  factory RiskInfo.fromJson(Map<String, dynamic> json) {
    return RiskInfo(
      level: json['level'] ?? '--',
      levelIndex: json['level_index'] ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      probabilityDistribution: (json['probability_distribution'] as List<dynamic>? ?? []).map((e) => (e as num).toDouble()).toList(),
    );
  }

  double get confidencePercent => confidence * 100;
}

class WarningInfo {
  final String level;
  final String color;
  final String message;
  final bool thresholdMet;

  WarningInfo({required this.level, required this.color, required this.message, required this.thresholdMet});

  factory WarningInfo.fromJson(Map<String, dynamic> json) {
    return WarningInfo(
      level: json['level'] ?? '',
      color: json['color'] ?? '#8BC34A',
      message: json['message'] ?? '',
      thresholdMet: json['threshold_met'] ?? false,
    );
  }
}

class PerformanceInfo {
  final double inferenceTimeMs;
  final String device;
  PerformanceInfo({required this.inferenceTimeMs, required this.device});

  factory PerformanceInfo.fromJson(Map<String, dynamic> json) {
    return PerformanceInfo(
      inferenceTimeMs: (json['inference_time_ms'] as num).toDouble(),
      device: json['device'] ?? 'cpu',
    );
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
