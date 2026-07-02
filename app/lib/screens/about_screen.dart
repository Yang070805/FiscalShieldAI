import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/ink_world.dart';

/// 关于页
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWorld(
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              // 顶栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_rounded, color: AppColors.paper),
                  ),
                  const SizedBox(width: 12),
                  Text('关于', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      // Logo + 名称
                      _buildLogoSection(),
                      const SizedBox(height: 32),
                      // 项目简介
                      _buildSection('项目简介', [
                        _textItem('FiscalShield AI（财智哨兵）是一款地方财政风险智能预警系统，基于「本地模型 + 大语言模型」双引擎架构，为政府、企业和公众提供财政风险分析与决策支持。'),
                      ]),
                      const SizedBox(height: 16),
                      // 比赛信息
                      _buildSection('比赛信息', [
                        _kvItem('赛事', '中国高校计算机大赛 · AIGC创新赛'),
                        _kvItem('团队', '泥很航事堆布队'),
                        _kvItem('成员', '杨文宇（队长/南开）、金紫茹（南京审计）、周泠亦（北航）、伍奕行（四川农业）'),
                      ]),
                      const SizedBox(height: 16),
                      // 技术架构
                      _buildSection('技术架构', [
                        _kvItem('前端', 'Flutter · 水墨·璃主题 · GLSL Shader'),
                        _kvItem('本地模型', 'ST-GNN 教师 → LightTCN 学生（8,293 参数）'),
                        _kvItem('大语言模型', 'vivo 蓝心（默认） · 支持多模型切换'),
                        _kvItem('后端', 'Python · FastAPI · OpenAI 兼容接口'),
                      ]),
                      const SizedBox(height: 16),
                      // 核心特性
                      _buildSection('核心特性', [
                        _featureItem(Icons.psychology_rounded, '双引擎架构', '本地模型保底 + LLM 增强，离线可用'),
                        _featureItem(Icons.swap_horiz_rounded, '三角色差异化', '政务/企业/民用三端独立，权限隔离'),
                        _featureItem(Icons.auto_awesome_rounded, 'AI 智能分析', '风险预测 + 趋势分析 + 政策建议'),
                        _featureItem(Icons.upload_rounded, '数据上报', '政务/企业上传数据，可选择公开或内部使用'),
                      ]),
                      const SizedBox(height: 16),
                      // 开源协议
                      _buildSection('开源协议', [
                        _textItem('MIT License · 仅用于学术竞赛'),
                      ]),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.celadon.withOpacity(0.08),
            border: Border.all(color: AppColors.celadon.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: AppColors.celadon.withOpacity(0.15), blurRadius: 24, spreadRadius: 4),
            ],
          ),
          child: Image.asset('assets/images/logo_transparent.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 16),
        Text('FiscalShield AI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.paper, letterSpacing: 2, decoration: TextDecoration.none)),
        const SizedBox(height: 4),
        Text('财智哨兵 · 地方财政风险智能预警系统', style: TextStyle(fontSize: 13, color: AppColors.paperMid)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.celadon.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('v1.0.0', style: TextStyle(fontSize: 12, color: AppColors.celadon, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }

  Widget _textItem(String text) {
    return Text(text, style: TextStyle(fontSize: 13, color: AppColors.paperMid, height: 1.6));
  }

  Widget _kvItem(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(key, style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: AppColors.paperMid))),
        ],
      ),
    );
  }

  Widget _featureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.celadon.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.celadon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
