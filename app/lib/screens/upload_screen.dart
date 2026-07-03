import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../config/colors.dart';
import '../widgets/glass_widgets.dart';
import '../services/api_service.dart';

/// 数据上报页 — 上传 Excel/CSV + 权限分级（MethodChannel 原生选文件）
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ApiService _api = ApiService();
  static const _channel = MethodChannel('com.fiscalshield/file_picker');

  String? _pickedFilePath;
  String? _pickedFileName;
  Map<String, dynamic>? _previewData;
  bool _uploading = false;
  bool _uploaded = false;
  String? _error;

  final _cityController = TextEditingController();
  int _year = 2026;
  String _permission = 'internal';

  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final result = await _api.getUploadHistory();
      setState(() => _history = result);
    } catch (_) {}
    setState(() => _loadingHistory = false);
  }

  /// 调用 Android 原生文件选择器
  Future<void> _pickFile() async {
    try {
      final uri = await _channel.invokeMethod<String>('pickFile', {'type': '*/*'});
      if (uri != null) {
        final fileName = uri.split('/').last.split('?').first;
        setState(() {
          _pickedFilePath = uri;
          _pickedFileName = fileName;
          _previewData = null;
          _error = null;
          _uploaded = false;
        });
      }
    } catch (e) {
      setState(() => _error = '文件选择失败: $e');
    }
  }

  /// 将 content:// URI 复制到本地临时目录（后端需要本地路径）
  Future<String?> _copyUriToLocal(String uriStr) async {
    try {
      final uri = Uri.parse(uriStr);
      final tempDir = await getTemporaryDirectory();
      final ext = _pickedFileName?.split('.').last ?? 'xlsx';
      final localFile = File('${tempDir.path}/upload_$ext');

      // 通过 MethodChannel 读取文件内容
      final data = await _channel.invokeMethod<Uint8List>('readFile', {'uri': uriStr});
      if (data != null) {
        await localFile.writeAsBytes(data);
        return localFile.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _uploadPreview() async {
    if (_pickedFilePath == null) return;
    setState(() { _uploading = true; _error = null; });
    try {
      final tempPath = await _copyUriToLocal(_pickedFilePath!);
      if (tempPath == null) {
        setState(() { _error = '文件读取失败'; _uploading = false; });
        return;
      }
      final result = await _api.uploadPreview(tempPath);
      if (result['success'] == true) {
        setState(() => _previewData = result['data']);
      } else {
        setState(() => _error = result['message'] ?? '预览失败');
      }
    } on ApiException catch (e) {
      if (e.code == 403) {
        setState(() => _error = '权限不足：仅政务版和企业版可上传数据');
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = '上传失败: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _confirmUpload() async {
    if (_previewData == null) return;
    final city = _cityController.text.trim();
    if (city.isEmpty) { setState(() => _error = '请输入城市名'); return; }
    setState(() { _uploading = true; _error = null; });
    try {
      final preview = _previewData!['preview'] as List? ?? [];
      final data = preview.map((e) => Map<String, dynamic>.from(e)).toList();
      final result = await _api.uploadConfirm(city: city, year: _year, permission: _permission, data: data);
      if (result['success'] == true) {
        setState(() => _uploaded = true);
        _loadHistory();
      } else {
        setState(() => _error = result['message'] ?? '入库失败');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '入库失败: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
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
                Text('数据上报', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_uploaded) ...[
                      const SizedBox(height: 40),
                      _buildSuccessView(),
                    ] else ...[
                      const SizedBox(height: 16),
                      _buildStep(1, '选择文件', _buildFilePicker()),
                      const SizedBox(height: 16),
                      if (_previewData != null) ...[
                        _buildStep(2, '数据预览', _buildPreview()),
                        const SizedBox(height: 16),
                        _buildStep(3, '确认入库', _buildConfirmForm()),
                      ],
                      if (_error != null) ...[const SizedBox(height: 12), _buildError()],
                    ],
                    const SizedBox(height: 24),
                    _buildHistorySection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int step, String title, Widget child) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 24, height: 24, decoration: BoxDecoration(color: AppColors.celadon, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text('$step', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)))),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _buildFilePicker() {
    return Column(children: [
      GestureDetector(
        onTap: _pickFile,
        child: Container(
          width: double.infinity, height: 120,
          decoration: BoxDecoration(
            color: AppColors.cardBg.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _pickedFilePath != null ? AppColors.celadon.withOpacity(0.5) : AppColors.glassBorder),
          ),
          child: _pickedFilePath != null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.description_rounded, size: 32, color: AppColors.celadon),
                  const SizedBox(height: 8),
                  Text(_pickedFileName ?? '已选择文件', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                  const SizedBox(height: 4),
                  Text('点击重新选择', style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
                ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.cloud_upload_rounded, size: 36, color: AppColors.paperDim),
                  const SizedBox(height: 8),
                  Text('点击选择 Excel / CSV 文件', style: TextStyle(fontSize: 14, color: AppColors.paperDim)),
                  const SizedBox(height: 4),
                  Text('支持 .xlsx .xls .csv', style: TextStyle(fontSize: 11, color: AppColors.paperDim.withOpacity(0.6))),
                ]),
        ),
      ),
      if (_pickedFilePath != null) ...[
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 44,
          child: ElevatedButton(
            onPressed: _uploading ? null : _uploadPreview,
            child: _uploading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('上传并预览', style: TextStyle(fontWeight: FontWeight.bold)),
          )),
      ],
    ]);
  }

  Widget _buildPreview() {
    final columns = _previewData!['columns'] as List? ?? [];
    final rows = _previewData!['preview'] as List? ?? [];
    final stats = _previewData!['stats'] as Map? ?? {};
    final missing = _previewData!['missing'] as Map? ?? {};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _infoChip('文件', _previewData!['filename'] ?? ''),
        const SizedBox(width: 8),
        _infoChip('行数', '${_previewData!['rows'] ?? 0}'),
        const SizedBox(width: 8),
        _infoChip('列数', '${_previewData!['cols'] ?? 0}'),
      ]),
      if (missing.isNotEmpty) ...[const SizedBox(height: 8),
        Text('缺失值: ${missing.entries.map((e) => '${e.key}(${e.value})').join(', ')}', style: TextStyle(fontSize: 11, color: AppColors.warmApricot))],
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: columns.map<Widget>((c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.sky.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Text('${c['name']} (${c['dtype']})', style: TextStyle(fontSize: 11, color: AppColors.sky)),
      )).toList()),
      if (stats.isNotEmpty) ...[const SizedBox(height: 12),
        Text('数值统计', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
        const SizedBox(height: 8),
        ...stats.entries.map((e) { final s = e.value as Map; return Padding(padding: const EdgeInsets.only(bottom: 4),
          child: Text('${e.key}: 均值=${s['mean']}, 范围=[${s['min']}, ${s['max']}]', style: TextStyle(fontSize: 11, color: AppColors.paperMid, fontFamily: 'JetBrainsMono'))); })],
      if (rows.isNotEmpty) ...[const SizedBox(height: 12),
        Text('数据预览（前5行）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
        const SizedBox(height: 8),
        ...rows.take(5).map((row) => Padding(padding: const EdgeInsets.only(bottom: 4),
          child: Text(row.toString(), style: TextStyle(fontSize: 10, color: AppColors.paperDim, fontFamily: 'JetBrainsMono'), maxLines: 1, overflow: TextOverflow.ellipsis)))],
    ]);
  }

  Widget _buildConfirmForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: _cityController, style: TextStyle(color: AppColors.paper, fontSize: 14),
        decoration: InputDecoration(labelText: '城市名', labelStyle: TextStyle(color: AppColors.paperDim), hintText: '如：南京',
          hintStyle: TextStyle(color: AppColors.paperDim.withOpacity(0.5)), filled: true, fillColor: AppColors.glassWhite,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.glassBorder)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
      const SizedBox(height: 12),
      Row(children: [Text('年份: ', style: TextStyle(fontSize: 14, color: AppColors.paper)), const SizedBox(width: 8),
        ...[2026, 2025, 2024, 2023].map((y) => Padding(padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(label: Text('$y', style: TextStyle(fontSize: 12)), selected: _year == y,
            onSelected: (_) => setState(() => _year = y), selectedColor: AppColors.celadon.withOpacity(0.2),
            labelStyle: TextStyle(color: _year == y ? AppColors.celadon : AppColors.paperDim))))]),
      const SizedBox(height: 12),
      Text('数据权限', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
      const SizedBox(height: 8),
      _permissionOption('public', '公开', '民用端可查看', Icons.public_rounded, AppColors.celadon),
      const SizedBox(height: 6),
      _permissionOption('internal', '内部', '仅政务/企业端可见', Icons.lock_rounded, AppColors.sky),
      const SizedBox(height: 6),
      _permissionOption('private', '训练回流', '数据进入模型训练pipeline', Icons.smart_toy_rounded, AppColors.warmApricot),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 48,
        child: ElevatedButton(onPressed: _uploading ? null : _confirmUpload,
          child: _uploading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('确认入库', style: TextStyle(fontWeight: FontWeight.bold)))),
    ]);
  }

  Widget _permissionOption(String value, String title, String desc, IconData icon, Color color) {
    final isSelected = _permission == value;
    return GestureDetector(onTap: () => setState(() => _permission = value),
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.08) : Colors.transparent, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color.withOpacity(0.5) : AppColors.glassBorder, width: isSelected ? 1.5 : 1)),
        child: Row(children: [
          Icon(icon, size: 20, color: isSelected ? color : AppColors.paperDim), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? color : AppColors.paper, decoration: TextDecoration.none)),
            Text(desc, style: TextStyle(fontSize: 11, color: AppColors.paperDim))])),
          if (isSelected) Icon(Icons.check_circle_rounded, size: 20, color: color)])));
  }

  Widget _buildSuccessView() {
    return Center(child: Column(children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.celadon.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.check_circle_rounded, size: 48, color: AppColors.celadon)),
      const SizedBox(height: 16),
      Text('上传成功！', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.celadon, decoration: TextDecoration.none)),
      const SizedBox(height: 8),
      if (_permission == 'private') Text('数据已标记为训练回流，将用于优化神经网络模型', style: TextStyle(fontSize: 13, color: AppColors.warmApricot)),
      if (_permission == 'public') Text('数据已公开，民用端可在仪表盘查看', style: TextStyle(fontSize: 13, color: AppColors.celadon)),
      if (_permission == 'internal') Text('数据已入库，仅内部可见', style: TextStyle(fontSize: 13, color: AppColors.sky)),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: () { setState(() { _pickedFilePath = null; _pickedFileName = null; _previewData = null; _uploaded = false; _error = null; }); }, child: Text('继续上传')),
      const SizedBox(height: 12),
      TextButton(onPressed: () => Navigator.pop(context), child: Text('返回仪表盘', style: TextStyle(color: AppColors.sky))),
    ]));
  }

  Widget _buildHistorySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.history_rounded, size: 18, color: AppColors.paperDim), const SizedBox(width: 8),
        Text('上传历史', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none))]),
      const SizedBox(height: 12),
      if (_loadingHistory) Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky))
      else if (_history.isEmpty) GlassCard(padding: const EdgeInsets.all(20), child: Center(child: Text('暂无上传记录', style: TextStyle(fontSize: 13, color: AppColors.paperDim))))
      else ..._history.take(10).map((h) => GlassCard(padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(Icons.description_rounded, size: 20, color: AppColors.sky), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h['filename'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
            Text('${h['city'] ?? "-"} · ${h['year'] ?? "-"}年 · ${h['rows'] ?? 0}行', style: TextStyle(fontSize: 11, color: AppColors.paperDim))])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: (h['status'] == 'confirmed' ? AppColors.celadon : AppColors.warmApricot).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(h['status'] == 'confirmed' ? '已入库' : '待确认', style: TextStyle(fontSize: 10, color: h['status'] == 'confirmed' ? AppColors.celadon : AppColors.warmApricot)))])))
    ]);
  }

  Widget _infoChip(String label, String value) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(6)),
      child: Text('$label: $value', style: TextStyle(fontSize: 11, color: AppColors.paperMid)));
  }

  Widget _buildError() {
    return Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.riskHigh.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.riskHigh.withOpacity(0.25))),
      child: Row(children: [Icon(Icons.error_outline_rounded, color: AppColors.riskHigh, size: 18), const SizedBox(width: 8),
        Expanded(child: Text(_error!, style: TextStyle(color: AppColors.riskHigh, fontSize: 13)))]));
  }
}
