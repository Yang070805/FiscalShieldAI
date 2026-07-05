import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/colors.dart';
import '../widgets/glass_widgets.dart';
import '../services/api_service.dart';

/// 数据上报页 — 带完整管道的数据上传
/// 流程：选择文件 → 字段映射 → Schema验证 → 清洗 → 去重 → 时间序列预处理 → 质量评分 → 入库
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ApiService _api = ApiService();

  String? _pickedFilePath;
  String? _pickedFileName;
  Map<String, dynamic>? _validationResult;
  Map<String, dynamic>? _pipelineResult;
  bool _processing = false;
  bool _uploaded = false;
  String? _error;

  final _cityController = TextEditingController();
  int _year = 2026;
  String _permission = 'internal';
  bool _skipDedup = false;
  bool _skipTs = false;

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

  /// 调用文件选择器（使用image_picker）
  Future<void> _pickFile() async {
    try {
      final ImagePicker picker = ImagePicker();
      // 使用pickFiles选择任意文件
      final XFile? file = await picker.pickMedia();

      if (file != null) {
        // 前端预校验：检查文件扩展名
        final ext = '.${file.name.split('.').last.toLowerCase()}';
        const allowed = {'.xlsx', '.xls', '.csv'};
        if (!allowed.contains(ext)) {
          setState(() {
            _error = '不支持的文件格式: $ext\n仅支持 .xlsx、.xls、.csv 文件';
          });
          return;
        }
        setState(() {
          _pickedFilePath = file.path;
          _pickedFileName = file.name;
          _validationResult = null;
          _pipelineResult = null;
          _error = null;
          _uploaded = false;
        });
      }
    } catch (e) {
      setState(() => _error = '文件选择失败: $e');
    }
  }

  /// 仅验证文件（不入库）
  Future<void> _validateFile() async {
    if (_pickedFilePath == null) return;
    setState(() { _processing = true; _error = null; });
    try {
      final result = await _api.validateFile(_pickedFilePath!);
      if (result['success'] == true) {
        setState(() => _validationResult = result['data']);
      } else {
        setState(() => _error = result['message'] ?? '验证失败');
      }
    } on ApiException catch (e) {
      if (e.code == 403) {
        setState(() => _error = '权限不足：仅政务版和企业版可上传数据');
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = '验证失败: $e');
    } finally {
      setState(() => _processing = false);
    }
  }

  /// 带管道的完整上传
  Future<void> _uploadWithPipeline() async {
    if (_pickedFilePath == null) return;
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      setState(() => _error = '请输入城市名');
      return;
    }
    setState(() { _processing = true; _error = null; });
    try {
      final result = await _api.uploadWithPipeline(
        filePath: _pickedFilePath!,
        city: city,
        year: _year,
        permission: _permission,
        skipDedup: _skipDedup,
        skipTs: _skipTs,
      );

      if (result['success'] == true) {
        setState(() {
          _pipelineResult = result['data'];
          _uploaded = true;
        });
        _loadHistory();
      } else {
        setState(() => _error = result['message'] ?? '上传失败');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '上传失败: $e');
    } finally {
      setState(() => _processing = false);
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
            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_rounded, color: AppColors.paper),
                ),
                const SizedBox(width: 12),
                Text('数据上报', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
                const Spacer(),
                Icon(Icons.auto_awesome, size: 18, color: AppColors.celadon),
                const SizedBox(width: 4),
                Text('智能管道', style: TextStyle(fontSize: 12, color: AppColors.celadon)),
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
                      // Step 1: 选择文件
                      _buildStep(1, '选择文件', _buildFilePicker()),
                      const SizedBox(height: 16),
                      // Step 2: 配置参数
                      if (_pickedFilePath != null) ...[
                        _buildStep(2, '配置参数', _buildConfigForm()),
                        const SizedBox(height: 16),
                      ],
                      // Step 3: 验证结果
                      if (_validationResult != null) ...[
                        _buildStep(3, '数据验证', _buildValidationResult()),
                        const SizedBox(height: 16),
                      ],
                      // Step 4: 上传并处理
                      if (_pickedFilePath != null) ...[
                        _buildStep(4, '上传处理', _buildUploadButton()),
                        const SizedBox(height: 16),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _buildError(),
                      ],
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
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: AppColors.celadon, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text('$step', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))),
          ),
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
                  Text('点击选择数据文件', style: TextStyle(fontSize: 14, color: AppColors.paperDim)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.celadon.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.celadon.withOpacity(0.3)),
                    ),
                    child: Text('仅支持 .xlsx  .xls  .csv', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.celadon)),
                  ),
                ]),
        ),
      ),
      if (_pickedFilePath != null) ...[
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 44,
          child: OutlinedButton(
            onPressed: _processing ? null : _validateFile,
            child: _processing
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_outline, size: 18, color: AppColors.sky),
                    const SizedBox(width: 8),
                    Text('预验证（可选）', style: TextStyle(color: AppColors.sky, fontWeight: FontWeight.w600)),
                  ]),
          )),
      ],
    ]);
  }

  Widget _buildConfigForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 城市名
      TextField(
        controller: _cityController,
        style: TextStyle(color: AppColors.paper, fontSize: 14),
        decoration: InputDecoration(
          labelText: '城市名',
          labelStyle: TextStyle(color: AppColors.paperDim),
          hintText: '如：南京',
          hintStyle: TextStyle(color: AppColors.paperDim.withOpacity(0.5)),
          filled: true,
          fillColor: AppColors.glassWhite,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.glassBorder)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      const SizedBox(height: 12),
      // 年份选择（当前年份往前推20年，可横向滚动）
      Row(children: [
        Text('年份: ', style: TextStyle(fontSize: 14, color: AppColors.paper)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(21, (i) => DateTime.now().year - i).map((y) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$y', style: TextStyle(fontSize: 12)),
                  selected: _year == y,
                  onSelected: (_) => setState(() => _year = y),
                  selectedColor: AppColors.celadon.withOpacity(0.2),
                  labelStyle: TextStyle(color: _year == y ? AppColors.celadon : AppColors.paperDim),
                ),
              )).toList(),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      // 权限选择
      Text('数据权限', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
      const SizedBox(height: 8),
      _permissionOption('public', '公开', '民用端可查看', Icons.public_rounded, AppColors.celadon),
      const SizedBox(height: 6),
      _permissionOption('internal', '内部', '仅政务/企业端可见', Icons.lock_rounded, AppColors.sky),
      const SizedBox(height: 6),
      _permissionOption('private', '训练回流', '数据进入模型训练pipeline', Icons.smart_toy_rounded, AppColors.warmApricot),
      const SizedBox(height: 12),
      // 管道选项
      Text('管道选项', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _buildCheckbox('跳过去重', _skipDedup, (v) => setState(() => _skipDedup = v))),
        const SizedBox(width: 12),
        Expanded(child: _buildCheckbox('跳过时序预处理', _skipTs, (v) => setState(() => _skipTs = v))),
      ]),
    ]);
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(children: [
        SizedBox(width: 20, height: 20,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.celadon,
            side: BorderSide(color: AppColors.glassBorder),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.paperDim)),
      ]),
    );
  }

  Widget _buildValidationResult() {
    final isValid = _validationResult!['is_valid'] ?? false;
    final mappings = _validationResult!['field_mappings'] as Map? ?? {};
    final errors = _validationResult!['validation_errors'] as List? ?? [];
    final qualityScore = _validationResult!['quality_score'] ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 验证状态
      Row(children: [
        Icon(
          isValid ? Icons.check_circle_rounded : Icons.warning_rounded,
          size: 20,
          color: isValid ? AppColors.celadon : AppColors.warmApricot,
        ),
        const SizedBox(width: 8),
        Text(
          isValid ? '验证通过' : '验证发现问题',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isValid ? AppColors.celadon : AppColors.warmApricot, decoration: TextDecoration.none),
        ),
        const Spacer(),
        _qualityBadge(qualityScore),
      ]),

      // 字段映射
      if (mappings.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('字段映射', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: mappings.entries.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppColors.celadon.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text('${e.key} → ${e.value}', style: TextStyle(fontSize: 11, color: AppColors.celadon)),
        )).toList()),
      ],

      // 验证错误
      if (errors.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('验证问题', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warmApricot, decoration: TextDecoration.none)),
        const SizedBox(height: 6),
        ...errors.take(5).map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warmApricot),
            const SizedBox(width: 6),
            Expanded(child: Text('$e', style: TextStyle(fontSize: 11, color: AppColors.warmApricot))),
          ]),
        )),
      ],
    ]);
  }

  Widget _qualityBadge(double score) {
    Color color;
    String label;
    if (score >= 0.9) {
      color = AppColors.celadon;
      label = '优秀';
    } else if (score >= 0.7) {
      color = AppColors.sky;
      label = '良好';
    } else if (score >= 0.5) {
      color = AppColors.warmApricot;
      label = '一般';
    } else {
      color = AppColors.riskHigh;
      label = '较差';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text('${(score * 100).toInt()}% $label', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildUploadButton() {
    return Column(children: [
      SizedBox(width: double.infinity, height: 48,
        child: ElevatedButton(
          onPressed: _processing ? null : _uploadWithPipeline,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.celadon,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _processing
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  const SizedBox(width: 12),
                  Text('管道处理中...', style: TextStyle(fontWeight: FontWeight.bold)),
                ])
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.auto_awesome, size: 18),
                  const SizedBox(width: 8),
                  Text('一键上传（智能管道）', style: TextStyle(fontWeight: FontWeight.bold)),
                ]),
        )),
      const SizedBox(height: 8),
      Text('管道将自动完成：字段映射 → 验证 → 清洗 → 去重 → 质量评分 → 入库',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
    ]);
  }

  Widget _permissionOption(String value, String title, String desc, IconData icon, Color color) {
    final isSelected = _permission == value;
    return GestureDetector(
      onTap: () => setState(() => _permission = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color.withOpacity(0.5) : AppColors.glassBorder, width: isSelected ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: isSelected ? color : AppColors.paperDim),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? color : AppColors.paper, decoration: TextDecoration.none)),
            Text(desc, style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
          ])),
          if (isSelected) Icon(Icons.check_circle_rounded, size: 20, color: color),
        ]),
      ),
    );
  }

  Widget _buildSuccessView() {
    final pipelineResult = _pipelineResult?['pipeline_result'] as Map? ?? {};
    final qualityScore = pipelineResult['quality_score'] ?? 0;
    final confidence = pipelineResult['confidence_weight'] ?? 0;
    final cleanedRows = pipelineResult['cleaned_rows'] ?? 0;
    final removedRows = pipelineResult['removed_rows'] ?? 0;
    final mappings = pipelineResult['field_mappings'] as Map? ?? {};
    final trainingTriggered = _pipelineResult?['training_triggered'] ?? false;

    return Center(child: Column(children: [
      // 成功图标
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.celadon.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.check_circle_rounded, size: 48, color: AppColors.celadon),
      ),
      const SizedBox(height: 16),
      Text('上传成功！', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.celadon, decoration: TextDecoration.none)),

      // 管道处理结果
      const SizedBox(height: 24),
      GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('管道处理结果', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
          const SizedBox(height: 12),
          _resultRow('数据质量', '${(qualityScore * 100).toInt()}%', _scoreColor(qualityScore)),
          _resultRow('可信度权重', '${(confidence * 100).toInt()}%', AppColors.sky),
          _resultRow('有效行数', '$cleanedRows', AppColors.paper),
          if (removedRows > 0) _resultRow('去除重复/异常', '$removedRows', AppColors.warmApricot),

          // 字段映射
          if (mappings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('字段映射', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.paperDim, decoration: TextDecoration.none)),
            const SizedBox(height: 6),
            ...mappings.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${e.key} → ${e.value}', style: TextStyle(fontSize: 11, color: AppColors.celadon)),
            )),
          ],
        ]),
      ),

      // 训练状态
      if (trainingTriggered) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.warmApricot.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(Icons.smart_toy_rounded, size: 18, color: AppColors.warmApricot),
            const SizedBox(width: 8),
            Expanded(child: Text('数据已标记为训练回流，将用于优化神经网络模型', style: TextStyle(fontSize: 12, color: AppColors.warmApricot))),
          ]),
        ),
      ],

      const SizedBox(height: 24),
      // 操作按钮
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () {
            setState(() {
              _pickedFilePath = null;
              _pickedFileName = null;
              _validationResult = null;
              _pipelineResult = null;
              _uploaded = false;
              _error = null;
            });
          },
          child: Text('继续上传'),
        )),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text('返回仪表盘'),
        )),
      ]),
    ]));
  }

  Widget _resultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.paperDim)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.9) return AppColors.celadon;
    if (score >= 0.7) return AppColors.sky;
    if (score >= 0.5) return AppColors.warmApricot;
    return AppColors.riskHigh;
  }

  Widget _buildHistorySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.history_rounded, size: 18, color: AppColors.paperDim),
        const SizedBox(width: 8),
        Text('上传历史', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
      ]),
      const SizedBox(height: 12),
      if (_loadingHistory)
        Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky))
      else if (_history.isEmpty)
        GlassCard(padding: const EdgeInsets.all(20), child: Center(child: Text('暂无上传记录', style: TextStyle(fontSize: 13, color: AppColors.paperDim))))
      else
        ..._history.take(10).map((h) => GlassCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(Icons.description_rounded, size: 20, color: AppColors.sky),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h['filename'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.paper, decoration: TextDecoration.none)),
              Text('${h['city'] ?? "-"} · ${h['year'] ?? "-"}年 · ${h['rows'] ?? 0}行', style: TextStyle(fontSize: 11, color: AppColors.paperDim)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (h['status'] == 'confirmed' ? AppColors.celadon : AppColors.warmApricot).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(h['status'] == 'confirmed' ? '已入库' : '待确认',
                style: TextStyle(fontSize: 10, color: h['status'] == 'confirmed' ? AppColors.celadon : AppColors.warmApricot)),
            ),
          ]),
        )),
    ]);
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.riskHigh.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.riskHigh.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: AppColors.riskHigh, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_error!, style: TextStyle(color: AppColors.riskHigh, fontSize: 13))),
      ]),
    );
  }
}
