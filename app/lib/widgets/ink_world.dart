import 'dart:math';
import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../config/theme_schemes.dart';
import '../config/theme_schemes.dart';  // themeNotifier

/// 水墨世界 — 80% 传统水墨 + 20% 3D
/// 配色：shuimo-ui 原版五行色
class InkWorld extends StatefulWidget {
  final Widget child;
  final bool static; // true 时停止动画（撕开时用）
  const InkWorld({super.key, required this.child, this.static = false});

  /// 墨底层（跟随主题配色）
  static Widget inkBase() {
    return Builder(
      builder: (context) {
        final s = schemeMap[themeNotifier.type]!;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [s.bgDeep, s.bgMid, s.bgLight, s.bgMid, s.bgDeep],
            ),
          ),
        );
      },
    );
  }

  /// 笔触层（墨流线条，需要 AnimationController）
  static Widget inkBrush(AnimationController ctrl) {
    return _InkBrushWidget(ctrl: ctrl);
  }

  /// 雾气层（需要 AnimationController）
  static Widget inkMist(AnimationController ctrl) {
    return _InkMistWidget(ctrl: ctrl);
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
        // 1. 墨底（跟随主题）
        Builder(
          builder: (context) {
            final s = schemeMap[themeNotifier.type]!;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [s.bgDeep, s.bgMid, s.bgLight, s.bgMid, s.bgDeep],
                ),
              ),
            );
          },
        ),

        // 2. 墨流笔触（shuimo-ui 原色）
        _InkBrushWidget(ctrl: _brushCtrl),

        // 3. 雾气
        _InkMistWidget(ctrl: _mistCtrl),

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
                    const Color(0xFF6CA8AF).withOpacity(0.12), // 正青
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
                    const Color(0xFFA3BBDB).withOpacity(0.10), // 晴山
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
// 累加器计时 Widget — 解决循环卡帧
// ══════════════════════════════════════════════════════════

class _InkBrushWidget extends StatefulWidget {
  final AnimationController ctrl;
  const _InkBrushWidget({required this.ctrl});
  @override
  State<_InkBrushWidget> createState() => _InkBrushWidgetState();
}

class _InkBrushWidgetState extends State<_InkBrushWidget> {
  double _time = 0;
  double _lastValue = 0;

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant _InkBrushWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ctrl != widget.ctrl) {
      oldWidget.ctrl.removeListener(_onTick);
      widget.ctrl.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    final v = widget.ctrl.value;
    // 检测循环跳变：如果 value 变小了，说明控制器重新开始了
    if (v < _lastValue - 0.5) {
      // 跳变时不清零，保持 time 连续
      // 用当前 value 替代跳变，平滑过渡
      _time += (1.0 - _lastValue) + v;
    } else {
      _time += (v - _lastValue).abs();
    }
    _lastValue = v;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: InkBrushPainter(time: _time),
    );
  }
}

class _InkMistWidget extends StatefulWidget {
  final AnimationController ctrl;
  const _InkMistWidget({required this.ctrl});
  @override
  State<_InkMistWidget> createState() => _InkMistWidgetState();
}

