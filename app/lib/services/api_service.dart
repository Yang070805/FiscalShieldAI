import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/prediction.dart';

/// TCP Socket API 服务
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _host = '127.0.0.1';
  int _port = 9527;

  void configure({String? host, int? port}) {
    if (host != null) _host = host;
    if (port != null) _port = port;
  }

  /// 健康检查
  Future<bool> healthCheck() async {
    try {
      final result = await _send({'action': 'health'});
      return result['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// 城市预测
  Future<PredictionResult> predictByCity({
    required String city,
    required int year,
    bool report = false,
  }) async {
    final result = await _send({
      'action': 'predict_by_city',
      'city': city,
      'year': year,
      'report': report,
    });
    if (result['status'] == 'error') throw ApiException(result['message'] ?? '预测失败');
    return PredictionResult.fromJson(result);
  }

  /// 批量预测
  Future<List<PredictionResult>> predictBatch({
    required List<String> cities,
    required int year,
    bool report = false,
  }) async {
    final result = await _send({
      'action': 'predict_batch',
      'cities': cities,
      'year': year,
      'report': report,
    });
    if (result['status'] == 'error') throw ApiException(result['message'] ?? '批量预测失败');
    return (result['results'] as List).map((r) => PredictionResult.fromJson(r)).toList();
  }

  /// 自定义指标预测
  Future<PredictionResult> predictCustom({
    required String city,
    required Map<String, double> metrics,
    bool report = false,
  }) async {
    final result = await _send({
      'action': 'predict_custom',
      'city': city,
      'indicators': metrics,
      'report': report,
    });
    if (result['status'] == 'error') throw ApiException(result['message'] ?? '预测失败');
    return PredictionResult.fromJson(result);
  }

  /// TCP 发送
  Future<Map<String, dynamic>> _send(Map<String, dynamic> request) async {
    Socket? socket;
    try {
      socket = await Socket.connect(_host, _port, timeout: const Duration(seconds: 10));
      socket.add(utf8.encode(jsonEncode(request)));
      await socket.flush();

      final completer = Completer<Map<String, dynamic>>();
      final buffer = StringBuffer();

      socket.listen(
        (data) {
          buffer.write(utf8.decode(data));
          try {
            final decoded = jsonDecode(buffer.toString());
            if (!completer.isCompleted) completer.complete(decoded);
          } catch (_) {}
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(ApiException('连接错误: $e'));
        },
        onDone: () {
          if (!completer.isCompleted) {
            try {
              completer.complete(jsonDecode(buffer.toString()));
            } catch (_) {
              completer.completeError(ApiException('连接已关闭'));
            }
          }
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw ApiException('请求超时'),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('连接失败: $e');
    } finally {
      socket?.destroy();
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
