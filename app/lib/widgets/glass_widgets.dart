import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../config/fonts.dart';
import '../config/theme.dart';

/// 毛玻璃卡片
class GlassCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding,
        decoration: AppTheme.glassCard(radius: radius, glow: glow, glowColor: glowColor ?? AppColors.celadon),
        child: child,
      ),
    );
  }
}

/// 风险等级卡片
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

  const RiskCard.empty({super.key, required this.title})
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