class _InkMistWidgetState extends State<_InkMistWidget> {
  double _time = 0;
  double _lastValue = 0;

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant _InkMistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ctrl != widget.ctrl) {
      oldWidget.ctrl.removeListener(_onTick);
      widget.ctrl.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    final v = widget.ctrl.value;
    if (v < _lastValue - 0.5) {
      _time += (1.0 - _lastValue) + v;
    } else {
      _time += (v - _lastValue).abs();
    }
    _lastValue = v;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: MistPainter(time: _time),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 墨流笔触 — 发光水墨
// ══════════════════════════════════════════════════════════

class InkBrushPainter extends CustomPainter {
  final double time;
  InkBrushPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    // ═══ 发光水墨笔触（跟随主题）═══
    final s = schemeMap[themeNotifier.type]!;
    final p = s.primary;    // 主色
    final a = s.accent;     // 辅色
    final t = s.textPrimary; // 文字主色

    // 粗 — 主色（上部）
    _drawStroke(canvas, size, yRatio: 0.12, amp: 0.15, freq: 2.5, speed: 3.0,
      color: p, opacity: 0.35, thickness: 0.28, glow: 8.0);

    // 细 — 文字主色（中上）密度×1.15
    _drawStroke(canvas, size, yRatio: 0.25, amp: 0.069, freq: 5.0, speed: 6.0,
      color: t, opacity: 0.20, thickness: 0.06, glow: 3.0);

    // 中 — 辅色（中部偏上）密度×1.1
    _drawStroke(canvas, size, yRatio: 0.36, amp: 0.11, freq: 3.0, speed: 4.1,
      color: a, opacity: 0.28, thickness: 0.16, glow: 6.0);

    // 粗 — 紫苑固定（中部）
    _drawStroke(canvas, size, yRatio: 0.48, amp: 0.12, freq: 2.2, speed: 2.4,
      color: const Color(0xFF757CBB), opacity: 0.25, thickness: 0.22, glow: 5.0);

    // 细 — 石英固定（中下）密度×1.15
    _drawStroke(canvas, size, yRatio: 0.58, amp: 0.058, freq: 6.0, speed: 6.8,
      color: const Color(0xFFC8B6BB), opacity: 0.15, thickness: 0.05, glow: 2.5);

    // 中 — 主色副线（下部）密度×1.1
    _drawStroke(canvas, size, yRatio: 0.70, amp: 0.088, freq: 3.8, speed: 4.8,
      color: p, opacity: 0.18, thickness: 0.12, glow: 4.0);

    // 粗 — 辅色副线（底部）
    _drawStroke(canvas, size, yRatio: 0.83, amp: 0.11, freq: 2.8, speed: 3.4,
      color: const Color(0xFFA3BBDB), opacity: 0.20, thickness: 0.20, glow: 5.0);
  }

  void _drawStroke(Canvas canvas, Size size, {
    required double yRatio, required double amp, required double freq,
    required double speed, required Color color,
    required double opacity, required double thickness, double glow = 0.0,
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

    // 光晕层（blur 发光）
    if (glow > 0) {
      final glowPaint = Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(opacity * 0.5),
            color.withOpacity(opacity * 0.8),
            color.withOpacity(opacity * 0.3),
            Colors.transparent,
          ],
          stops: const [0.0, 0.25, 0.65, 1.0],
        ).createShader(Rect.fromLTWH(0, baseY - h * thickness * 0.5, w, h * thickness));
      canvas.drawPath(path, glowPaint);
    }

    // 实体笔触层
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(opacity * 0.4),
          color.withOpacity(opacity),
          color.withOpacity(opacity * 0.7),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.6, 1.0],
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
    // ═══ 发光雾气（跟随主题）═══
    final s = schemeMap[themeNotifier.type]!;

    _drawCloud(canvas, size,
      cx: 0.2 + sin(time * 0.1) * 0.1, cy: 0.2 + cos(time * 0.08) * 0.05,
      r: 0.35, opacity: 0.12, color: s.textPrimary, glow: 30.0);

    _drawCloud(canvas, size,
      cx: 0.7 + cos(time * 0.07) * 0.12, cy: 0.45 + sin(time * 0.06) * 0.06,
      r: 0.4, opacity: 0.10, color: s.accent, glow: 25.0);

    _drawCloud(canvas, size,
      cx: 0.5 + sin(time * 0.09) * 0.08, cy: 0.7 + cos(time * 0.05) * 0.04,
      r: 0.3, opacity: 0.09, color: s.primary, glow: 20.0);

    _drawCloud(canvas, size,
      cx: 0.3 + cos(time * 0.06) * 0.1, cy: 0.88 + sin(time * 0.04) * 0.03,
      r: 0.25, opacity: 0.07, color: const Color(0xFF757CBB), glow: 15.0);
  }

  void _drawCloud(Canvas canvas, Size size, {
    required double cx, required double cy, required double r,
    required double opacity, required Color color, double glow = 0.0,
  }) {
    final center = Offset(cx * size.width, cy * size.height);
    final radius = r * size.width;

    // 光晕层
    if (glow > 0) {
      canvas.drawCircle(center, radius * 1.3, Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow)
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity * 0.4), color.withOpacity(opacity * 0.15), Colors.transparent],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.3)));
    }

    // 实体雾气
    canvas.drawCircle(center, radius, Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(opacity), color.withOpacity(opacity * 0.4), Colors.transparent],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
