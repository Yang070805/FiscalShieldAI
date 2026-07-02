import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../config/fonts.dart';
import '../widgets/ink_world.dart';
import 'dashboard_tab.dart';
import 'profile_tab.dart';
import 'settings_screen.dart';

/// 主框架 — 底部导航 + 角色适配
class MainScreen extends StatefulWidget {
  final String role;
  final bool isGuest;
  const MainScreen({super.key, required this.role, this.isGuest = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return InkWorld(
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FiscalShield AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.paper, letterSpacing: 2, decoration: TextDecoration.none)),
              Text(
                '${widget.role}${widget.isGuest ? " · 游客模式" : ""}',
                style: const TextStyle(fontSize: 12, color: AppColors.paperMid),
              ),
            ],
          ),
          const Spacer(),
          _headerBtn(Icons.settings_rounded, () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
        ],
      ),
    );
  }

  Widget _headerBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.glassWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, size: 18, color: AppColors.paperMid),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return DashboardTab(role: widget.role, isGuest: widget.isGuest);
      case 1:
        return ProfileTab(role: widget.role);
      default:
        return DashboardTab(role: widget.role, isGuest: widget.isGuest);
    }
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.deepBg.withOpacity(0.8),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navItem(0, Icons.dashboard_rounded, '仪表盘'),
          _navItem(1, Icons.person_rounded, '我的'),
        ],
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final active = _currentIndex == i;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = i),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: active ? AppColors.sky : AppColors.paperDim),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: active ? AppColors.sky : AppColors.paperDim)),
        ],
      ),
    );
  }
}
