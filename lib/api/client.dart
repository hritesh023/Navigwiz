import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class SearchResult {
  final String title;
  final String url;
  final String snippet;
  SearchResult({required this.title, required this.url, required this.snippet});
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;
  ApiException(this.statusCode, this.message, [this.body]);
  @override String toString() => 'ApiException($statusCode): $message';
}

class ChatResponse {
  final String content; final String type;
  final String sessionId; final String? imageBase64;
  final String? fileData; final String? fileName; final String? fileType;

  ChatResponse({required this.content, this.type = 'chat', required this.sessionId,
    this.imageBase64, this.fileData, this.fileName, this.fileType});

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
    content: json['content'] as String? ?? '',
    type: json['type'] as String? ?? 'chat',
    sessionId: json['session_id'] as String? ?? '',
    imageBase64: (json['image_base64'] as String?) ?? (json['image_data'] as String?),
    fileData: json['file_data'] as String?,
    fileName: json['file_name'] as String?,
    fileType: json['file_type'] as String?);
}

class ApiClient {
  String _baseUrl;
  http.Client _client = http.Client();

  ApiClient({String baseUrl = ''}) : _baseUrl = baseUrl;

  String get baseUrl => _baseUrl;
  void updateBaseUrl(String url) => _baseUrl = url;
  void cancelCurrentRequest() { try { _client.close(); } catch (_) {} _client = http.Client(); }
  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Map<String, dynamic> _checkResponse(http.Response response) {
    final body = response.body;
    Map<String, dynamic> json;
    try { json = jsonDecode(body) as Map<String, dynamic>; } catch (e) { throw ApiException(response.statusCode, 'Request failed: invalid response format', <String, dynamic>{'response': body}); }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errMsg = json['error'] as String? ?? json['detail'] as String? ?? json['message'] as String? ?? '';
      throw ApiException(response.statusCode, errMsg.isNotEmpty ? errMsg : 'Request failed ($response.statusCode)', json);
    }
    return json;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {Duration? timeout}) async {
    var future = _client.post(Uri.parse('$_baseUrl$path'), headers: _headers, body: jsonEncode(body));
    if (timeout != null) future = future.timeout(timeout);
    return _checkResponse(await future);
  }

  Future<Map<String, dynamic>> _multipartPost(String path, Map<String, String> fields, Uint8List fileBytes, String fileName, {Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
    var future = request.send(); if (timeout != null) future = future.timeout(timeout);
    final streamed = await future;
    return _checkResponse(await http.Response.fromStream(streamed));
  }

  Future<ChatResponse> chat({required String message, String? sessionId, Duration? timeout}) async {
    final body = <String, dynamic>{'message': message, 'session_id': sessionId ?? 'default'};
    final resp = await _post('/v1/chat', body, timeout: timeout);
    return ChatResponse(content: resp['response'] as String? ?? '', sessionId: resp['session_id'] as String? ?? sessionId ?? '',
      type: resp['type'] as String? ?? 'chat',
      imageBase64: resp['image_data'] as String?,
      fileData: resp['file_data'] as String?, fileName: resp['file_name'] as String?, fileType: resp['file_type'] as String?);
  }

  Future<ChatResponse> chatWithImage({required String message, required Uint8List imageBytes, required String fileName, String? sessionId, Duration? timeout}) async {
    final fields = <String, String>{'message': message}; if (sessionId != null) fields['session_id'] = sessionId;
    final resp = await _multipartPost('/v1/chat/image', fields, imageBytes, fileName, timeout: timeout);
    return ChatResponse(content: resp['response'] as String? ?? '', sessionId: resp['session_id'] as String? ?? sessionId ?? '', type: resp['type'] as String? ?? 'chat');
  }

  Future<ChatResponse> uploadFile({required Uint8List fileBytes, required String fileName, String message = '', String? sessionId, Duration? timeout}) async {
    final fields = <String, String>{'message': message}; if (sessionId != null) fields['session_id'] = sessionId;
    final resp = await _multipartPost('/v1/chat/file', fields, fileBytes, fileName, timeout: timeout);
    return ChatResponse(content: resp['response'] as String? ?? '', sessionId: resp['session_id'] as String? ?? sessionId ?? '', type: resp['type'] as String? ?? 'chat');
  }

  Future<Map<String, dynamic>> generateImage({required String prompt, String? sessionId, Duration? timeout}) async {
    final body = <String, dynamic>{'prompt': prompt}; if (sessionId != null) body['session_id'] = sessionId;
    return _post('/v1/image/generate', body, timeout: timeout);
  }
}