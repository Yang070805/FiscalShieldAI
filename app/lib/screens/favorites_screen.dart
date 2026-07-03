import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/glass_widgets.dart';

/// 收藏列表页 — 展示用户收藏的城市
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    try {
      final result = await _api.getFavorites();
      setState(() => _favorites = result);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _removeFavorite(String city) async {
    try {
      await _api.removeFavorite(city);
      setState(() => _favorites.removeWhere((f) => f['city'] == city));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已取消收藏 $city'), duration: Duration(seconds: 1)),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_rounded, color: AppColors.paper),
                ),
                const SizedBox(width: 12),
                Text('我的收藏', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                const Spacer(),
                Text('${_favorites.length} 个城市', style: TextStyle(fontSize: 13, color: AppColors.paperDim)),
              ]),
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky))
                  : _favorites.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _loadFavorites,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _favorites.length,
                            itemBuilder: (context, index) {
                              final fav = _favorites[index];
                              return _buildFavoriteCard(fav);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.celadon.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.favorite_border_rounded, size: 36, color: AppColors.celadon.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text('暂无收藏', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
          const SizedBox(height: 8),
          Text('在仪表盘中点击心形图标收藏城市', style: TextStyle(fontSize: 13, color: AppColors.paperDim)),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> fav) {
    final city = fav['city'] ?? '';
    final count = fav['count'] ?? 0;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.riskHigh.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.favorite_rounded, size: 20, color: AppColors.riskHigh),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(city, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
              Text('被 $count 人关注', style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _removeFavorite(city),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.riskHigh.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.favorite_rounded, size: 18, color: AppColors.riskHigh),
          ),
        ),
      ]),
    );
  }
}
