import 'dart:math';
import 'package:flutter/material.dart';
import '../config/colors.dart';

/// 水墨世界 — 80% 传统水墨 + 20% 3D
/// 配色：shuimo-ui 原版五行色
class InkWorld extends StatefulWidget {
  final Widget child;
  final bool static; // true 时停止动画（撕开时用）
  const InkWorld({super.key, required this.child, this.static = false});

  /// 墨底层（最深，shuimo-ui 水·冬原色）
  static Widget inkBase() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0E16),
            Color(0xFF151D29),
            Color(0xFF1A2847),
            Color(0xFF12264F),
            Color(0xFF0B1018),
          ],
        ),
      ),
    );
  }

  /// 笔触层（墨流线条，需要 AnimationController）
  static Widget inkBrush(AnimationController ctrl) {
    return ListenableBuilder(
      listenable: ctrl,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: InkBrushPainter(time: ctrl.value * 20),
      ),
    );
  }

  /// 雾气层（需要 AnimationController）
  static Widget inkMist(AnimationController ctrl) {
    return ListenableBuilder(
      listenable: ctrl,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: MistPainter(time: ctrl.value * 30),
      ),
    );
  }

  @override
  State<InkWorld> createState() => _InkWorldState();
}

class _InkWorldState extends State<InkWorld> with TickerProviderStateMixin {
  late AnimationController _brushCtrl;
  late AnimationController _mistCtrl;

  @override
  void initState() {
    super.initState();
    _brushCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20));
    _mistCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 30));
    if (!widget.static) {
      _brushCtrl.repeat();
      _mistCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _brushCtrl.dispose();
    _mistCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 墨底（shuimo-ui 水·冬原色）
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A0E16), // 极深
                Color(0xFF151D29), // 獭见（shuimo-ui 水·阳）
                Color(0xFF1A2847), // 花青（shuimo-ui 金·秋）
                Color(0xFF12264F), // 麒麟（shuimo-ui 木·冬）
                Color(0xFF0B1018), // 回深
              ],
            ),
          ),
        ),

        // 2. 墨流笔触（shuimo-ui 原色）
        ListenableBuilder(
          listenable: _brushCtrl,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: InkBrushPainter(time: _brushCtrl.value * 20),
          ),
        ),

        // 3. 雾气
        ListenableBuilder(
          listenable: _mistCtrl,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: MistPainter(time: _mistCtrl.value * 30),
          ),
        ),

        // 4. 微光（正青 + 晴山）
        _buildGlow(),

        // 5. 内容
        widget.child,
      ],
    );
  }

  Widget _buildGlow() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -60, left: -40, right: -40,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.1, -0.3),
                  radius: 1.5,
                  colors: [
                    const Color(0xFF6CA8AF).withOpacity(0.06), // 正青
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40, left: -40, right: -40,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.5),
                  radius: 1.3,
                  colors: [
                    const Color(0xFFA3BBDB).withOpacity(0.04), // 晴山
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 墨流笔触 — shuimo-ui 原版五行色
// ══════════════════════════════════════════════════════════

class InkBrushPainter extends CustomPainter {
  final double time;
  InkBrushPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    // 大笔触 — 水·冬深色系
    _drawStroke(canvas, size, yRatio: 0.32, amp: 0.15, freq: 2.5, speed: 0.4,
      color: const Color(0xFF1A2847), opacity: 0.18, thickness: 0.25); // 花青

    _drawStroke(canvas, size, yRatio: 0.42, amp: 0.12, freq: 3.0, speed: 0.6,
      color: const Color(0xFF31322C), opacity: 0.14, thickness: 0.20); // 京元

    _drawStroke(canvas, size, yRatio: 0.52, amp: 0.10, freq: 2.0, speed: 0.3,
      color: const Color(0xFF45465E), opacity: 0.11, thickness: 0.18); // 青黛

    // 细笔触 — 水·冬浅色系
    _drawStroke(canvas, size, yRatio: 0.26, amp: 0.08, freq: 4.0, speed: 0.8,
      color: const Color(0xFF13393E), opacity: 0.08, thickness: 0.08); // 螺子黛

    _drawStroke(canvas, size, yRatio: 0.60, amp: 0.06, freq: 3.5, speed: 0.5,
      color: const Color(0xFF576470), opacity: 0.06, thickness: 0.06); // 育阳染

    // 飞白 — 木·春点缀（极淡）
    _drawStroke(canvas, size, yRatio: 0.35, amp: 0.05, freq: 5.0, speed: 1.0,
      color: const Color(0xFF284852), opacity: 0.04, thickness: 0.04); // 青绶
  }

  void _drawStroke(Canvas canvas, Size size, {
    required double yRatio, required double amp, required double freq,
    required double speed, required Color color,
    required double opacity, required double thickness,
  }) {
    final w = size.width;
    final h = size.height;
    final baseY = h * yRatio;
    final path = Path();
    path.moveTo(0, h);

    for (double x = 0; x <= w; x += 2) {
      final nx = x / w;
      final y = baseY +
          sin(nx * freq * pi + time * speed) * h * amp +
          sin(nx * freq * 1.7 * pi + time * speed * 0.6) * h * amp * 0.4 +
          cos(nx * freq * 2.3 * pi + time * speed * 1.2) * h * amp * 0.2;
      path.lineTo(x, y);
    }
    path.lineTo(w, h);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(opacity * 0.3),
          color.withOpacity(opacity),
          color.withOpacity(opacity * 0.6),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, baseY - h * thickness * 0.5, w, h * thickness));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ══════════════════════════════════════════════════════════
// 雾气 — 月白 + 晴山 + 石英
// ══════════════════════════════════════════════════════════

class MistPainter extends CustomPainter {
  final double time;
  MistPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    _drawCloud(canvas, size,
      cx: 0.2 + sin(time * 0.1) * 0.1, cy: 0.3 + cos(time * 0.08) * 0.05,
      r: 0.35, opacity: 0.04, color: const Color(0xFFD4E5EF)); // 月白

    _drawCloud(canvas, size,
      cx: 0.7 + cos(time * 0.07) * 0.12, cy: 0.5 + sin(time * 0.06) * 0.06,
      r: 0.4, opacity: 0.03, color: const Color(0xFFA3BBDB)); // 晴山

    _drawCloud(canvas, size,
      cx: 0.5 + sin(time * 0.09) * 0.08, cy: 0.7 + cos(time * 0.05) * 0.04,
      r: 0.3, opacity: 0.035, color: const Color(0xFFC8B6BB)); // 石英
  }

  void _drawCloud(Canvas canvas, Size size, {
    required double cx, required double cy, required double r,
    required double opacity, required Color color,
  }) {
    final center = Offset(cx * size.width, cy * size.height);
    final radius = r * size.width;
    canvas.drawCircle(center, radius, Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(opacity), color.withOpacity(opacity * 0.4), Colors.transparent],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
