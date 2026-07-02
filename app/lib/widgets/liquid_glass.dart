import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../config/colors.dart';

/// 液态玻璃卡片 — Fragment Shader 驱动
///
/// 效果：
/// - 折射扭曲（SDF 法线梯度 → UV 偏移）
/// - 菲涅尔高光（边缘反射）
/// - 液态表面扰动（fbm 噪声）
/// - 动态高光点（随时间漂移）
/// - 触摸交互（按下时增强扭曲）
class LiquidGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;
  final double height;
  final bool glow;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin = EdgeInsets.zero,
    this.radius = 16,
    this.height = double.infinity,
    this.glow = false,
  });

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  ui.FragmentProgram? _program;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(() => setState(() {}))
      ..repeat();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
      setState(() {});
    } catch (e) {
      debugPrint('LiquidGlass shader load failed: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: Container(
        margin: widget.margin,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: widget.glow
              ? [BoxShadow(color: AppColors.celadon.withOpacity(0.15), blurRadius: 24, spreadRadius: 2)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Stack(
            children: [
              // Shader 背景层
              if (_program != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CardGlassPainter(
                      program: _program!,
                      isPressed: _isPressed,
                    ),
                  ),
                )
              else
                // Fallback: 简单毛玻璃
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.glassWhite,
                          AppColors.glassWhite.withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                ),

              // 边框（玻璃边缘高光）
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radius),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                ),
              ),

              // 内容
              Positioned.fill(
                child: Padding(
                  padding: widget.padding,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 卡片玻璃 Painter
class _CardGlassPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final bool isPressed;

  _CardGlassPainter({required this.program, required this.isPressed});

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final aspect = size.width / size.height;

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, now);
    shader.setFloat(3, 0.5);
    shader.setFloat(4, 0.5);
    shader.setFloat(5, 0.5);
    shader.setFloat(6, 0.5);
    shader.setFloat(7, 0.5);
    shader.setFloat(8, 0.5);
    shader.setFloat(9, isPressed ? 1.0 : 0.0);
    shader.setFloat(10, aspect);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
    shader.dispose();
  }

  @override
  bool shouldRepaint(covariant _CardGlassPainter old) => true;
}
