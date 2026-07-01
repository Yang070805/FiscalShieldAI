import 'dart:math';
import 'package:flutter/material.dart';
import '../config/colors.dart';

/// 水墨世界 — 80% 传统水墨 + 20% 3D
/// 核心：宣纸底 + 墨流笔触 + 雾气 + 微光
class InkWorld extends StatefulWidget {
  final Widget child;
  const InkWorld({super.key, required this.child});

  @override
  State<InkWorld> createState() => _InkWorldState();
}

class _InkWorldState extends State<InkWorld> with TickerProviderStateMixin {
  late AnimationController _brushCtrl;  // 笔触流动（慢）
  late AnimationController _mistCtrl;   // 雾气飘动（很慢）

  @override
  void initState() {
    super.initState();
    // 笔触流动：20秒一轮，缓慢如溪水
    _brushCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    // 雾气飘动：30秒一轮，极慢如山间云雾
    _mistCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
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
        // 1. 宣纸底（微微泛黄的暖白，不是纯黑！）
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0B0F18), // 夜空墨
                Color(0xFF101825), // 深墨
                Color(0xFF141E2E), // 墨蓝
                Color(0xFF0D1520), // 回深
              ],
            ),
          ),
        ),

        // 2. 墨流笔触层（主体，80%）
        ListenableBuilder(
          listenable: _brushCtrl,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _InkBrushPainter(time: _brushCtrl.value * 20),
          ),
        ),

        // 3. 雾气层（飘渺感）
        ListenableBuilder(
          listenable: _mistCtrl,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _MistPainter(time: _mistCtrl.value * 30),
          ),
        ),

        // 4. 微光（20% 3D点缀 — 极淡，不抢戏）
        _buildSubtleGlow(),

        // 5. 内容
        widget.child,
      ],
    );
  }

  /// 微光 — 3D点缀，极淡
  Widget _buildSubtleGlow() {
    return IgnorePointer(
      child: Stack(
        children: [
          // 正青微光（像月光透过墨色）
          Positioned(
            top: -60, left: -40, right: -40,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.1, -0.3),
                  radius: 1.5,
                  colors: [
                    AppColors.zhengqing.withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 晴山微光（底部）
          Positioned(
            bottom: -40, left: -40, right: -40,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.5),
                  radius: 1.3,
                  colors: [
                    AppColors.qingshan.withOpacity(0.04),
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
// 墨流笔触 — 模拟毛笔在宣纸上缓慢运笔
// 不是粒子！是大面积、柔和、流动的墨迹
// ══════════════════════════════════════════════════════════

class _InkBrushPainter extends CustomPainter {
  final double time;
  _InkBrushPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    // 大笔触：横扫画面的墨流
    _drawBrushStroke(canvas, size,
      yRatio: 0.35,
      amplitude: 0.15,
      frequency: 2.5,
      speed: 0.4,
      color: AppColors.huaqing,   // 花青
      opacity: 0.15,
      thickness: size.height * 0.25,
    );

    _drawBrushStroke(canvas, size,
      yRatio: 0.45,
      amplitude: 0.12,
      frequency: 3.0,
      speed: 0.6,
      color: AppColors.jingyuan,  // 京元
      opacity: 0.12,
      thickness: size.height * 0.2,
    );

    _drawBrushStroke(canvas, size,
      yRatio: 0.55,
      amplitude: 0.1,
      frequency: 2.0,
      speed: 0.3,
      color: AppColors.qingdai,   // 青黛
      opacity: 0.10,
      thickness: size.height * 0.18,
    );

    // 细笔触：像毛笔尖端的飞白
    _drawBrushStroke(canvas, size,
      yRatio: 0.28,
      amplitude: 0.08,
      frequency: 4.0,
      speed: 0.8,
      color: AppColors.zhengqing, // 正青
      opacity: 0.06,
      thickness: size.height * 0.08,
    );

    _drawBrushStroke(canvas, size,
      yRatio: 0.62,
      amplitude: 0.06,
      frequency: 3.5,
      speed: 0.5,
      color: AppColors.yuyangran, // 育阳染
      opacity: 0.05,
      thickness: size.height * 0.06,
    );
  }

  /// 绘制一条笔触 — 大面积柔和的墨流
  void _drawBrushStroke(
    Canvas canvas, Size size, {
    required double yRatio,
    required double amplitude,
    required double frequency,
    required double speed,
    required Color color,
    required double opacity,
    required double thickness,
  }) {
    final w = size.width;
    final h = size.height;
    final baseY = h * yRatio;

    final path = Path();
    path.moveTo(0, h);

    // 用多层正弦叠加模拟毛笔运笔的自然抖动
    for (double x = 0; x <= w; x += 2) {
      final nx = x / w;
      final y = baseY +
          sin(nx * frequency * pi + time * speed) * h * amplitude +
          sin(nx * frequency * 1.7 * pi + time * speed * 0.6) * h * amplitude * 0.4 +
          cos(nx * frequency * 2.3 * pi + time * speed * 1.2) * h * amplitude * 0.2;
      path.lineTo(x, y);
    }
    path.lineTo(w, h);
    path.close();

    // 笔触有渐变（中间浓，边缘淡，像真实墨迹）
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(opacity * 0.3),
          color.withOpacity(opacity),
          color.withOpacity(opacity * 0.6),
          color.withOpacity(0),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, baseY - thickness * 0.5, w, thickness));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ══════════════════════════════════════════════════════════
// 雾气 — 山间云雾，飘渺感
// ══════════════════════════════════════════════════════════

class _MistPainter extends CustomPainter {
  final double time;
  _MistPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 多团雾气缓缓飘动
    _drawMistCloud(canvas, size,
      cx: 0.2 + sin(time * 0.1) * 0.1,
      cy: 0.3 + cos(time * 0.08) * 0.05,
      radius: 0.35,
      opacity: 0.04,
      color: AppColors.yuebai,
    );

    _drawMistCloud(canvas, size,
      cx: 0.7 + cos(time * 0.07) * 0.12,
      cy: 0.5 + sin(time * 0.06) * 0.06,
      radius: 0.4,
      opacity: 0.03,
      color: AppColors.qingshan,
    );

    _drawMistCloud(canvas, size,
      cx: 0.5 + sin(time * 0.09) * 0.08,
      cy: 0.7 + cos(time * 0.05) * 0.04,
      radius: 0.3,
      opacity: 0.035,
      color: AppColors.zhengqing,
    );
  }

  void _drawMistCloud(Canvas canvas, Size size, {
    required double cx, required double cy,
    required double radius, required double opacity,
    required Color color,
  }) {
    final center = Offset(cx * size.width, cy * size.height);
    final r = radius * size.width;

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(opacity * 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
