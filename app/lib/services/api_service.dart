import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// HTTP API 服务 — 对接 FastAPI 后端
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = 'http://10.184.67.48:8000'; // 真机访问电脑（手机热点）
  String? _token;
  String? _refreshToken;

  // ==================== 配置 ====================

  void configure({String? baseUrl}) {
    if (baseUrl != null) _baseUrl = baseUrl;
  }

  /// 从本地恢复 Token
  Future<void> restoreToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  /// 保存 Token
  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// 清除 Token
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  bool get isLoggedIn => _token != null;
  String? get token => _token;

  // ==================== 通用请求 ====================

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// 解析后端统一响应 {success, message, data}
  Map<String, dynamic> _parseResponse(http.Response resp) {
    if (resp.statusCode == 401) {
      throw ApiException('登录已过期，请重新登录', code: 401);
    }
    if (resp.statusCode == 403) {
      throw ApiException('权限不足', code: 403);
    }

    final body = jsonDecode(utf8.decode(resp.bodyBytes));
    if (resp.statusCode >= 400) {
      throw ApiException(body['message'] ?? '请求失败', code: resp.statusCode);
    }
    return body;
  }

  /// GET 请求
  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw ApiException('请求超时'),
    );
    return _parseResponse(resp);
  }

  /// POST 请求
  Future<Map<String, dynamic>> _post(String path, {Map<String, dynamic>? body}) async {
    final resp = await http
        .post(Uri.parse('$_baseUrl$path'), headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 15), onTimeout: () => throw ApiException('请求超时'));
    return _parseResponse(resp);
  }

  /// DELETE 请求
  Future<Map<String, dynamic>> _delete(String path) async {
    final resp = await http
        .delete(Uri.parse('$_baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 15), onTimeout: () => throw ApiException('请求超时'));
    return _parseResponse(resp);
  }

  // ==================== 认证 ====================

  /// 注册
  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String nickname,
    String role = 'citizen',
  }) async {
    final result = await _post('/api/v1/auth/register', body: {
      'phone': phone,
      'password': password,
      'nickname': nickname,
      'role': role,
    });
    if (result['success'] == true && result['data'] != null) {
      await _saveToken(result['data']['access_token']);
    }
    return result;
  }

  /// 登录
  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final result = await _post('/api/v1/auth/login', body: {
      'phone': phone,
      'password': password,
    });
    if (result['success'] == true && result['data'] != null) {
      await _saveToken(result['data']['access_token']);
    }
    return result;
  }

  /// 获取当前用户信息
  Future<Map<String, dynamic>> getMe() async {
    return await _get('/api/v1/auth/me');
  }

  /// 修改密码
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return await _post('/api/v1/auth/change-password', body: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  /// 退出登录
  Future<void> logout() async {
    await clearToken();
  }

  // ==================== 预测 ====================

  /// 获取城市列表
  Future<List<String>> getCities() async {
    final result = await _get('/api/v1/predict/cities');
    if (result['success'] == true && result['data'] != null) {
      return List<String>.from(result['data']);
    }
    return [];
  }

  /// 城市预测
  Future<Map<String, dynamic>> predict({
    required String city,
    required int year,
  }) async {
    final result = await _get('/api/v1/predict/$city', params: {'year': year.toString()});
    if (result['success'] == true) {
      return result['data'] ?? {};
    }
    throw ApiException(result['message'] ?? '预测失败');
  }

  // ==================== 报告 ====================

  /// 获取AI报告
  Future<Map<String, dynamic>> getReport({
    required String city,
    required int year,
    bool llmEnabled = false,
  }) async {
    final params = <String, String>{
      'year': year.toString(),
      'llm_enabled': llmEnabled.toString(),
    };
    final result = await _get('/api/v1/report/$city', params: params);
    if (result['success'] == true) {
      return result['data'] ?? {};
    }
    throw ApiException(result['message'] ?? '报告生成失败');
  }

  // ==================== 对话（SSE 流式）====================

  /// SSE 流式对话 — 返回 Stream<String>（逐字输出）
  Stream<ChatEvent> chatStream({
    required String message,
    int? chatId,
    String? city,
    int? year,
    String model = 'bluelm',  // 这里传的是 provider key
  }) async* {
    final uri = Uri.parse('$_baseUrl/api/v1/chat');
    final request = http.Request('POST', uri);
    // 从 SharedPreferences 读取 API Key 并放入 Header
    final prefs = await SharedPreferences.getInstance();
    // 按账号读取：手机号前缀
    final phone = prefs.getString('loginPhone') ?? '';
    final prefix = phone.isNotEmpty ? '${phone}_' : '';
    final chatProvider = prefs.getString('${prefix}chat_provider') ?? 'bluelm';
    var apiKey = prefs.getString('${prefix}llm_key_$chatProvider') ?? '';
    var appId = prefs.getString('${prefix}llm_appid_$chatProvider') ?? '';
    // fallback: 如果没有 prefix 的 key，试试无 prefix 的
    if (apiKey.isEmpty) {
      apiKey = prefs.getString('llm_key_$chatProvider') ?? '';
      appId = prefs.getString('llm_appid_$chatProvider') ?? '';
    }
    // fallback: 从后端文件读取（如果前端也没存）
    if (apiKey.isEmpty) {
      try {
        final fileResp = await http.get(Uri.parse('$_baseUrl/api/v1/llm/api-key-status'), headers: _headers);
        final fileData = jsonDecode(utf8.decode(fileResp.bodyBytes));
        if (fileData['success'] == true && fileData['data'] != null) {
          final status = fileData['data'][chatProvider];
          if (status != null && status['configured'] == true) {
            apiKey = 'from_file'; // 后端会从文件读取
          }
        }
      } catch (_) {}
    }
    request.headers.addAll({
      ..._headers,
      'Accept': 'text/event-stream',
      if (apiKey.isNotEmpty) 'X-AI-API-Key': apiKey,
      'X-AI-Model': model,
      if (appId.isNotEmpty) 'X-AI-App-ID': appId,
    });
    final actualModel = prefs.getString('${prefix}llm_model_$chatProvider') ?? 'Doubao-Seed-2.0-mini';
    request.body = jsonEncode({
      'message': message,
      if (chatId != null) 'chat_id': chatId,
      if (city != null) 'city': city,
      if (year != null) 'year': year,
      'model': actualModel,
    });

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw ApiException('对话请求超时'),
      );

      if (streamedResponse.statusCode == 401) {
        throw ApiException('登录已过期', code: 401);
      }
      if (streamedResponse.statusCode >= 400) {
        final body = await streamedResponse.stream.bytesToString();
        final parsed = jsonDecode(body);
        throw ApiException(parsed['message'] ?? '对话失败');
      }

      // 解析 SSE 事件流
      String buffer = '';
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        // SSE 格式：data: {...}\n\n
        final lines = buffer.split('\n');
        buffer = lines.removeLast(); // 保留未完成的行

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isEmpty) continue;
            try {
              final event = jsonDecode(jsonStr);
              final type = event['type'];
              if (type == 'start') {
                yield ChatEvent(type: 'start', chatId: event['chat_id']);
              } else if (type == 'chunk') {
                yield ChatEvent(type: 'chunk', content: event['content'] ?? '');
              } else if (type == 'done') {
                yield ChatEvent(type: 'done', chatId: event['chat_id']);
              } else if (type == 'error') {
                yield ChatEvent(type: 'error', content: event['message'] ?? '未知错误');
              }
            } catch (_) {}
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// 获取对话列表
  Future<List<Map<String, dynamic>>> getChatList() async {
    final result = await _get('/api/v1/chat/list');
    if (result['success'] == true && result['data'] != null) {
      return List<Map<String, dynamic>>.from(result['data']);
    }
    return [];
  }

  /// 获取对话详情
  Future<Map<String, dynamic>> getChatDetail(int chatId) async {
    final result = await _get('/api/v1/chat/$chatId');
    if (result['success'] == true) {
      return result['data'] ?? {};
    }
    throw ApiException(result['message'] ?? '获取对话失败');
  }

  /// 删除对话
  Future<void> deleteChat(int chatId) async {
    await _delete('/api/v1/chat/$chatId');
  }

  // ==================== 公开数据（民用端）====================

  /// 获取公开数据
  Future<List<Map<String, dynamic>>> getPublicData({String? city, int? year}) async {
    final params = <String, String>{};
    if (city != null) params['city'] = city;
    if (year != null) params['year'] = year.toString();
    final result = await _get('/api/v1/upload/public-data', params: params.isNotEmpty ? params : null);
    if (result['success'] == true && result['data'] != null) {
      return List<Map<String, dynamic>>.from(result['data']);
    }
    return [];
  }

  // ==================== 城市统计 ====================

  /// 获取城市统计数据
  Future<List<Map<String, dynamic>>> getCityStats() async {
    final result = await _get('/api/v1/upload/city-stats');
    if (result['success'] == true && result['data'] != null) {
      return List<Map<String, dynamic>>.from(result['data']);
    }
    return [];
  }

  // ==================== 搜索/收藏/推荐 ====================

  /// 搜索
  Future<Map<String, dynamic>> search(String query) async {
    final result = await _get('/api/v1/search', params: {'q': query});
    if (result['success'] == true) {
      return result['data'] ?? {};
    }
    throw ApiException(result['message'] ?? '搜索失败');
  }

  /// 收藏城市
  Future<void> addFavorite(String city) async {
    await _post('/api/v1/search/favorite/$city');
  }

  /// 取消收藏
  Future<void> removeFavorite(String city) async {
    await _delete('/api/v1/search/favorite/$city');
  }

  /// 收藏列表
  Future<List<Map<String, dynamic>>> getFavorites() async {
    final result = await _get('/api/v1/search/favorites');
    if (result['success'] == true && result['data'] != null) {
      return List<Map<String, dynamic>>.from(result['data']);
    }
    return [];
  }

  /// 推荐
  Future<Map<String, dynamic>> getRecommend() async {
    final result = await _get('/api/v1/search/recommend');
    if (result['success'] == true) {
      return result['data'] ?? {};
    }
    return {};
  }

  // ==================== 数据上传 ====================

  /// 带管道的数据上传（完整流程：字段映射→验证→清洗→去重→评分→入库）
  Future<Map<String, dynamic>> uploadWithPipeline({
    required String filePath,
    required String city,
    required int year,
    String permission = 'internal',
    bool skipDedup = false,
    bool skipTs = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/pipeline/upload').replace(
      queryParameters: {
        'city': city,
        'year': year.toString(),
        'permission': permission,
        if (skipDedup) 'skip_dedup': 'true',
        if (skipTs) 'skip_ts': 'true',
      },
    );

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({'Authorization': 'Bearer $_token'});
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw ApiException('管道处理超时'),
    );

    final resp = await http.Response.fromStream(streamedResponse);
    return _parseResponse(resp);
  }

  /// 仅验证文件（不入库）
  Future<Map<String, dynamic>> validateFile(String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/v1/pipeline/validate'),
    );
    request.headers.addAll({'Authorization': 'Bearer $_token'});
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw ApiException('验证超时'),
    );

    final resp = await http.Response.fromStream(streamedResponse);
    return _parseResponse(resp);
  }

  /// 获取数据契约
  Future<Map<String, dynamic>> getDataContract() async {
    final result = await _get('/api/v1/pipeline/contract');
    if (result['success'] == true) {
      return result['data'] ?? {};
    }
    return {};
  }

  /// 获取质量报告
  Future<Map<String, dynamic>> getQualityReport({String? city, int? year}) async {
    final params = <String, String>{};
    if (city != null) params['city'] = city;
    if (year != null) params['year'] = year.toString();
    final result = await _get('/api/v1/pipeline/quality-report', params: params.isNotEmpty ? params : null);
    if (result['success'] == true) {
      return result['data'] ?? {};
    }
    return {};
  }

  /// 获取上传历史
  Future<List<Map<String, dynamic>>> getUploadHistory() async {
    final result = await _get('/api/v1/upload/history');
    if (result['success'] == true && result['data'] != null) {
      return List<Map<String, dynamic>>.from(result['data']);
    }
    return [];
  }

  /// 上传文件预览（multipart）
  Future<Map<String, dynamic>> uploadPreview(String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/v1/upload/preview'),
    );
    request.headers.addAll({'Authorization': 'Bearer $_token'});
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw ApiException('上传超时'),
    );

    final resp = await http.Response.fromStream(streamedResponse);
    return _parseResponse(resp);
  }

  /// 确认数据入库
  Future<Map<String, dynamic>> uploadConfirm({
    required String city,
    required int year,
    required String permission,
    required List<Map<String, dynamic>> data,
  }) async {
    return await _post('/api/v1/upload/confirm', body: {
      'city': city,
      'year': year,
      'permission': permission,
      'data': data,
    });
  }

  // ==================== 训练 ====================

  /// 启动训练
  Future<Map<String, dynamic>> startTraining({int epochs = 50, bool incremental = true}) async {
    final result = await _post('/api/v1/training/start', body: {
      'epochs': epochs,
      'incremental': incremental,
    });
    if (result['success'] == true) {
      return result['data'] ?? {};
    }
    throw ApiException(result['message'] ?? '启动训练失败');
  }

  /// 训练状态
  Future<Map<String, dynamic>> getTrainingStatus() async {
    final result = await _get('/api/v1/training/status');
    if (result['success'] == true) {
      return result['data'] ?? {};
    }
    return {};
  }

  /// 训练历史
  Future<List<Map<String, dynamic>>> getTrainingHistory() async {
    final result = await _get('/api/v1/training/history');
    if (result['success'] == true && result['data'] != null) {
      return List<Map<String, dynamic>>.from(result['data']);
    }
    return [];
  }

  // ==================== 风险监控 ====================

  /// 触发扫描
  Future<Map<String, dynamic>> triggerScan({String? city}) async {
    final params = <String, String>{};
    if (city != null) params['city'] = city;
    final result = await _get('/api/v1/monitor/scan', params: params.isNotEmpty ? params : null);
    if (result['success'] == true) {
      return result['data'] ?? {};
    }
    throw ApiException(result['message'] ?? '扫描失败');
  }

  /// 获取告警列表
  Future<List<Map<String, dynamic>>> getAlerts({String? city, String? level}) async {
    final params = <String, String>{};
    if (city != null) params['city'] = city;
    if (level != null) params['level'] = level;
    final result = await _get('/api/v1/monitor/alerts', params: params.isNotEmpty ? params : null);
    if (result['success'] == true && result['data'] != null) {
      return List<Map<String, dynamic>>.from(result['data']);
    }
    return [];
  }

  /// 监控概览
  Future<Map<String, dynamic>> getMonitorOverview() async {
    final result = await _get('/api/v1/monitor/overview');
    if (result['success'] == true) {
      return result['data'] ?? {};
    }
    return {};
  }

  // ==================== LLM 配置 ====================

  /// 获取支持的 Provider 列表
  Future<List<Map<String, dynamic>>> getProviders() async {
    final result = await _get('/api/v1/llm/providers');
    if (result['success'] == true && result['data'] != null) {
      return List<Map<String, dynamic>>.from(result['data']);
    }
    return [];
  }

  /// 设置 API Key（存到后端内存）
  Future<void> setApiKey({required String model, required String apiKey}) async {
    await _post('/api/v1/llm/set-api-key', body: {'model': model, 'api_key': apiKey});
  }

  /// 测试 LLM 连接（带 API Key + Provider + AppID）
  Future<Map<String, dynamic>> testLlmConnection({String? apiKey, String model = 'bluelm', String? appId}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/llm/test-connection');
    final resp = await http.get(uri, headers: {
      ..._headers,
      if (apiKey != null) 'X-AI-API-Key': apiKey,
      'X-AI-Model': model,
      if (appId != null) 'X-AI-App-ID': appId,
    }).timeout(const Duration(seconds: 30));
    final body = jsonDecode(utf8.decode(resp.bodyBytes));
    return body['data'] ?? {};
  }

  // ==================== 健康检查 ====================

  Future<bool> healthCheck() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ==================== 数据类 ====================

class ChatEvent {
  final String type; // start, chunk, done, error
  final String? content;
  final int? chatId;

  ChatEvent({required this.type, this.content, this.chatId});
}

class ApiException implements Exception {
  final String message;
  final int? code;
  ApiException(this.message, {this.code});
  @override
  String toString() => message;
}
