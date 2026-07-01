import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/colors.dart';

/// 水墨风格 3D 柱形图
/// 参考 XCL-Charts：offset + angle 伪3D，三面体渲染，渐变光照
class InkBarChart extends StatelessWidget {
  final List<BarData> data;
  final double maxWidth;
  final double maxHeight;

  const InkBarChart({
    super.key,
    required this.data,
    this.maxWidth = 300,
    this.maxHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(maxWidth, maxHeight),
      painter: _InkBarPainter(data: data),
    );
  }
}

class BarData {
  final String label;
  final double value;
  final Color color;
  const BarData({required this.label, required this.value, required this.color});
}

class _InkBarPainter extends CustomPainter {
  final List<BarData> data;
  _InkBarPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.map((d) => d.value).reduce(math.max);
    final barCount = data.length;
    final barWidth = (size.width * 0.6) / barCount;
    final spacing = (size.width * 0.4) / (barCount + 1);
    final chartHeight = size.height * 0.75;
    final baseY = size.height * 0.85;

    // 3D 偏移参数（参考 XCL-Charts）
    const thickness = 16.0;
    const angle = 45.0;
    final offsetX = thickness * math.cos(angle * math.pi / 180);
    final offsetY = thickness * math.sin(angle * math.pi / 180);

    // 绘制网格线（宣纸效果）
    _drawGrid(canvas, size, baseY, chartHeight);

    for (int i = 0; i < barCount; i++) {
      final d = data[i];
      final barHeight = (d.value / maxVal) * chartHeight;
      final left = spacing + i * (barWidth + spacing);
      final top = baseY - barHeight;
      final right = left + barWidth;

      // ── 正面（浅色渐变，模拟光照） ──
      final frontPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            d.color.withOpacity(0.95),
            d.color.withOpacity(0.65),
          ],
        ).createShader(Rect.fromLTWH(left - offsetX, top + offsetY, barWidth, barHeight));
      canvas.drawRect(
        Rect.fromLTWH(left - offsetX, top + offsetY, barWidth, barHeight),
        frontPaint,
      );

      // ── 顶面（深色，平行四边形） ──
      final topPaint = Paint()..color = d.color.withOpacity(0.7);
      final topPath = Path()
        ..moveTo(left, top)
        ..lineTo(left - offsetX, top + offsetY)
        ..lineTo(right - offsetX, top + offsetY)
        ..lineTo(right, top)
        ..close();
      canvas.drawPath(topPath, topPaint);

      // ── 右侧面（中等色） ──
      final sidePaint = Paint()..color = d.color.withOpacity(0.5);
      final sidePath = Path()
        ..moveTo(right, top)
        ..lineTo(right - offsetX, top + offsetY)
        ..lineTo(right - offsetX, baseY + offsetY)
        ..lineTo(right, baseY)
        ..close();
      canvas.drawPath(sidePath, sidePaint);

      // ── 白色轮廓高光（参考 XCL-Charts） ──
      final highlightPaint = Paint()
        ..color = AppColors.gaoyu.withOpacity(0.4)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      // 顶面高光线
      canvas.drawLine(Offset(left, top), Offset(left - offsetX, top + offsetY), highlightPaint);
      // 右侧高光线
      canvas.drawLine(Offset(right, top), Offset(right - offsetX, top + offsetY), highlightPaint);
      canvas.drawLine(Offset(right - offsetX, top + offsetY), Offset(right - offsetX, baseY + offsetY), highlightPaint);

      // ── 标签 ──
      final tp = TextPainter(
        text: TextSpan(
          text: d.label,
          style: TextStyle(fontSize: 10, color: AppColors.paperDim),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left + (barWidth - tp.width) / 2, baseY + offsetY + 6));

      // ── 数值 ──
      final vp = TextPainter(
        text: TextSpan(
          text: d.value.toStringAsFixed(1),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.paper),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      vp.paint(canvas, Offset(left + (barWidth - vp.width) / 2, top + offsetY - 18));
    }
  }

  void _drawGrid(Canvas canvas, Size size, double baseY, double chartHeight) {
    final gridPaint = Paint()
      ..color = AppColors.paperDim.withOpacity(0.08)
      ..strokeWidth = 0.5;

    // 横线
    for (int i = 0; i <= 4; i++) {
      final y = baseY - (chartHeight / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
