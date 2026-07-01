import 'dart:math';
import 'package:flutter/material.dart';
import '../config/colors.dart';

/// 水墨 3D 世界 — 重做版，效果要明显！
class InkWorld extends StatefulWidget {
  final Widget child;

  const InkWorld({super.key, required this.child});

  @override
  State<InkWorld> createState() => _InkWorldState();
}

class _InkWorldState extends State<InkWorld> with TickerProviderStateMixin {
  late AnimationController _flowCtrl;
  late AnimationController _particleCtrl;
  late List<_InkDot> _dots;

  @override
  void initState() {
    super.initState();
    _flowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _dots = List.generate(45, (_) => _InkDot.random());
  }

  @override
  void dispose() {
    _flowCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 深墨底色
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF060A14),
                Color(0xFF0D1520),
                Color(0xFF0F1D2E),
                Color(0xFF132438),
              ],
            ),
          ),
        ),

        // 2. 水墨流动纹理（高对比度，必须看得见！）
        ListenableBuilder(
          listenable: _flowCtrl,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _FlowPainter(time: _flowCtrl.value * 12),
          ),
        ),

        // 3. 墨点粒子（大而亮）
        ListenableBuilder(
          listenable: _particleCtrl,
          builder: (_, __) {
            _updateDots();
            return CustomPaint(
              size: Size.infinite,
              painter: _DotPainter(dots: _dots),
            );
          },
        ),

        // 4. 光晕
        _buildGlow(),

        // 5. 内容
        widget.child,
      ],
    );
  }

  void _updateDots() {
    for (final d in _dots) {
      d.x += d.vx;
      d.y += d.vy;
      d.vy += 0.0003; // 微重力
      d.vx *= 0.999;
      d.vy *= 0.999;
      if (d.x < -0.1) d.x = 1.1;
      if (d.x > 1.1) d.x = -0.1;
      if (d.y > 1.15) {
        d.y = -0.05;
        d.x = Random().nextDouble();
      }
      d.life -= d.decay;
      if (d.life <= 0) {
        d.reset();
      }
    }
  }

  Widget _buildGlow() {
    return IgnorePointer(
      child: Stack(
        children: [
          // 顶部正青光晕
          Positioned(
            top: -80, left: -60, right: -60,
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.1, -0.2),
                  radius: 1.3,
                  colors: [
                    AppColors.zhengqing.withOpacity(0.15),
                    AppColors.huaqing.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 底部晴山光晕
          Positioned(
            bottom: -60, left: -60, right: -60,
            child: Container(
              height: 240,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.1, 0.4),
                  radius: 1.2,
                  colors: [
                    AppColors.qingshan.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 左侧大繎光晕
          Positioned(
            top: 150, left: -80,
            child: Container(
              width: 180, height: 350,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.centerRight,
                  radius: 1.4,
                  colors: [
                    AppColors.daran.withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 右侧紫苑光晕
          Positioned(
            top: 300, right: -60,
            child: Container(
              width: 160, height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.centerLeft,
                  radius: 1.3,
                  colors: [
                    AppColors.ziyan.withOpacity(0.05),
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

// ══════════════════════════════════════════════════
// 流动纹理（高对比度版）
// ══════════════════════════════════════════════════

class _FlowPainter extends CustomPainter {
  final double time;
  _FlowPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    // 5层流动纹理，每层用不同五行色，opacity 调高
    _drawLayer(canvas, size, 0.12, 0.3, AppColors.huaqing);    // 花青（深蓝）
    _drawLayer(canvas, size, 0.10, 0.5, AppColors.jingyuan);   // 京元（深墨）
    _drawLayer(canvas, size, 0.08, 0.7, AppColors.qingdai);    // 青黛（灰紫）
    _drawLayer(canvas, size, 0.06, 1.0, AppColors.zhengqing);  // 正青（青瓷）
    _drawLayer(canvas, size, 0.05, 0.4, AppColors.yuyangran);  // 育阳染（灰蓝）
  }

  void _drawLayer(Canvas canvas, Size size, double opacity, double speed, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final path = Path();
    final h = size.height;
    final w = size.width;
    path.moveTo(0, h);

    for (double x = 0; x <= w; x += 2) {
      final y = h * 0.38 +
          sin((x / w * 3.5) + time * speed) * h * 0.14 +
          sin((x / w * 1.8) + time * speed * 0.55) * h * 0.09 +
          cos((x / w * 5.5) + time * speed * 1.15) * h * 0.05;
      path.lineTo(x, y);
    }
    path.lineTo(w, h);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ══════════════════════════════════════════════════
// 墨点粒子（大而亮，必须看见！）
// ══════════════════════════════════════════════════

class _InkDot {
  double x, y, vx, vy, size, life, decay;
  Color color;
  double glowR;

  _InkDot({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.size, required this.life, required this.decay,
    required this.color, required this.glowR,
  });

  factory _InkDot.random() {
    final rng = Random();
    final colors = [
      AppColors.zhengqing,   // 正青
      AppColors.qingshan,    // 晴山
      AppColors.ziyan,       // 紫苑
      AppColors.yuebai,      // 月白
      AppColors.zhuyantuo,   // 朱颜酡
      AppColors.piaobi,      // 缥碧
    ];
    return _InkDot(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      vx: (rng.nextDouble() - 0.5) * 0.12,
      vy: (rng.nextDouble() - 0.5) * 0.08,
      size: 2 + rng.nextDouble() * 4,  // 更大！
      life: 1.0,
      decay: rng.nextDouble() * 0.001 + 0.0005,
      color: colors[rng.nextInt(colors.length)],
      glowR: 8 + rng.nextDouble() * 12,  // 更大光晕
    );
  }

  void reset() {
    final rng = Random();
    x = rng.nextDouble();
    y = rng.nextDouble() * 0.4;
    vx = (rng.nextDouble() - 0.5) * 0.12;
    vy = rng.nextDouble() * 0.03;
    life = 1.0;
  }
}

class _DotPainter extends CustomPainter {
  final List<_InkDot> dots;
  _DotPainter({required this.dots});

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in dots) {
      final px = d.x * size.width;
      final py = d.y * size.height;
      final alpha = d.life.clamp(0.0, 1.0);

      // 光晕（必须大而明显）
      canvas.drawCircle(
        Offset(px, py),
        d.glowR,
        Paint()
          ..color = d.color.withOpacity(alpha * 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );

      // 墨点本体
      canvas.drawCircle(
        Offset(px, py),
        d.size * alpha,
        Paint()..color = d.color.withOpacity(alpha * 0.8),
      );

      // 高光点
      if (d.size > 2.5) {
        canvas.drawCircle(
          Offset(px - d.size * 0.3, py - d.size * 0.3),
          d.size * 0.3,
          Paint()..color = AppColors.gaoyu.withOpacity(alpha * 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
