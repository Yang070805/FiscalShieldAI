import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/glass_widgets.dart';

/// 管理员 — 成员管理 Tab（企业版/政务版通用）
class EnterpriseAdminTab extends StatefulWidget {
  final ApiService api;
  final String role; // 'enterprise' or 'gov'
  const EnterpriseAdminTab({super.key, required this.api, required this.role});

  @override
  State<EnterpriseAdminTab> createState() => _EnterpriseAdminTabState();
}

class _EnterpriseAdminTabState extends State<EnterpriseAdminTab> {
  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic>? _enterpriseInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final members = await widget.api.getMembers();
      final info = await widget.api.getEnterpriseInfo();
      setState(() {
        _members = members;
        _enterpriseInfo = info;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _showCreateMember() {
    final phoneCtrl = TextEditingController();
    final nicknameCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    String selectedRole = 'member';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.deepBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.glassBorder),
          ),
          title: Row(children: [
            Icon(Icons.person_add_rounded, color: AppColors.celadon, size: 22),
            const SizedBox(width: 8),
            Text('创建成员', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogInput(phoneCtrl, '手机号', Icons.phone_rounded, TextInputType.phone, maxLength: 11),
                const SizedBox(height: 12),
                _dialogInput(nicknameCtrl, '昵称', Icons.person_rounded, TextInputType.text),
                const SizedBox(height: 12),
                _dialogInput(pwdCtrl, '初始密码', Icons.lock_rounded, TextInputType.visiblePassword),
                const SizedBox(height: 12),
                // 角色选择
                Row(children: [
                  Text('角色: ', style: TextStyle(fontSize: 13, color: AppColors.paperDim)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('成员', style: TextStyle(fontSize: 12)),
                    selected: selectedRole == 'member',
                    onSelected: (_) => setDialogState(() => selectedRole = 'member'),
                    selectedColor: AppColors.celadon.withOpacity(0.2),
                    labelStyle: TextStyle(color: selectedRole == 'member' ? AppColors.celadon : AppColors.paperDim),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('管理员', style: TextStyle(fontSize: 12)),
                    selected: selectedRole == 'admin',
                    onSelected: (_) => setDialogState(() => selectedRole = 'admin'),
                    selectedColor: AppColors.warmApricot.withOpacity(0.2),
                    labelStyle: TextStyle(color: selectedRole == 'admin' ? AppColors.warmApricot : AppColors.paperDim),
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: AppColors.paperDim)),
            ),
            TextButton(
              onPressed: () async {
                if (phoneCtrl.text.length != 11) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('请输入11位手机号'), backgroundColor: AppColors.riskHigh),
                  );
                  return;
                }
                if (nicknameCtrl.text.isEmpty || pwdCtrl.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('请填写完整信息（密码至少6位）'), backgroundColor: AppColors.riskHigh),
                  );
                  return;
                }
                try {
                  await widget.api.createMember(
                    phone: phoneCtrl.text.trim(),
                    nickname: nicknameCtrl.text.trim(),
                    password: pwdCtrl.text,
                    enterpriseRole: selectedRole,
                  );
                  Navigator.pop(ctx);
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('成员创建成功'), backgroundColor: AppColors.celadon),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('创建失败: $e'), backgroundColor: AppColors.riskHigh),
                    );
                  }
                }
              },
              child: Text('创建', style: TextStyle(color: AppColors.celadon, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogInput(TextEditingController c, String label, IconData icon, TextInputType type, {int? maxLength}) {
    return TextField(
      controller: c,
      keyboardType: type,
      maxLength: maxLength,
      style: TextStyle(color: AppColors.paper, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.paperDim),
        prefixIcon: Icon(icon, size: 18, color: AppColors.paperDim),
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.glassBorder)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _showDeleteConfirm(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.glassBorder),
        ),
        title: Text('确认删除', style: TextStyle(color: AppColors.paper, decoration: TextDecoration.none)),
        content: Text('确定要删除成员「${member['nickname']}」吗？\n该成员将失去企业数据访问权限。', style: TextStyle(color: AppColors.paperMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: AppColors.paperDim)),
          ),
          TextButton(
            onPressed: () async {
              try {
                await widget.api.deleteMember(member['id']);
                Navigator.pop(ctx);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('成员已删除'), backgroundColor: AppColors.celadon),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e'), backgroundColor: AppColors.riskHigh),
                  );
                }
              }
            },
            child: Text('删除', style: TextStyle(color: AppColors.riskHigh, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(children: [
            Icon(Icons.admin_panel_settings_rounded, size: 22, color: AppColors.celadon),
            const SizedBox(width: 8),
            Text(widget.role == 'gov' ? '机构管理' : '企业管理', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.paper, decoration: TextDecoration.none)),
          ]),
          const SizedBox(height: 4),
          Text('成员管理 · 权限配置', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
          const SizedBox(height: 20),

          // 企业信息卡片
          if (_enterpriseInfo != null)
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.business_rounded, size: 18, color: AppColors.sky),
                  const SizedBox(width: 8),
                  Text(widget.role == 'gov' ? '机构信息' : '企业信息', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                ]),
                const SizedBox(height: 12),
                _infoRow('企业名称', _enterpriseInfo!['name'] ?? '-'),
                _infoRow('信用代码', _enterpriseInfo!['credit_code'] ?? '-'),
                _infoRow('联系电话', _enterpriseInfo!['contact_phone'] ?? '-'),
                _infoRow('状态', _enterpriseInfo!['status'] ?? '-'),
              ]),
            ),
          const SizedBox(height: 16),

          // 成员管理
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.people_rounded, size: 18, color: AppColors.celadon),
                const SizedBox(width: 8),
                Text('成员列表', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                const Spacer(),
                Text('${_members.length}人', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _showCreateMember,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.celadon.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, size: 16, color: AppColors.celadon),
                      const SizedBox(width: 4),
                      Text('添加成员', style: TextStyle(fontSize: 12, color: AppColors.celadon)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (_loading)
                Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky))
              else if (_members.isEmpty)
                Center(child: Text('暂无成员', style: TextStyle(fontSize: 13, color: AppColors.paperDim)))
              else
                ..._members.map((m) => _memberCard(m)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.paper)),
      ]),
    );
  }

  Widget _memberCard(Map<String, dynamic> member) {
    final isAdmin = member['enterprise_role'] == 'admin';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAdmin ? AppColors.celadon.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isAdmin ? AppColors.celadon.withOpacity(0.3) : AppColors.glassBorder),
      ),
      child: Row(children: [
        // 头像
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: (isAdmin ? AppColors.celadon : AppColors.sky).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isAdmin ? Icons.star_rounded : Icons.person_rounded,
            size: 20,
            color: isAdmin ? AppColors.celadon : AppColors.sky,
          ),
        ),
        const SizedBox(width: 12),
        // 信息
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(member['nickname'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isAdmin ? AppColors.celadon : AppColors.sky).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(isAdmin ? '管理员' : '成员', style: TextStyle(fontSize: 10, color: isAdmin ? AppColors.celadon : AppColors.sky)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(member['phone'] ?? '', style: TextStyle(fontSize: 11, color: AppColors.paperDim, fontFamily: 'JetBrainsMono')),
          ],
        )),
        // 删除按钮（非管理员可删除）
        if (!isAdmin)
          GestureDetector(
            onTap: () => _showDeleteConfirm(member),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.riskHigh.withOpacity(0.6)),
            ),
          ),
      ]),
    );
  }
}
