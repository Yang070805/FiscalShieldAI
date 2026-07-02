import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../config/theme_schemes.dart';
import '../widgets/ink_world.dart';

/// 头像列表
const List<Map<String, String>> avatarList = [
  {'name': 'bamboo', 'label': '翠竹', 'path': 'assets/avatars/bamboo.png'},
  {'name': 'mountain', 'label': '远山', 'path': 'assets/avatars/mountain.png'},
  {'name': 'wave', 'label': '波澜', 'path': 'assets/avatars/wave.png'},
  {'name': 'moon', 'label': '明月', 'path': 'assets/avatars/moon.png'},
  {'name': 'shield', 'label': '盾牌', 'path': 'assets/avatars/shield.png'},
  {'name': 'ink', 'label': '墨滴', 'path': 'assets/avatars/ink.png'},
  {'name': 'star', 'label': '星辰', 'path': 'assets/avatars/star.png'},
  {'name': 'lotus', 'label': '莲花', 'path': 'assets/avatars/lotus.png'},
];

/// 头像选择页
class AvatarPickerScreen extends StatelessWidget {
  const AvatarPickerScreen({super.key});

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
                  Text('选择头像', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                ]),
              ),

              // 当前头像预览
              _buildCurrentAvatar(context),
              const SizedBox(height: 20),

              // 拍照/相册按钮
              _buildActionButtons(context),
              const SizedBox(height: 20),

              // 预设头像列表
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('预设头像', style: TextStyle(fontSize: 14, color: AppColors.paperDim, decoration: TextDecoration.none)),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: avatarList.length,
                  itemBuilder: (ctx, i) => _buildAvatarItem(ctx, i),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 当前头像预览
  Widget _buildCurrentAvatar(BuildContext context) {
    final isCustom = themeNotifier.avatarName == 'custom';
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.celadon.withOpacity(0.5), width: 2),
            boxShadow: [BoxShadow(color: AppColors.celadon.withOpacity(0.2), blurRadius: 16)],
          ),
          child: ClipOval(
            child: isCustom
                ? Image.file(File(themeNotifier.avatarPath), fit: BoxFit.cover)
                : Image.asset(themeNotifier.avatarPath, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isCustom ? '自定义头像' : _getAvatarLabel(themeNotifier.avatarName),
          style: TextStyle(fontSize: 13, color: AppColors.paperMid, decoration: TextDecoration.none),
        ),
      ],
    );
  }

  /// 拍照/相册按钮
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildActionBtn(
            context, Icons.camera_alt_rounded, '拍照', () => _pickImage(context, ImageSource.camera),
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildActionBtn(
            context, Icons.photo_library_rounded, '相册', () => _pickImage(context, ImageSource.gallery),
          )),
        ],
      ),
    );
  }

  Widget _buildActionBtn(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.glassWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.celadon),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, color: AppColors.paper, decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
  }

  /// 预设头像项
  Widget _buildAvatarItem(BuildContext context, int i) {
    final avatar = avatarList[i];
    final isSelected = themeNotifier.avatarName == avatar['name'];
    return GestureDetector(
      onTap: () async {
        themeNotifier.setAvatar(avatar['name']!);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('avatar', avatar['name']!);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.celadon : AppColors.glassBorder,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.celadon.withOpacity(0.25), blurRadius: 10)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(avatar['path']!, fit: BoxFit.cover),
              if (isSelected)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: AppColors.celadon, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.black54,
                  child: Text(avatar['label']!, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.white, decoration: TextDecoration.none)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 拍照/选相册
  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (picked == null) return;

    // 保存到应用目录
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'custom_avatar${p.extension(picked.path)}';
    final savedFile = await File(picked.path).copy('${appDir.path}/$fileName');

    // 更新状态
    themeNotifier.setAvatar('custom');
    themeNotifier.setCustomAvatarPath(savedFile.path);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar', 'custom');
    await prefs.setString('customAvatarPath', savedFile.path);
  }

  String _getAvatarLabel(String name) {
    for (final a in avatarList) {
      if (a['name'] == name) return a['label']!;
    }
    return '自定义头像';
  }
}
