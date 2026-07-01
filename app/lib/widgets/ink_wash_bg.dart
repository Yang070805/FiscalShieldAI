import 'dart:math';
import 'package:flutter/material.dart';
import '../config/colors.dart';

/// 水墨世界背景 — 深度沉浸式
/// 参考 shuimo-ui 配色 + FireWorks 粒子物理
class InkWashBackground extends StatefulWidget {
  final Widget child;
  final bool showParticles;
  final bool showRipples;

  const InkWashBackground({
    super.key,
    required this.child,
    this.showParticles = true,
    this.showRipples = true,
  });

  @override
  State<InkWashBackground> createState() => _InkWashBackgroundState();
}

class _InkWashBackgroundState extends State<InkWashBackground> with TickerProviderStateMixin {
  late AnimationController _flowController;
  late AnimationController _particleController;
  late AnimationController _rippleController;
  late List<InkParticle> _particles;
  late List<InkRipple> _ripples;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _particleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))..repeat();
    _rippleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

    _particles = List.generate(50, (_) => InkParticle.random());
    _ripples = List.generate(3, (i) => InkRipple(delay: i * 1.3));
  }

  @override
  void dispose() {
    _flowController.dispose();
    _particleController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 深墨基底（五行水·冬）
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.5, -1),
              end: Alignment(0.5, 1),
              colors: [
                Color(0xFF0A0F18), // 极深墨
                Color(0xFF151D29), // 獭见
                Color(0xFF1A2847), // 花青
                Color(0xFF31322C), // 京元
              ],
            ),
          ),
        ),
        // 2. 水墨流动纹理
        ListenableBuilder(
          listenable: _flowController,
          builder: (context, _) {
            return CustomPaint(
              size: Size.infinite,
              painter: InkFlowPainter(time: _flowController.value * 20),
            );
          },
        ),
        // 3. 水波纹
        if (widget.showRipples)
          ListenableBuilder(
            listenable: _rippleController,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: InkRipplePainter(
                  ripples: _ripples,
                  time: _rippleController.value * 4,
                ),
              );
            },
          ),
        // 4. 漂浮墨点（带物理）
        if (widget.showParticles)
          ListenableBuilder(
            listenable: _particleController,
            builder: (context, _) {
              _updateParticles();
              return CustomPaint(
                size: Size.infinite,
                painter: InkParticlePainter(particles: _particles),
              );
            },
          ),
        // 5. 光晕层
        _buildGlowLayers(),
        // 6. 内容
        widget.child,
      ],
    );
  }

  void _updateParticles() {
    for (final p in _particles) {
      p.update();
    }
  }

  Widget _buildGlowLayers() {
    return Stack(
      children: [
        // 顶部正青光晕
        Positioned(
          top: -80,
          left: -40,
          right: -40,
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.4,
                colors: [
                  AppColors.zhengqing.withOpacity(0.08), // 正青
                  AppColors.huaqing.withOpacity(0.03),   // 花青
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 底部晴山光晕
        Positioned(
          bottom: -60,
          left: -40,
          right: -40,
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.5),
                radius: 1.3,
                colors: [
                  AppColors.qingshan.withOpacity(0.04), // 晴山
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 左侧大繎光晕（朱砂红）
        Positioned(
          top: 200,
          left: -100,
          child: Container(
            width: 200,
            height: 400,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.centerRight,
                radius: 1.5,
                colors: [
                  AppColors.daran.withOpacity(0.03), // 大繎
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 水墨流动绘制器 — 5层叠加
class InkFlowPainter extends CustomPainter {
  final double time;
  InkFlowPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    _drawLayer(canvas, size, 0.08, 0.4, const Color(0xFF1A2847)); // 花青
    _drawLayer(canvas, size, 0.06, 0.7, const Color(0xFF31322C)); // 京元
    _drawLayer(canvas, size, 0.04, 1.0, const Color(0xFF45465E)); // 青黛
    _drawLayer(canvas, size, 0.03, 1.3, const Color(0xFF6CA8AF)); // 正青
    _drawLayer(canvas, size, 0.02, 0.6, const Color(0xFF576470)); // 育阳染
  }

  void _drawLayer(Canvas canvas, Size size, double opacity, double speed, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final path = Path();
    final h = size.height;
    final w = size.width;
    path.moveTo(0, h);

    for (double x = 0; x <= w; x += 3) {
      final y = h * 0.4 +
          sin((x / w * 3) + time * speed) * h * 0.12 +
          sin((x / w * 1.8) + time * speed * 0.5) * h * 0.08 +
          cos((x / w * 5) + time * speed * 1.1) * h * 0.04;
      path.lineTo(x, y);
    }
    path.lineTo(w, h);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 水波纹绘制器
class InkRipplePainter extends CustomPainter {
  final List<InkRipple> ripples;
  final double time;

  InkRipplePainter({required this.ripples, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in ripples) {
      final progress = ((time + r.delay) % 4) / 4;
      if (progress <= 0) continue;

      final radius = progress * 200;
      final opacity = (1 - progress) * 0.12;

      canvas.drawCircle(
        Offset(size.width * r.x, size.height * r.y),
        radius,
        Paint()
          ..color = AppColors.qingshan.withOpacity(opacity) // 晴山
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // 内圈
      if (radius > 30) {
        canvas.drawCircle(
          Offset(size.width * r.x, size.height * r.y),
          radius * 0.6,
          Paint()
            ..color = AppColors.zhengqing.withOpacity(opacity * 0.5) // 正青
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 水波纹数据
class InkRipple {
  final double x, y, delay;
  InkRipple({this.x = 0.5, this.y = 0.5, this.delay = 0});
}

/// 墨点粒子 — 带物理引擎（参考 FireWorks）
class InkParticle {
  double x, y;         // 位置
  double vx, vy;       // 速度
  double ax, ay;        // 加速度
  double size;
  double life;          // 生命值 0~1
  double decay;         // 衰减速率
  Color color;
  double glowRadius;

  InkParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.ax,
    required this.ay,
    required this.size,
    required this.life,
    required this.decay,
    required this.color,
    required this.glowRadius,
  });

  factory InkParticle.random() {
    final rng = Random();
    final colors = [
      AppColors.zhengqing.withOpacity(0.7),   // 正青
      AppColors.qingshan.withOpacity(0.6),    // 晴山
      AppColors.ziyan.withOpacity(0.5),        // 紫苑
      AppColors.yuebai.withOpacity(0.2),       // 月白
      AppColors.daran.withOpacity(0.25),       // 大繎（朱砂红点缀）
      AppColors.piaobi.withOpacity(0.3),       // 缥碧（浅绿点缀）
    ];
    return InkParticle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      vx: (rng.nextDouble() - 0.5) * 0.2,
      vy: (rng.nextDouble() - 0.5) * 0.15,
      ax: 0,
      ay: 0.001, // 微弱重力
      size: rng.nextDouble() * 3 + 0.5,
      life: 1.0,
      decay: rng.nextDouble() * 0.002 + 0.001,
      color: colors[rng.nextInt(colors.length)],
      glowRadius: rng.nextDouble() * 8 + 2,
    );
  }

  void update() {
    // 物理更新
    vx += ax;
    vy += ay;
    x += vx * 0.016; // 假设 60fps
    y += vy * 0.016;

    // 边界回弹
    if (x < -0.05) x = 1.05;
    if (x > 1.05) x = -0.05;
    if (y < -0.05) y = 1.05;
    if (y > 1.05) y = -0.05;

    // 阻尼
    vx *= 0.998;
    vy *= 0.998;

    // 生命衰减
    life -= decay;
    if (life <= 0) {
      _reset();
    }
  }

  void _reset() {
    final rng = Random();
    x = rng.nextDouble();
    y = rng.nextDouble();
    vx = (rng.nextDouble() - 0.5) * 0.2;
    vy = (rng.nextDouble() - 0.5) * 0.15;
    life = 1.0;
    decay = rng.nextDouble() * 0.002 + 0.001;
  }
}

/// 墨点粒子绘制器
class InkParticlePainter extends CustomPainter {
  final List<InkParticle> particles;

  InkParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final px = p.x * size.width;
      final py = p.y * size.height;
      final alpha = p.life.clamp(0.0, 1.0);

      // 光晕
      if (p.glowRadius > 3 && alpha > 0.3) {
        canvas.drawCircle(
          Offset(px, py),
          p.glowRadius * 2,
          Paint()
            ..color = p.color.withOpacity(alpha * 0.08)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }

      // 墨点本体
      canvas.drawCircle(
        Offset(px, py),
        p.size * alpha,
        Paint()..color = p.color.withOpacity(alpha * 0.7),
      );

      // 高光点
      if (p.size > 1.8 && alpha > 0.5) {
        canvas.drawCircle(
          Offset(px - p.size * 0.3, py - p.size * 0.3),
          p.size * 0.3,
          Paint()..color = Colors.white.withOpacity(alpha * 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
