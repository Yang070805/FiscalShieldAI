import 'dart:math';
import 'package:flutter/material.dart';
import '../config/colors.dart';

/// 墨点飞溅效果 — 点击按钮时触发
/// 参考 FireWorks：粒子爆炸扩散 + HSB色彩 + 生命衰减
class InkSplash extends StatefulWidget {
  final Widget child;
  final Color splashColor;

  const InkSplash({
    super.key,
    required this.child,
    this.splashColor = AppColors.zhengqing,
  });

  @override
  State<InkSplash> createState() => _InkSplashState();
}

class _InkSplashState extends State<InkSplash> with TickerProviderStateMixin {
  final List<_SplashBurst> _bursts = [];

  void _onTapDown(TapDownDetails details) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    final burst = _SplashBurst(
      origin: details.localPosition,
      controller: controller,
      particles: _generateParticles(details.localPosition),
    );
    controller.addListener(() => setState(() {}));
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _bursts.remove(burst));
        burst.controller.dispose();
      }
    });
    setState(() => _bursts.add(burst));
    controller.forward();
  }

  List<_SplashParticle> _generateParticles(Offset origin) {
    final rng = Random();
    return List.generate(20, (_) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 40.0 + rng.nextDouble() * 120;
      // HSB 色相偏移（参考 FireWorks）
      final hueShift = (rng.nextDouble() - 0.5) * 30;
      final hsv = HSVColor.fromColor(widget.splashColor);
      final color = hsv.withHue((hsv.hue + hueShift) % 360).toColor();

      return _SplashParticle(
        x: origin.dx,
        y: origin.dy,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        size: 1.5 + rng.nextDouble() * 3,
        color: color,
        life: 1.0,
      );
    });
  }

  @override
  void dispose() {
    for (final b in _bursts) {
      b.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      child: CustomPaint(
        foregroundPainter: _SplashPainter(bursts: _bursts),
        child: widget.child,
      ),
    );
  }
}

class _SplashBurst {
  final Offset origin;
  final AnimationController controller;
  final List<_SplashParticle> particles;

  _SplashBurst({
    required this.origin,
    required this.controller,
    required this.particles,
  });
}

class _SplashParticle {
  double x, y, vx, vy, size, life;
  Color color;

  _SplashParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.life,
  });
}

class _SplashPainter extends CustomPainter {
  final List<_SplashBurst> bursts;

  _SplashPainter({required this.bursts});

  @override
  void paint(Canvas canvas, Size size) {
    for (final burst in bursts) {
      final t = burst.controller.value;
      final gravity = 98.0;
      final damping = 0.95;

      for (final p in burst.particles) {
        // 物理更新（参考 FireWorks）
        final dt = 0.016;
        p.vy += gravity * dt;
        p.vx *= damping;
        p.vy *= damping;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.life = (1 - t).clamp(0.0, 1.0);

        final alpha = p.life;
        if (alpha <= 0) continue;

        // 光晕
        canvas.drawCircle(
          Offset(p.x, p.y),
          p.size * 3,
          Paint()
            ..color = p.color.withOpacity(alpha * 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // 墨点
        canvas.drawCircle(
          Offset(p.x, p.y),
          p.size * alpha,
          Paint()..color = p.color.withOpacity(alpha * 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
