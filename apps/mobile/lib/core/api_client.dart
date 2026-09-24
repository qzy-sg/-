import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code});

  final String message;
  final int? status;
  final String? code;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? token, String? baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConfig.apiBase,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Accept': 'application/json',
              if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
          ),
        );

  static void Function()? onUnauthorized;

  final Dio _dio;

  Future<Map<String, dynamic>> _data(Future<Response<dynamic>> call) async {
    try {
      final response = await call;
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {};
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401) {
        onUnauthorized?.call();
      }
      final body = error.response?.data;
      var message = status == 401 ? '登录已过期，请重新登录' : '网络请求失败';
      if (status == 404) message = '服务接口不可用，请确认后端已重启';
      String? code;
      if (body is Map && body['message'] is String) {
        message = body['message'] as String;
        code = body['code'] as String?;
      }
      throw ApiException(message, status: error.response?.statusCode, code: code);
    }
  }

  Future<String> login(String email, String password) async {
    final data = await _data(_dio.post('/api/v1/auth/login', data: {
      'email': email,
      'password': password,
    }));
    return data['access_token'] as String;
  }

  Future<Map<String, dynamic>> requestSms(String phone) {
    return _data(_dio.post('/api/v1/auth/sms/send', data: {'phone': phone}));
  }

  Future<String> loginPhone(String phone, String code) async {
    final data = await _data(_dio.post('/api/v1/auth/phone', data: {'phone': phone, 'code': code}));
    return data['access_token'] as String;
  }

  Future<Map<String, dynamic>> wechatChallenge() {
    return _data(_dio.post('/api/v1/auth/wechat/challenge'));
  }

  Future<Map<String, dynamic>> loginWechat({required String state, required String subject}) {
    return _data(_dio.post('/api/v1/auth/wechat', data: {'state': state, 'subject': subject}));
  }

  Future<String> register({required String phone, required String code, required String password}) async {
    final data = await _data(_dio.post('/api/v1/auth/register', data: {
      'phone': phone,
      'code': code,
      'password': password,
    }));
    return data['access_token'] as String;
  }

  Future<Map<String, dynamic>> getAccount() {
    return _data(_dio.get('/api/v1/auth/me'));
  }

  Future<Map<String, dynamic>> updateAccount({
    String? displayName,
    String? city,
    String? bio,
    String? avatarId,
  }) {
    return _data(_dio.patch('/api/v1/auth/me', data: {
      'display_name': ?displayName,
      'city': ?city,
      'bio': ?bio,
      'avatar_id': ?avatarId,
    }));
  }

  Future<List<dynamic>> listProjects() async {
    final data = await _data(_dio.get('/api/v1/projects'));
    return (data['items'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> createProject(String name) {
    return _data(_dio.post('/api/v1/projects', data: {'name': name}));
  }

  Future<Map<String, dynamic>> updateProject(String id, {String? name}) {
    return _data(_dio.patch('/api/v1/projects/$id', data: {
      if (name != null && name.isNotEmpty) 'name': name,
    }));
  }

  Future<void> deleteProject(String id) async {
    await _data(_dio.delete('/api/v1/projects/$id'));
  }

  Future<Map<String, dynamic>> getProfile(String id) {
    return _data(_dio.get('/api/v1/projects/$id/profile'));
  }

  Future<Map<String, dynamic>> saveProfile(String id, Map<String, dynamic> body) {
    return _data(_dio.put('/api/v1/projects/$id/profile', data: body));
  }

  Future<Map<String, dynamic>> getProject(String id) {
    return _data(_dio.get('/api/v1/projects/$id'));
  }

  Future<Map<String, dynamic>> requestUpload(
    String projectId, {
    required String filename,
    required String contentType,
    required int sizeBytes,
  }) {
    return _data(_dio.post('/api/v1/projects/$projectId/assets/upload-url', data: {
      'filename': filename,
      'content_type': contentType,
      'size_bytes': sizeBytes,
      'kind': 'image',
    }));
  }

  Future<void> completeUpload(String projectId, String assetId) async {
    await _data(_dio.post('/api/v1/projects/$projectId/assets/$assetId/complete'));
  }

  Future<void> putBytes(
    String url,
    List<int> bytes,
    String contentType, {
    String? projectId,
    String? assetId,
  }) async {
    // 本地 Mock 存储：把字节交给 API，顺带做 EXIF 清理。
    if (url.contains('mock-storage.local') && projectId != null && assetId != null) {
      await _data(_dio.put(
        '/api/v1/projects/$projectId/assets/$assetId/bytes',
        data: bytes,
        options: Options(headers: {'Content-Type': contentType}),
      ));
      return;
    }
    if (url.contains('mock-storage.local')) return;
    final dio = Dio();
    await dio.put(url, data: bytes, options: Options(headers: {'Content-Type': contentType}));
  }

  /// 申请签名 → 直传（Mock 走 API ingest）→ complete，返回 asset_id。
  Future<String> uploadImage(
    String projectId, {
    required String filename,
    required String contentType,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.1);
    final signed = await requestUpload(
      projectId,
      filename: filename,
      contentType: contentType,
      sizeBytes: bytes.length,
    );
    final assetId = signed['asset_id'] as String;
    final uploadUrl = signed['upload_url'] as String;
    onProgress?.call(0.4);
    await putBytes(uploadUrl, bytes, contentType, projectId: projectId, assetId: assetId);
    onProgress?.call(0.8);
    await completeUpload(projectId, assetId);
    onProgress?.call(1);
    return assetId;
  }

  Future<Map<String, dynamic>> getTask(String taskId) {
    return _data(_dio.get('/api/v1/tasks/$taskId'));
  }

  Future<List<dynamic>> taskEvents(String taskId, {int afterSequence = 0}) async {
    final data = await _data(_dio.get(
      '/api/v1/tasks/$taskId/events',
      queryParameters: {'after_sequence': afterSequence},
      options: Options(headers: {'Last-Event-ID': '$afterSequence'}),
    ));
    return (data['items'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> createAnalysis(String projectId, {String? assetId}) {
    return _data(_dio.post('/api/v1/projects/$projectId/analysis-tasks', data: {
      'asset_id': ?assetId,
    }));
  }

  Future<Map<String, dynamic>> confirmAnalysis(String projectId, String taskId, List<Map<String, dynamic>> rooms) {
    return _data(_dio.post('/api/v1/projects/$projectId/analysis-tasks/$taskId/confirm', data: {
      'accept': true,
      'rooms': rooms,
    }));
  }

  Future<Map<String, dynamic>> adoptAnalysis(String projectId, String taskId) {
    return _data(_dio.post('/api/v1/projects/$projectId/analysis-tasks/$taskId/adopt'));
  }

  Future<Map<String, dynamic>> sendMessage(String projectId, String content) {
    return _data(_dio.post('/api/v1/projects/$projectId/messages', data: {'content': content}));
  }

  Future<Map<String, dynamic>> consult(String content) {
    return _data(_dio.post(
      '/api/v1/ai/consult',
      data: {'content': content},
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    ));
  }

  /// SSE 流式顾问：onDelta 收到增量文本；返回终态 payload（含 reply）。
  Future<Map<String, dynamic>> consultStream(
    String content, {
    required void Function(String delta) onDelta,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<ResponseBody>(
        '/api/v1/ai/consult/stream',
        data: {'content': content},
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 2),
          headers: const {'Accept': 'text/event-stream'},
        ),
      );
      final body = response.data;
      if (body == null) throw ApiException('没有流式响应');

      final buffer = StringBuffer();
      String? eventName;
      Map<String, dynamic>? completed;
      String? failedMessage;

      void flushEvent(String rawData) {
        if (rawData.isEmpty) return;
        Map<String, dynamic>? envelope;
        try {
          final decoded = jsonDecode(rawData);
          if (decoded is Map) envelope = Map<String, dynamic>.from(decoded);
        } catch (_) {
          return;
        }
        final type = eventName ?? '${envelope?['type'] ?? ''}';
        final data = envelope?['data'];
        final payload = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        if (type == 'assistant.delta') {
          final piece = '${payload['text'] ?? ''}';
          if (piece.isNotEmpty) onDelta(piece);
        } else if (type == 'task.completed') {
          completed = payload;
        } else if (type == 'task.failed') {
          failedMessage = '${payload['message'] ?? '流式回复失败'}';
        }
        eventName = null;
      }

      await for (final chunk in body.stream) {
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        var content = buffer.toString();
        while (true) {
          final sep = content.indexOf('\n\n');
          if (sep < 0) break;
          final block = content.substring(0, sep);
          content = content.substring(sep + 2);
          var dataLines = <String>[];
          for (final line in block.split('\n')) {
            if (line.startsWith('event:')) {
              eventName = line.substring(6).trim();
            } else if (line.startsWith('data:')) {
              dataLines.add(line.substring(5).trim());
            }
          }
          if (dataLines.isNotEmpty) flushEvent(dataLines.join('\n'));
        }
        buffer
          ..clear()
          ..write(content);
      }

      if (failedMessage != null) throw ApiException(failedMessage!);
      if (completed != null) return completed!;
      throw ApiException('流式结束但没有完整回复');
    } on DioException catch (err) {
      if (CancelToken.isCancel(err)) rethrow;
      final status = err.response?.statusCode;
      if (status == 401) onUnauthorized?.call();
      final data = err.response?.data;
      if (data is Map && data['message'] != null) {
        throw ApiException('${data['message']}', status: status, code: data['code']?.toString());
      }
      if (status == 404) {
        throw ApiException('流式接口不可用，请确认后端已重启', status: status);
      }
      throw ApiException(err.message ?? '网络异常', status: status);
    }
  }

  /// 优先流式；失败时回退到一次性 consult（兼容未重启后端 / Web 流式限制）。
  Future<Map<String, dynamic>> consultPreferStream(
    String content, {
    required void Function(String delta) onDelta,
    CancelToken? cancelToken,
  }) async {
    try {
      return await consultStream(content, onDelta: onDelta, cancelToken: cancelToken);
    } on ApiException catch (err) {
      if (err.status == 401) rethrow;
      final data = await consult(content);
      final reply = '${data['reply'] ?? ''}';
      if (reply.isNotEmpty) onDelta(reply);
      return data;
    } catch (err) {
      if (err is DioException && CancelToken.isCancel(err)) rethrow;
      final data = await consult(content);
      final reply = '${data['reply'] ?? ''}';
      if (reply.isNotEmpty) onDelta(reply);
      return data;
    }
  }

  Future<List<dynamic>> listVersions(String projectId) async {
    final data = await _data(_dio.get('/api/v1/projects/$projectId/design-versions'));
    return (data['items'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> saveDraft(
    String projectId, {
    required bool confirmed,
    String title = '布局草案',
    String summary = '用户确认后保存',
    List<Map<String, dynamic>> options = const [],
    String? styleId,
  }) {
    return _data(_dio.post('/api/v1/projects/$projectId/design-versions', data: {
      'title': title,
      'summary': summary,
      'options': options,
      'confirmed': confirmed,
      if (styleId != null && styleId.isNotEmpty) 'style_id': styleId,
    }));
  }

  Future<Map<String, dynamic>> seedRooms(String projectId, {List<Map<String, dynamic>>? rooms, double? areaSqm}) {
    return _data(_dio.post('/api/v1/projects/$projectId/rooms/seed', data: {
      'rooms': ?rooms,
      'area_sqm': ?areaSqm,
    }));
  }

  Future<Map<String, dynamic>> confirmVersion(String projectId, String versionId) {
    return _data(_dio.post('/api/v1/projects/$projectId/design-versions/$versionId/confirm'));
  }

  Future<Map<String, dynamic>> createRender(String projectId, String versionId, {required bool confirmed}) {
    return _data(_dio.post('/api/v1/projects/$projectId/render-tasks', data: {
      'design_version_id': versionId,
      'confirmed': confirmed,
    }));
  }

  Future<Map<String, dynamic>> createScene(String projectId, {String? designVersionId, required bool confirmed}) {
    return _data(_dio.post('/api/v1/projects/$projectId/scene-tasks', data: {
      'confirmed': confirmed,
      'design_version_id': ?designVersionId,
    }));
  }

  Future<Map<String, dynamic>> latestScene(String projectId) {
    return _data(_dio.get('/api/v1/projects/$projectId/scene-versions/latest'));
  }

  Future<Map<String, dynamic>> manifest(String projectId, String versionId) {
    return _data(_dio.get('/api/v1/projects/$projectId/scene-versions/$versionId/manifest'));
  }

  Future<Map<String, dynamic>> confirmScene(String projectId, String versionId) {
    return _data(_dio.post('/api/v1/projects/$projectId/scene-versions/$versionId/confirm'));
  }
}
