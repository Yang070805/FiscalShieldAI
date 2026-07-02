import 'dart:math';
import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../config/fonts.dart';
import '../widgets/ink_world.dart';
import 'login_screen.dart';

/// 启动页 — 完整水墨动画 + 手势切开跳过
///
/// 参考项目：
/// - inkbutton: 墨滴扩散（gooey 边缘）
/// - SplitImage: 锯齿撕裂裁剪
/// - RippleView: 水波纹扩散（alpha 随半径变化）
/// - ChineseIsEasy-Calligraphy: 逐笔画书写动画
/// - canvasEffect_Ink1: 触摸交互概念
/// - canvasEffect_Ink2: fbm 噪声流动纹理
///
/// 动画流程：
/// 阶段1（0~1s）：墨滴落下 → 扩散
/// 阶段2（1~2s）：墨迹铺满 → 收缩到中心
/// 阶段3（2~3s）：FiscalShield AI 浮现
/// 阶段4（3~4s）：FiscalShield AI 逐笔写出
/// 阶段5（4~5s）：整体淡出 → 进入登录页
///
/// 任意时刻横划 → 水痕 + 波纹 + 锯齿裂缝 → 上下撕开 → 进入登录
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // ═══ 三层控制器 ═══
  late AnimationController _brushCtrl; // 笔触
  late AnimationController _mistCtrl;  // 雾气

  // ═══ 阶段动画 ═══
  late AnimationController _seqCtrl; // 总序列 5 秒

  // 阶段 1: 墨滴扩散
  late Animation<double> _dropRadius;  // 0 → 1（归一化半径）
  late Animation<double> _dropEdge;    // gooey 边缘模糊度

  // 阶段 2: 墨迹收缩
  late Animation<double> _inkShrink;   // 1 → 0（铺满→收缩）

  // 阶段 3: FiscalShield AI 浮现
  late Animation<double> _enTextO;     // 透明度
  late Animation<double> _enTextS;     // 缩放

  // 阶段 4: FiscalShield AI 逐笔
  late Animation<double> _cnTextO;     // 透明度
  late Animation<double> _cnStroke;    // 笔画进度 0→1

  // 阶段 5: 淡出
  late Animation<double> _fadeOut;     // 1→0

  // ═══ 切开动画 ═══
  late AnimationController _splitCtrl;
  late Animation<double> _splitProgress;
  late Animation<double> _splitBg;       // 底层（最先开始）
  late Animation<double> _splitTop;      // 上层（稍延迟）
  late Animation<double> _splitBottom;   // 下层（稍延迟）
  late Animation<double> _splitGlow;

  // ═══ 手势 ═══
  double _dragDelta = 0;
  bool _splitting = false;
  static const double _splitThreshold = 120;

  // ═══ 墨迹轨迹 ═══
  final List<_TrailPoint> _trail = [];

  // ═══ 波纹 ═══
  final List<_Ripple> _ripples = [];
  int _lastRippleTime = 0;

  @override
  void initState() {
    super.initState();

    // ── 三层控制器 ──
    _brushCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _mistCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();

    // ── 序列控制器 ──
    _seqCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5));

    // 阶段 1: 墨滴扩散 (0.0 ~ 0.2)
    _dropRadius = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 100),
    ]).animate(CurvedAnimation(parent: _seqCtrl, curve: const Interval(0.0, 0.2)));

    _dropEdge = Tween<double>(begin: 0.6, end: 0.15).animate(
      CurvedAnimation(parent: _seqCtrl, curve: const Interval(0.0, 0.2, curve: Curves.easeOut)),
    );

    // 阶段 2: 墨迹收缩 (0.2 ~ 0.4)
    _inkShrink = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _seqCtrl, curve: const Interval(0.2, 0.4, curve: Curves.easeInOutCubic)),
    );

    // 阶段 3: FiscalShield AI 浮现 (0.3 ~ 0.5)
    _enTextO = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _seqCtrl, curve: const Interval(0.3, 0.5, curve: Curves.easeIn)),
    );
    _enTextS = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _seqCtrl, curve: const Interval(0.3, 0.5, curve: Curves.easeOutCubic)),
    );

    // 阶段 4: FiscalShield AI 逐笔 (0.5 ~ 0.8)
    _cnTextO = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _seqCtrl, curve: const Interval(0.5, 0.7, curve: Curves.easeIn)),
    );
    _cnStroke = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _seqCtrl, curve: const Interval(0.5, 0.8, curve: Curves.easeInOut)),
    );

    // 阶段 5: 淡出 (0.85 ~ 1.0)
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _seqCtrl, curve: const Interval(0.85, 1.0, curve: Curves.easeIn)),
    );

    _seqCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_splitting) {
        _navigateToLogin();
      }
    });

    // ── 切开控制器（三层）──
    _splitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500));
    _splitProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _splitCtrl, curve: Curves.easeInOut),
    );
    // 底层先开始，上下层延迟
    _splitBg = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _splitCtrl, curve: const Interval(0.0, 0.9, curve: Curves.easeInOut)),
    );
    _splitTop = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _splitCtrl, curve: const Interval(0.08, 0.95, curve: Curves.easeInOut)),
    );
    _splitBottom = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _splitCtrl, curve: const Interval(0.08, 0.95, curve: Curves.easeInOut)),
    );
    _splitGlow = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _splitCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );

    // 启动序列
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _seqCtrl.forward();
    });
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, __, ___, child) => child,
        transitionDuration: Duration.zero,
      ),
    );
  }

  // ── 手势处理 ──

  void _onDragStart(DragStartDetails d) {
    if (_splitting) return;
    _dragDelta = 0;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_splitting) return;
    _dragDelta += d.delta.dx.abs();

    final now = DateTime.now().millisecondsSinceEpoch;

    // 计算手指速度
    final speed = d.delta.distance * 60; // 近似速度（像素/秒）

    // 记录轨迹点
    _trail.add(_TrailPoint(pos: d.globalPosition, time: now, speed: speed));
    if (_trail.length > 100) _trail.removeAt(0);

    // 添加波纹
    if (now - _lastRippleTime > 80) {
      _ripples.add(_Ripple(
        center: d.globalPosition,
        startTime: now,
        color: AppColors.sky,
      ));
      _lastRippleTime = now;
      if (_ripples.length > 12) _ripples.removeAt(0);
    }
    setState(() {});
  }

  void _onDragEnd(DragEndDetails d) {
    if (_splitting) return;
    if (_dragDelta >= _splitThreshold) {
      // 划够了，触发自动撕开动画
      _triggerSplit();
    } else {
      // 没划够，回弹
      _dragDelta = 0;
      setState(() {});
    }
  }

  void _triggerSplit() {
    _seqCtrl.stop();
    setState(() => _splitting = true);
    _splitCtrl.forward().then((_) => _navigateToLogin());
  }


  @override
  void dispose() {
    _seqCtrl.dispose();
    _splitCtrl.dispose();
    _brushCtrl.dispose();
    _mistCtrl.dispose();
    super.dispose();
  }

  /// 构建三层水墨背景
  /// splitProgress == 0 时：完整显示作为背景
  /// splitProgress > 0 时：分层裁剪移开，露出登录页
  List<Widget> _buildInkLayers(Size size, double bgSp, double topSp, double botSp) {
    // 没在撕开 → 完整三层叠在一起作为背景
    if (bgSp < 0.01 && topSp < 0.01 && botSp < 0.01) {
      return [
        InkWorld.inkBase(),
        InkWorld.inkBrush(_brushCtrl),
        InkWorld.inkMist(_mistCtrl),
      ];
    }

    // 撕开中 → 三层分层裁剪移开
    return [
      // 第1层：深墨底（最先开始，最快）
      ClipPath(
        clipper: _ArcClipper(top: true, progress: bgSp),
        child: Transform.translate(
          offset: Offset(0, -bgSp * size.height),
          child: InkWorld.inkBase(),
        ),
      ),
      ClipPath(
        clipper: _ArcClipper(top: false, progress: bgSp),
        child: Transform.translate(
          offset: Offset(0, bgSp * size.height),
          child: InkWorld.inkBase(),
        ),
      ),
      // 第2层：笔触（稍延迟）
      ClipPath(
        clipper: _ArcClipper(top: true, progress: topSp),
        child: Transform.translate(
          offset: Offset(0, -topSp * size.height),
          child: InkWorld.inkBrush(_brushCtrl),
        ),
      ),
      ClipPath(
        clipper: _ArcClipper(top: false, progress: topSp),
        child: Transform.translate(
          offset: Offset(0, topSp * size.height),
          child: InkWorld.inkBrush(_brushCtrl),
        ),
      ),
      // 第3层：雾气（最慢）
      ClipPath(
        clipper: _ArcClipper(top: true, progress: botSp),
        child: Transform.translate(
          offset: Offset(0, -botSp * size.height),
          child: InkWorld.inkMist(_mistCtrl),
        ),
      ),
      ClipPath(
        clipper: _ArcClipper(top: false, progress: botSp),
        child: Transform.translate(
          offset: Offset(0, botSp * size.height),
          child: InkWorld.inkMist(_mistCtrl),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: ListenableBuilder(
        listenable: Listenable.merge([_seqCtrl, _splitCtrl]),
        builder: (context, _) {
          final sp = _splitProgress.value;
          final bgSp = _splitBg.value;   // 底层进度
          final topSp = _splitTop.value; // 上层进度
          final botSp = _splitBottom.value; // 下层进度
          final seq = _fadeOut.value; // 序列整体可见性

          return Stack(
            children: [
              // ═══ 登录页（撕开时从裂口露出）═══
              if (sp > 0.01)
                ClipPath(
                  clipper: _CrackClipper(progress: sp),
                  child: const LoginScreen(),
                ),

              // ═══ 三层水墨背景 ═══
              // 正常序列：完整显示作为背景
              // 撕开时：分层裁剪移开，露出底下的登录页
              ..._buildInkLayers(size, bgSp, topSp, botSp),

              // ═══ 手势墨痕 + 波纹 ═══
              if (_trail.isNotEmpty)
                IgnorePointer(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _InkTrailWithRipplesPainter(
                      trail: _trail,
                      ripples: _ripples,
                      now: DateTime.now().millisecondsSinceEpoch,
                    ),
                  ),
                ),

              // ═══ 正常内容（Logo + 文字）═══
              if (sp < 0.01)
                Opacity(
                  opacity: seq,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── FiscalShield AI（主名，花体，大号）──
                        FadeTransition(
                          opacity: _enTextO,
                          child: ScaleTransition(
                            scale: _enTextS,
                            child: Text(
                              'FiscalShield AI',
                              style: TextStyle(
                                fontFamily: 'GreatVibes',
                                fontSize: 42,
                                color: const Color(0xFFD4E5EF), // 月白
                                letterSpacing: 3,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ── FiscalShield AI（副名，系统黑体，小号）──
                        FadeTransition(
                          opacity: _cnTextO,
                          child: _StrokeText(
                            text: 'FiscalShield AI',
                            progress: _cnStroke.value,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFFA3BBDB), // 晴山
                              letterSpacing: 4,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 60),

                        // ── 提示 ──
                        AnimatedOpacity(
                          opacity: _seqCtrl.value > 0.5 ? 0.6 : 0.0,
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            '← 横向滑动跳过 →',
                            style: TextStyle(
                              color: AppColors.sky.withOpacity(0.5),
                              fontSize: 12,
                              letterSpacing: 3,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 墨滴扩散画笔 — inkbutton gooey 效果
//
// inkbutton 原理：SVG feTurbulence(分形噪声) + feDisplacementMap(位移映射)
// = 圆形扩散时边缘有机模糊，像墨汁
// Flutter 没有 SVG filter，用边缘随机小墨点模拟：
// - 主圆：RadialGradient，中心最深向外渐淡
// - 边缘：N 个小墨点，随机大小(2~7px)、随机偏移、随机透明度
// - 整体看起来像墨汁扩散的有机边缘
// ══════════════════════════════════════════════════════════

class _InkDropPainter extends CustomPainter {
  final double radius;   // 0~1
  final double edgeBlur; // 边缘模糊度
  final double centerX, centerY;

  _InkDropPainter({
    required this.radius,
    required this.edgeBlur,
    required this.centerX,
    required this.centerY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxR = size.shortestSide * 0.6;
    final r = maxR * radius;
    if (r < 1) return;

    // ── 主墨滴 ──
    final center = Offset(centerX, centerY);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF151D29).withOpacity(0.95 * radius),  // 獭见（最深）
          const Color(0xFF151D29).withOpacity(0.8 * radius),
          const Color(0xFF1A2847).withOpacity(0.4 * radius),  // 花青
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, paint);

    // ── 边缘墨点（gooey 模拟）──
    // inkbutton 的 gooey = feTurbulence 噪声位移
    // 我们用随机小墨点代替：大小 2~7px，散布在主圆边缘
    if (radius > 0.15) {
      final rng = Random(42);  // 固定种子，避免每帧闪烁
      final dropCount = (radius * 18).toInt();  // 墨点数随扩散增加
      for (var i = 0; i < dropCount; i++) {
        final angle = rng.nextDouble() * pi * 2;
        final dist = r * (0.65 + rng.nextDouble() * 0.45);  // 距离：主圆 65%~110%
        final dropR = 1.5 + rng.nextDouble() * 5.5 * radius;  // 大小：1.5~7px
        final opacity = (0.2 + rng.nextDouble() * 0.5) * radius;
        canvas.drawCircle(
          Offset(centerX + cos(angle) * dist, centerY + sin(angle) * dist),
          dropR,
          Paint()..color = const Color(0xFF151D29).withOpacity(opacity),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _InkDropPainter old) =>
      old.radius != radius || old.edgeBlur != edgeBlur;
}

// ══════════════════════════════════════════════════════════
// 裂缝画笔 — 弧形裂口 + 褶皱
//
// 参考 babylonjs curved line：
// - Catmull-Rom 样条曲线画弧形裂口
// - 偏移时根据方向调整坐标产生褶皱
//
// 裂口不是直线，是弧线：中间最凹，两边渐回
// 像布料被从中间拉开，边缘有自然的弧度和褶皱
// ══════════════════════════════════════════════════════════

class _SawtoothCrackPainter extends CustomPainter {
  final double progress;
  final double width, height;

  _SawtoothCrackPainter({required this.progress, required this.width, required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final crackLen = size.width * progress;
    final startX = (size.width - crackLen) / 2;
    final endX = startX + crackLen;
    if (crackLen < 10) return;

    // ── 弧形裂口（贝塞尔曲线，中间最凹）──
    // progress 越大，弧度越深（被拉开得越多）
    final sag = 8.0 + progress * 20.0; // 弧度深度

    final path = Path();
    path.moveTo(startX, cy);
    // 三段贝塞尔：左弧 → 中间最凹 → 右弧
    path.cubicTo(
      startX + crackLen * 0.2, cy + sag * 0.3,   // 左侧微微下凹
      startX + crackLen * 0.4, cy + sag,           // 向中间加深
      startX + crackLen * 0.5, cy + sag,           // 中间最凹
    );
    path.cubicTo(
      startX + crackLen * 0.6, cy + sag,           // 中间最凹
      startX + crackLen * 0.8, cy + sag * 0.3,     // 右侧渐回
      endX, cy,                                     // 回到中线
    );

    // 裂缝线 — 墨色 + 正青高光
    final crackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 + progress * 1.5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF151D29).withOpacity(0),
          const Color(0xFF151D29).withOpacity(0.6),
          AppColors.sky.withOpacity(0.4),
          const Color(0xFF151D29).withOpacity(0.6),
          const Color(0xFF151D29).withOpacity(0),
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(startX, cy - sag - 10, crackLen, sag * 2 + 20));
    canvas.drawPath(path, crackPaint);

    // ── 褶皱线（参考 babylonjs shiftCatmull）──
    // 偏移时根据方向调整坐标产生褶皱
    // 在裂口两侧画几条短弧线，模拟布料褶皱
    if (progress > 0.2) {
      final wrinklePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round;

      final wrinkleCount = (progress * 6).toInt();
      final rng = Random(42);

      for (var i = 0; i < wrinkleCount; i++) {
        // 褶皱位置：裂口两侧
        final wx = startX + crackLen * (0.15 + rng.nextDouble() * 0.7);
        final side = rng.nextBool() ? 1.0 : -1.0; // 上侧或下侧
        final wy = cy + side * (sag * 0.3 + rng.nextDouble() * 10);
        final wLen = 15.0 + rng.nextDouble() * 25.0; // 褶皱长度
        final wDepth = 3.0 + rng.nextDouble() * 5.0; // 褶皱深度

        final wrinklePath = Path();
        wrinklePath.moveTo(wx - wLen / 2, wy);
        wrinklePath.quadraticBezierTo(
          wx, wy + side * wDepth, // 褶皱弧度
          wx + wLen / 2, wy,
        );

        wrinklePaint.color = const Color(0xFF151D29).withOpacity(
          0.15 + rng.nextDouble() * 0.15 * progress,
        );
        canvas.drawPath(wrinklePath, wrinklePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SawtoothCrackPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════
// 墨痕 + 波纹画笔 — RippleView 水波纹效果
//
// RippleView 原理：
// - 波纹队列：mCircleRadiusList 存储所有活跃波纹的半径
// - 每 600ms 添加一个新波纹
// - 每帧半径 +1
// - alpha 公式（先亮后暗）：
//   mColorDiameter = start + (end - start) / 2
//   if (r < mColorDiameter/2)
//     alpha = maxAlpha * (r - start) / (end - start)  // 渐亮
//   else
//     alpha = maxAlpha - maxAlpha * (r - start) / (end - start)  // 渐暗
// - 超出 endDiameter/2 自动移除
//
// 我们的适配：
// - 手指划过时每隔 80ms 添加波纹（原版 600ms 太慢）
// - 波纹从手指位置扩散（不是固定中心）
// - alpha 公式直接复用
// - 最多 12 个波纹（原版不限，但移动端需要性能优化）
// - 颜色：正青 #6CA8AF，stroke 样式
// ══════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════
// 裂缝边缘水墨流动 — 让撕开有“水帘”感
//
// 想象水帘被拉开：
// - 裂缝两侧有墨汁向下流淌
// - 墨滴从裂缝边缘滴落
// - 整体有流动感，不是静止的
// ══════════════════════════════════════════════════════════

class _CrackFlowPainter extends CustomPainter {
  final double progress;
  final double width, height;

  _CrackFlowPainter({required this.progress, required this.width, required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final crackLen = size.width * progress;
    final startX = (size.width - crackLen) / 2;
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    // ── 裂缝两侧的墨流线条 ──
    // 像水从裂缝边缘向下流淌
    final flowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final rng = Random(123);
    final flowCount = (progress * 12).toInt();

    for (var i = 0; i < flowCount; i++) {
      // 每条墨流从裂缝边缘开始，向下延伸
      final x = startX + rng.nextDouble() * crackLen;
      final startY = cy + (rng.nextDouble() - 0.5) * 8; // 裂缝附近
      final flowLen = 20.0 + rng.nextDouble() * 40 * progress; // 流淌长度
      final speed = 0.3 + rng.nextDouble() * 0.5; // 流淌速度
      final offset = (now * speed) % 1.0; // 0~1 循环

      // 流淌方向：上半向下流，下半向上流
      final direction = startY < cy ? 1.0 : -1.0;
      final endY = startY + flowLen * direction * offset;

      // 渐变透明度：源头最亮，末端渐淡
      final gradient = LinearGradient(
        begin: Alignment(0, startY / size.height * 2 - 1),
        end: Alignment(0, endY / size.height * 2 - 1),
        colors: [
          const Color(0xFF151D29).withOpacity(0.4 * progress),
          const Color(0xFF1A2847).withOpacity(0.2 * progress),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      );

      flowPaint.shader = gradient.createShader(
        Rect.fromPoints(Offset(x, startY), Offset(x + 1, endY)),
      );

      // 画曲线（不是直线，有流动感）
      final path = Path();
      path.moveTo(x, startY);
      path.quadraticBezierTo(
        x + sin(now * 2 + i) * 3, // 微微摆动
        startY + (endY - startY) * 0.5,
        x + sin(now * 1.5 + i) * 2,
        endY,
      );
      canvas.drawPath(path, flowPaint);
    }

    // ── 墨滴从裂缝滴落 ──
    // （用户说不要锯齿，墨滴也去掉，只保留流动线条）
  }

  @override
  bool shouldRepaint(covariant _CrackFlowPainter old) => true;
}

class _Ripple {
  final Offset center;
  final int startTime;
  final Color color;
  _Ripple({required this.center, required this.startTime, required this.color});
}

/// 轨迹点 — 记录位置、时间、速度
class _TrailPoint {
  final Offset pos;
  final int time;
  final double speed; // 手指速度
  _TrailPoint({required this.pos, required this.time, required this.speed});
}

/// 墨迹流动画笔 — 参考 canvasEffect_Ink1
/// 手指滑过的地方留下流动的墨迹
/// 速度影响粗细：快→细淡，慢→粗浓
/// 边缘模糊（MaskFilter.blur）模拟水墨晕染
class _InkTrailWithRipplesPainter extends CustomPainter {
  final List<_TrailPoint> trail;
  final List<_Ripple> ripples;
  final int now;

  _InkTrailWithRipplesPainter({
    required this.trail,
    required this.ripples,
    required this.now,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trail.length < 2) return;

    // ── 墨迹流动主线 ──
    // 用贝塞尔曲线连接各轨迹点
    // 速度影响粗细：快→细淡，慢→粗浓
    for (var i = 1; i < trail.length; i++) {
      final p0 = trail[i - 1];
      final p1 = trail[i];

      // 粗细：速度越快越细（canvasEffect_Ink1 的 addForce 距离衰减）
      final speedFactor = (1.0 - (p1.speed / 800).clamp(0.0, 0.8));
      final thickness = (2.0 + 6.0 * speedFactor).clamp(1.0, 8.0);

      // 透明度：速度越快越淡
      final opacity = (0.3 + 0.5 * speedFactor).clamp(0.1, 0.8);

      // 边缘模糊：模拟水墨晕染
      final blur = 2.0 + 4.0 * speedFactor;

      final paint = Paint()
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
        ..color = const Color(0xFF151D29).withOpacity(opacity);

      canvas.drawLine(p0.pos, p1.pos, paint);

      // 正青高光（在墨迹中心）
      if (speedFactor > 0.3) {
        final glowPaint = Paint()
          ..strokeWidth = thickness * 0.3
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 0.5)
          ..color = AppColors.sky.withOpacity(opacity * 0.4);
        canvas.drawLine(p0.pos, p1.pos, glowPaint);
      }
    }

    // ── 墨点飞溅（速度快时产生）──
    for (var i = 1; i < trail.length; i++) {
      final p = trail[i];
      if (p.speed > 400) {
        final rng = Random(p.time);
        final splashCount = ((p.speed - 400) / 100).ceil().clamp(1, 4);
        for (var j = 0; j < splashCount; j++) {
          final dx = p.pos.dx + (rng.nextDouble() - 0.5) * 20;
          final dy = p.pos.dy + (rng.nextDouble() - 0.5) * 20;
          final r = 0.5 + rng.nextDouble() * 2;
          final o = 0.2 + rng.nextDouble() * 0.3;
          canvas.drawCircle(
            Offset(dx, dy), r,
            Paint()..color = const Color(0xFF151D29).withOpacity(o),
          );
        }
      }
    }

    // ── 水波纹（RippleView 公式）──
    final maxR = 60.0;
    final rippleDuration = 1.2;
    for (final ripple in ripples) {
      final age = (now - ripple.startTime) / 1000.0;
      if (age > rippleDuration) continue;

      final r = maxR * (age / rippleDuration);
      final halfR = maxR * 0.4;
      final alpha = r < halfR
          ? (r / halfR)
          : (1.0 - (r - halfR) / (maxR - halfR));
      final clampedAlpha = alpha.clamp(0.0, 1.0) * 0.4;

      canvas.drawCircle(
        ripple.center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.sky.withOpacity(clampedAlpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InkTrailWithRipplesPainter old) => true;
}

// ══════════════════════════════════════════════════════════
// 弧形裁剪器 — 幕布被拉开的效果
//
// 上半幕布：底边是弧线（中间凹，两边回）
// 下半幕布：顶边是弧线（中间凸，两边回）
// 弧度随 progress 加深，像布料被从中间拉开
// ══════════════════════════════════════════════════════════

class _ArcClipper extends CustomClipper<Path> {
  final bool top;
  final double progress;

  _ArcClipper({required this.top, required this.progress});

  @override
  Path getClip(Size size) {
    final cy = size.height / 2;
    final sag = progress * size.height * 0.15; // 弧度深度

    final path = Path();
    if (top) {
      // 上半幕布：完整宽度，底边是弧线（中间凹）
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, cy);
      // 弧形底边：中间凹下去
      path.cubicTo(
        size.width * 0.75, cy - sag * 0.3,
        size.width * 0.6, cy - sag,
        size.width * 0.5, cy - sag,
      );
      path.cubicTo(
        size.width * 0.4, cy - sag,
        size.width * 0.25, cy - sag * 0.3,
        0, cy,
      );
      path.close();
    } else {
      // 下半幕布：完整宽度，顶边是弧线（中间凹）
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, cy);
      // 弧形顶边：中间凹下去
      path.cubicTo(
        size.width * 0.75, cy + sag * 0.3,
        size.width * 0.6, cy + sag,
        size.width * 0.5, cy + sag,
      );
      path.cubicTo(
        size.width * 0.4, cy + sag,
        size.width * 0.25, cy + sag * 0.3,
        0, cy,
      );
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _ArcClipper old) =>
      old.progress != progress || old.top != top;
}

// ══════════════════════════════════════════════════════════
// 裂口裁剪器 — 只裁剪出两条弧线之间的区域
//
// 登录页只在这个区域显示，被幕布盖住时看不到
// ══════════════════════════════════════════════════════════

class _CrackClipper extends CustomClipper<Path> {
  final double progress;

  _CrackClipper({required this.progress});

  @override
  Path getClip(Size size) {
    final cy = size.height / 2;
    final sag = progress * size.height * 0.15;

    final path = Path();
    // 上弧（上半幕布的底边）
    path.moveTo(0, cy);
    path.cubicTo(
      size.width * 0.25, cy - sag * 0.3,
      size.width * 0.4, cy - sag,
      size.width * 0.5, cy - sag,
    );
    path.cubicTo(
      size.width * 0.6, cy - sag,
      size.width * 0.75, cy - sag * 0.3,
      size.width, cy,
    );
    // 下弧（下半幕布的顶边）
    path.cubicTo(
      size.width * 0.75, cy + sag * 0.3,
      size.width * 0.6, cy + sag,
      size.width * 0.5, cy + sag,
    );
    path.cubicTo(
      size.width * 0.4, cy + sag,
      size.width * 0.25, cy + sag * 0.3,
      0, cy,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _CrackClipper old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════
// 逐笔画文字 — calligraphy 逐笔效果（简化版）
// ══════════════════════════════════════════════════════════

class _StrokeText extends StatelessWidget {
  final String text;
  final double progress; // 0~1
  final TextStyle style;

  const _StrokeText({
    required this.text,
    required this.progress,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    // 逐字显现（模拟逐笔画）
    final visibleChars = (text.length * progress).ceil();
    final displayText = text.substring(0, visibleChars.clamp(0, text.length));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(text.length, (i) {
        final visible = i < visibleChars;
        final charProgress = visible
            ? ((progress * text.length - i).clamp(0.0, 1.0))
            : 0.0;

        return AnimatedOpacity(
          opacity: visible ? charProgress : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Transform.scale(
            scale: visible ? 0.8 + 0.2 * charProgress : 0.5,
            child: Text(text[i], style: style),
          ),
        );
      }),
    );
  }
}
