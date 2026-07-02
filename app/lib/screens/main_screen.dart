import 'package:flutter/material.dart';
import '../config/colors.dart';

import '../widgets/ink_world.dart';
import '../widgets/glass_widgets.dart';
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

  int _notifCount = 0;

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FiscalShield AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.paper, letterSpacing: 2, decoration: TextDecoration.none)),
              Text(
                '${widget.role}${widget.isGuest ? " · 游客模式" : ""}',
                style: TextStyle(fontSize: 12, color: AppColors.paperMid),
              ),
            ],
          ),
          const Spacer(),
          _headerBtnWithBadge(Icons.notifications_none_rounded, _notifCount, () {
            setState(() => _notifCount = 0);
            _showNotifications();
          }),
          const SizedBox(width: 8),
          _headerBtn(Icons.settings_rounded, () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(isGuest: widget.isGuest)));
          }),
        ],
      ),
    );
  }

  Widget _headerBtnWithBadge(IconData icon, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Icon(icon, size: 18, color: AppColors.paperMid),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: count >= 10 ? 5 : 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.riskHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.deepBg, width: 1.5),
                ),
                child: Text(
                  count >= 100 ? '99+' : '$count',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, height: 1, decoration: TextDecoration.none),
                ),
              ),
            ),
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
        // 政务版/企业版中间tab显示功能页，民用版显示搜索
        if (widget.role == '民用版') return _buildCivilianSearch();
        return _buildFeatureTab();
      case 2:
        return ProfileTab(role: widget.role, isGuest: widget.isGuest);
      default:
        return DashboardTab(role: widget.role, isGuest: widget.isGuest);
    }
  }

  Widget _buildFeatureTab() {
    final isGov = widget.role == '政务版';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isGov ? '风险监控' : '智能分析', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text(isGov ? '主动扫描异常 · 实时预警' : '数据对标 · 趋势预测', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
          const SizedBox(height: 20),
          if (isGov) ...[
            _monitorCard(Icons.warning_rounded, '赤字率异常', '南京赤字率超过3%警戒线', '高风险', AppColors.riskHigh),
            _monitorCard(Icons.trending_up_rounded, '债务率上升', '常州债务率同比增长5.2%', '中风险', AppColors.riskMedium),
            _monitorCard(Icons.check_circle_outline_rounded, '收入达标', '苏州财政收入完成年度目标', '正常', AppColors.riskLow),
          ] else ...[
            _monitorCard(Icons.show_chart_rounded, 'GDP趋势分析', '苏州近5年GDP稳步增长', '已完成', AppColors.celadon),
            _monitorCard(Icons.compare_arrows_rounded, '城市对标', '南京 vs 苏州 财政健康度对比', '已完成', AppColors.sky),
            _monitorCard(Icons.assessment_rounded, '综合风险评估', '无锡综合风险评级为低', '已完成', AppColors.riskLow),
          ],
        ],
      ),
    );
  }

  Widget _monitorCard(IconData icon, String title, String desc, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: TextStyle(fontSize: 11, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildCivilianSearch() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索框
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: AppColors.paperDim, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text('搜索城市、指标...', style: TextStyle(color: AppColors.paperDim, fontSize: 15))),
                Icon(Icons.mic_rounded, color: AppColors.paperDim, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('推荐', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text('基于您的浏览偏好', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
          const SizedBox(height: 14),
          ...['南京', '苏州', '无锡'].map((c) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.location_city_rounded, color: AppColors.celadon, size: 20),
                const SizedBox(width: 12),
                Text(c, style: TextStyle(fontSize: 15, color: AppColors.paper, decoration: TextDecoration.none)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, color: AppColors.paperDim, size: 20),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: AppColors.deepBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.notifications_none_rounded, color: AppColors.celadon, size: 22),
              const SizedBox(width: 8),
              Text('通知中心', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close_rounded, color: AppColors.paperDim)),
            ]),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _notifItem(Icons.warning_rounded, '风险预警', '南京财政赤字率超过警戒线', '10分钟前', AppColors.riskHigh),
                  _notifItem(Icons.trending_up_rounded, '预测更新', '苏州2026年GDP预测已更新', '1小时前', AppColors.celadon),
                  _notifItem(Icons.info_outline_rounded, '系统通知', '平台已升级至v1.0.1版本', '3小时前', AppColors.sky),
                  _notifItem(Icons.security_rounded, '安全提醒', '检测到新设备登录', '昨天', AppColors.riskMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifItem(IconData icon, String title, String desc, String time, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                  const Spacer(),
                  Text(time, style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
                ]),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12, color: AppColors.paperMid)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = <Map<String, dynamic>>[]
      ..add({'icon': Icons.dashboard_rounded, 'label': '仪表盘'})
      ..add({'icon': Icons.person_rounded, 'label': '我的'});

    // 政务版专属：监控入口
    if (widget.role == '政务版') {
      items.insert(1, {'icon': Icons.shield_rounded, 'label': '监控'});
    }
    // 企业版专属：分析入口
    if (widget.role == '企业版') {
      items.insert(1, {'icon': Icons.analytics_rounded, 'label': '分析'});
    }
    // 民用版专属：搜索入口
    if (widget.role == '民用版') {
      items.insert(0, {'icon': Icons.search_rounded, 'label': '搜索'});
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.deepBg.withOpacity(0.8),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(items.length, (i) {
          final item = items[i];
          final active = _currentIndex == i;
          return _navItem(i, item['icon'] as IconData, item['label'] as String);
        }),
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
