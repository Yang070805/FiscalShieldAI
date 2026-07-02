import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../config/fonts.dart';

/// ═══ 液态玻璃卡片 ═══
///
/// Fragment Shader 驱动：折射 + 菲涅尔高光 + 液态扰动。
/// 所有 GlassCard 自动使用液态玻璃效果。
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;
  final bool glow;
  final Color? glowColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 16,
    this.glow = false,
    this.glowColor,
    this.onTap,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  static ui.FragmentProgram? _program;
  bool _shaderReady = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _initShader();
  }

  Future<void> _initShader() async {
    if (_program != null) {
      if (mounted) setState(() => _shaderReady = true);
      return;
    }
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
      if (mounted) setState(() => _shaderReady = true);
    } catch (e) {
      debugPrint('GlassCard shader failed: $e');
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: widget.glow
              ? [BoxShadow(
                  color: (widget.glowColor ?? AppColors.celadon).withOpacity(0.12),
                  blurRadius: 20,
                  spreadRadius: 2,
                )]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: _shaderReady
              ? _buildShaderContent()
              : _buildFallbackContent(),
        ),
      ),
    );
  }

  /// Shader 渲染的液态玻璃
  Widget _buildShaderContent() {
    return ListenableBuilder(
      listenable: _animCtrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _LiquidGlassPainter(
            program: _program!,
            time: _animCtrl.value,
            isPressed: _isPressed,
          ),
          child: _buildContentLayer(),
        );
      },
    );
  }

  /// Fallback 毛玻璃
  Widget _buildFallbackContent() {
    return Container(
      color: AppColors.glassWhite,
      child: _buildContentLayer(),
    );
  }

  /// 内容层（玻璃边缘高光 + 用户内容）
  Widget _buildContentLayer() {
    return Stack(
      children: [
        // 边缘高光
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
            ),
          ),
        ),
        // 内容
        Padding(
          padding: widget.padding,
          child: widget.child,
        ),
      ],
    );
  }
}

/// 液态玻璃 Painter — 绘制 shader 背景
class _LiquidGlassPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;
  final bool isPressed;

  _LiquidGlassPainter({
    required this.program,
    required this.time,
    required this.isPressed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    final now = time * 60.0; // 模拟秒数
    final aspect = size.width / size.height;

    // Uniforms: resolution, time, glassCenter, glassSize, mouse, mouseDown, aspect
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
  bool shouldRepaint(covariant _LiquidGlassPainter old) => true;
}

/// ═══ 风险等级卡片 ═══
class RiskCard extends StatelessWidget {
  final String title;
  final String level;
  final double confidence;
  final Color color;

  const RiskCard({
    super.key,
    required this.title,
    required this.level,
    required this.confidence,
    required this.color,
  });

  RiskCard.empty({super.key, required this.title})
      : level = '--',
        confidence = 0,
        color = AppColors.paperDim;

  @override
  Widget build(BuildContext context) {
    final hasData = level != '--';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasData ? color.withOpacity(0.08) : AppColors.glassWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasData ? color.withOpacity(0.25) : AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: hasData ? color.withOpacity(0.8) : AppColors.paperDim)),
          const SizedBox(height: 8),
          Text(
            hasData ? '${confidence.toStringAsFixed(1)}%' : '--',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: hasData ? color : AppColors.paperDim, fontFamily: AppFonts.mono),
          ),
          const SizedBox(height: 4),
          Text(level, style: TextStyle(fontSize: 12, color: hasData ? AppColors.paperMid : AppColors.paperDim), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
