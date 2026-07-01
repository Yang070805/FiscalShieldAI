import 'package:flutter/material.dart';
import 'dart:async';
import '../config/colors.dart';
import '../widgets/ink_world.dart';
import 'login_screen.dart';

/// 启动动画 — 墨滴 + 波纹 + Logo 浮出（占位版）
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _dropController;
  late AnimationController _rippleController;
  late AnimationController _logoController;
  late Animation<double> _dropY;
  late Animation<double> _dropScale;
  late Animation<double> _rippleRadius;
  late Animation<double> _rippleOpacity;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;

  @override
  void initState() {
    super.initState();

    _dropController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _rippleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _dropY = Tween<double>(begin: -80, end: 0).animate(CurvedAnimation(parent: _dropController, curve: Curves.easeIn));
    _dropScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _dropController, curve: Curves.easeOut));
    _rippleRadius = Tween<double>(begin: 0, end: 150).animate(CurvedAnimation(parent: _rippleController, curve: Curves.easeOutCubic));
    _rippleOpacity = Tween<double>(begin: 0.5, end: 0).animate(CurvedAnimation(parent: _rippleController, curve: Curves.easeOut));
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _dropController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _rippleController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _dropController.dispose();
    _rippleController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWorld(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 墨滴 + 波纹
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 波纹
                  ListenableBuilder(
                    listenable: _rippleController,
                    builder: (context, _) {
                      return Container(
                        width: _rippleRadius.value * 2,
                        height: _rippleRadius.value * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.sky.withOpacity(_rippleOpacity.value), width: 1.5),
                        ),
                      );
                    },
                  ),
                  // 墨滴
                  ListenableBuilder(
                    listenable: _dropController,
                    builder: (context, _) {
                      return Transform.translate(
                        offset: Offset(0, _dropY.value),
                        child: Transform.scale(
                          scale: _dropScale.value,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [AppColors.qingshan, AppColors.zhengqing, AppColors.tajian.withOpacity(0.8)],
                              ),
                              boxShadow: [BoxShadow(color: AppColors.qingshan.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Logo + 文字
            SlideTransition(
              position: _logoSlide,
              child: FadeTransition(
                opacity: _logoOpacity,
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.sky, AppColors.celadon],
                      ).createShader(bounds),
                      child: const Text('财智哨兵', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 6)),
                    ),
                    const SizedBox(height: 8),
                    Text('FiscalShield AI', style: TextStyle(fontSize: 14, color: AppColors.paperMid, letterSpacing: 6)),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.sky.withOpacity(0.6))),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
