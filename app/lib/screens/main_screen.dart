import 'package:flutter/material.dart';
import '../config/colors.dart';

import '../widgets/ink_world.dart';
import '../widgets/glass_widgets.dart';
import 'dashboard_tab.dart';
import 'profile_tab.dart';
import 'settings_screen.dart';
import 'favorites_screen.dart';
import '../services/api_service.dart';

/// 主框架 — 底部导航 + 角色适配
/// 角色 code: gov / enterprise / citizen
class MainScreen extends StatefulWidget {
  final String role;
  final bool isGuest;
  const MainScreen({super.key, required this.role, this.isGuest = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late String _currentRole;
  final ApiService _api = ApiService();

  // 角色 code → 中文名
  static const Map<String, String> _roleNames = {
    'gov': '政务版',
    'enterprise': '企业版',
    'citizen': '民用版',
  };

  String get _roleName => _roleNames[_currentRole] ?? '民用版';

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role;
  }

  void switchRole(String newRole) {
    setState(() => _currentRole = newRole);
  }

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
                '$_roleName${widget.isGuest ? " · 游客模式" : ""}',
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
        return DashboardTab(role: _currentRole, isGuest: widget.isGuest);
      case 1:
        // 政务版/企业版中间tab显示功能页，民用版显示搜索
        if (_currentRole == 'citizen') return _buildCivilianSearch();
        return _buildFeatureTab();
      case 2:
        return ProfileTab(role: _currentRole, isGuest: widget.isGuest, onRoleSwitch: switchRole);
      default:
        return DashboardTab(role: _currentRole, isGuest: widget.isGuest);
    }
  }

  Widget _buildFeatureTab() {
    final isGov = _currentRole == 'gov';
    if (isGov) return _buildGovMonitorTab();
    return _buildEnterpriseAnalysisTab();
  }

  /// 政务版 — 风险监控 tab（接入后端）
  Widget _buildGovMonitorTab() {
    return _GovMonitorTab(api: _api);
  }

  /// 企业版 — 智能分析 tab
  Widget _buildEnterpriseAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('智能分析', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text('数据对标 · 趋势预测', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
          const SizedBox(height: 20),
          _monitorCard(Icons.show_chart_rounded, 'GDP趋势分析', '苏州近5年GDP稳步增长', '已完成', AppColors.celadon),
          _monitorCard(Icons.compare_arrows_rounded, '城市对标', '南京 vs 苏州 财政健康度对比', '已完成', AppColors.sky),
          _monitorCard(Icons.assessment_rounded, '综合风险评估', '无锡综合风险评级为低', '已完成', AppColors.riskLow),
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
    return _CivilianSearchTab(api: _api);
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
    if (_currentRole == 'gov') {
      items.insert(1, {'icon': Icons.shield_rounded, 'label': '监控'});
    }
    // 企业版专属：分析入口
    if (_currentRole == 'enterprise') {
      items.insert(1, {'icon': Icons.analytics_rounded, 'label': '分析'});
    }
    // 民用版专属：搜索入口
    if (_currentRole == 'citizen') {
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

// ══════════════════════════════════════════════════════
// 民用版搜索 Tab — 接入后端 /search + /search/favorites
// ══════════════════════════════════════════════════════

class _CivilianSearchTab extends StatefulWidget {
  final ApiService api;
  const _CivilianSearchTab({required this.api});

  @override
  State<_CivilianSearchTab> createState() => _CivilianSearchTabState();
}

class _CivilianSearchTabState extends State<_CivilianSearchTab> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _recommendCities = [];
  bool _loading = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final favs = await widget.api.getFavorites();
      final rec = await widget.api.getRecommend();
      setState(() {
        _favorites = favs;
        _recommendCities = List<String>.from(rec['hot']?.map((h) => h['city']) ?? ['南京', '苏州', '无锡']);
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _doSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await widget.api.search(q);
      setState(() => _searchResults = List<Map<String, dynamic>>.from(result['predictions'] ?? []));
    } catch (_) {}
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _doSearch,
                    style: TextStyle(color: AppColors.paper, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '搜索城市、指标...',
                      hintStyle: TextStyle(color: AppColors.paperDim),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchResults = []);
                    },
                    child: Icon(Icons.close_rounded, color: AppColors.paperDim, size: 20),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 搜索结果
          if (_searching)
            Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky))
          else if (_searchResults.isNotEmpty) ...[
            Text('搜索结果', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none)),
            const SizedBox(height: 12),
            ..._searchResults.map((p) => _searchResultCard(p)),
            const SizedBox(height: 24),
          ],
          // 收藏的城市
          if (_favorites.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.favorite_rounded, size: 16, color: AppColors.riskHigh),
              const SizedBox(width: 6),
              Text('我的收藏', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FavoritesScreen())),
                child: Text('查看全部', style: TextStyle(fontSize: 12, color: AppColors.sky)),
              ),
            ]),
            const SizedBox(height: 12),
            ..._favorites.take(5).map((f) => _favoriteCard(f)),
            const SizedBox(height: 24),
          ],
          // 推荐
          Text('推荐城市', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text('热门城市', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
          const SizedBox(height: 12),
          ..._recommendCities.map((c) => _recommendCard(c)),
        ],
      ),
    );
  }

  Widget _searchResultCard(Map<String, dynamic> p) {
    final city = p['city'] ?? '';
    final score = (p['risk_score'] as num?)?.toDouble() ?? 0;
    final level = p['risk_level'] ?? '-';
    final Color levelColor;
    switch (level) {
      case 'critical': levelColor = AppColors.riskHigh; break;
      case 'high': levelColor = AppColors.warmApricot; break;
      case 'medium': levelColor = AppColors.zhuyantuo; break;
      default: levelColor = AppColors.riskLow;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: levelColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.location_city_rounded, size: 20, color: levelColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(city, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
              Text('风险评分: ${score.toStringAsFixed(1)} · ${p['trend'] ?? '-'}', style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: levelColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
          child: Text(level, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: levelColor)),
        ),
      ]),
    );
  }

  Widget _favoriteCard(Map<String, dynamic> fav) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(children: [
        Icon(Icons.favorite_rounded, color: AppColors.riskHigh, size: 20),
        const SizedBox(width: 12),
        Text(fav['city'] ?? '', style: TextStyle(fontSize: 15, color: AppColors.paper, decoration: TextDecoration.none)),
        const Spacer(),
        if ((fav['count'] ?? 0) > 0)
          Text('${fav['count']}人关注', style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, color: AppColors.paperDim, size: 20),
      ]),
    );
  }

  Widget _recommendCard(String city) {
    return Container(
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
          Text(city, style: TextStyle(fontSize: 15, color: AppColors.paper, decoration: TextDecoration.none)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: AppColors.paperDim, size: 20),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// 政务版监控 Tab — 接入后端 /monitor
// ══════════════════════════════════════════════════════

class _GovMonitorTab extends StatefulWidget {
  final ApiService api;
  const _GovMonitorTab({required this.api});

  @override
  State<_GovMonitorTab> createState() => _GovMonitorTabState();
}

class _GovMonitorTabState extends State<_GovMonitorTab> {
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final overview = await widget.api.getMonitorOverview();
      final alerts = await widget.api.getAlerts();
      setState(() {
        _overview = overview;
        _alerts = alerts;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _triggerScan() async {
    setState(() => _scanning = true);
    try {
      await widget.api.triggerScan();
      await _loadData();
    } catch (_) {}
    setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('风险监控', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none)),
            const Spacer(),
            GestureDetector(
              onTap: _scanning ? null : _triggerScan,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.celadon.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _scanning
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.celadon))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.play_arrow_rounded, size: 16, color: AppColors.celadon),
                        const SizedBox(width: 4),
                        Text('扫描', style: TextStyle(fontSize: 13, color: AppColors.celadon)),
                      ]),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text('主动扫描异常 · 实时预警', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
          const SizedBox(height: 20),
          if (_loading)
            Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky))
          else ...[
            // 概览卡片
            _buildOverviewCard(),
            const SizedBox(height: 16),
            // 告警列表
            Text('告警列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none)),
            const SizedBox(height: 12),
            if (_alerts.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.glassWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Center(child: Text('暂无告警', style: TextStyle(fontSize: 13, color: AppColors.paperDim))),
              )
            else
              ..._alerts.map((a) => _alertCard(a)),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    final normal = _overview?['normal'] ?? 0;
    final warning = _overview?['warning'] ?? 0;
    final critical = _overview?['critical'] ?? 0;
    final total = _overview?['total_cities'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('监控概览', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
          const SizedBox(height: 12),
          Row(
            children: [
              _overviewStat('监控城市', total, AppColors.sky),
              const SizedBox(width: 8),
              _overviewStat('正常', normal, AppColors.riskLow),
              const SizedBox(width: 8),
              _overviewStat('预警', warning, AppColors.warmApricot),
              const SizedBox(width: 8),
              _overviewStat('异常', critical, AppColors.riskHigh),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color, fontFamily: 'JetBrainsMono', decoration: TextDecoration.none)),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.paperDim)),
        ]),
      ),
    );
  }

  Widget _alertCard(Map<String, dynamic> alert) {
    final level = alert['level'] ?? 'info';
    final Color color;
    final IconData icon;
    switch (level) {
      case 'critical':
        color = AppColors.riskHigh;
        icon = Icons.error_rounded;
        break;
      case 'warning':
        color = AppColors.warmApricot;
        icon = Icons.warning_rounded;
        break;
      default:
        color = AppColors.sky;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(alert['city'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(level, style: TextStyle(fontSize: 10, color: color)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(alert['message'] ?? '', style: TextStyle(fontSize: 12, color: AppColors.paperMid)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
