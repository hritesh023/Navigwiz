import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class SearchResult {
  final String title;
  final String url;
  final String snippet;

  SearchResult({required this.title, required this.url, required this.snippet});

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
    snippet: json['snippet'] as String? ?? '',
  );
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;

  ApiException(this.statusCode, this.message, [this.body]);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ChatResponse {
  final String content;
  final String type;
  final String sessionId;
  final String? imageBase64;
  final String? fileData;
  final String? fileName;
  final String? fileType;

  ChatResponse({
    required this.content,
    this.type = 'chat',
    required this.sessionId,
    this.imageBase64,
    this.fileData,
    this.fileName,
    this.fileType,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
    content: json['message'] as String? ?? json['content'] as String? ?? '',
    type: json['type'] as String? ?? 'chat',
    sessionId: json['session_id'] as String? ?? '',
    imageBase64: (json['image_base64'] as String?) ?? (json['image_data'] as String?),
    fileData: json['file_data'] as String?,
    fileName: json['file_name'] as String?,
    fileType: json['file_type'] as String?,
  );
}

class ApiClient {
  String _baseUrl;
  http.Client _client = http.Client();
  String? _authToken;

  ApiClient({String baseUrl = ''}) : _baseUrl = baseUrl;

  String get baseUrl => _baseUrl;
  void updateBaseUrl(String url) => _baseUrl = url;
  void setAuthToken(String? token) => _authToken = token;
  void cancelCurrentRequest() {
    try {
      _client.close();
    } catch (_) {}
    _client = http.Client();
  }

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Map<String, dynamic> _checkResponse(http.Response response) {
    final body = response.body;
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      } else {
        json = <String, dynamic>{'results': decoded};
      }
    } catch (e) {
      throw ApiException(response.statusCode,
          'Request failed: invalid response format', <String, dynamic>{'response': body});
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errMsg = json['error'] as String? ??
          json['detail'] as String? ??
          json['message'] as String? ??
          '';
      throw ApiException(response.statusCode,
          errMsg.isNotEmpty ? errMsg : 'Request failed ($response.statusCode)', json);
    }
    return json;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
      {Duration? timeout}) async {
    var future = _client.post(Uri.parse('$_baseUrl$path'),
        headers: _headers, body: jsonEncode(body));
    if (timeout != null) future = future.timeout(timeout);
    return _checkResponse(await future);
  }

  Future<Map<String, dynamic>> _multipartPost(String path, Map<String, String> fields,
      Uint8List fileBytes, String fileName,
      {Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
    var future = request.send();
    if (timeout != null) future = future.timeout(timeout);
    final streamed = await future;
    return _checkResponse(await http.Response.fromStream(streamed));
  }

  Future<ChatResponse> chat({
    required String message,
    String? sessionId,
    List<Map<String, dynamic>>? attachments,
    Duration? timeout,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'session_id': sessionId ?? 'default',
    };
    if (attachments != null) body['attachments'] = attachments;
    final resp = await _post('/api/v1/chat', body, timeout: timeout);
    return ChatResponse(
      content: resp['message'] as String? ?? '',
      sessionId: resp['session_id'] as String? ?? sessionId ?? '',
      type: 'chat',
    );
  }

  Future<ChatResponse> chatWithImage({
    required String message,
    required Uint8List imageBytes,
    required String fileName,
    String? sessionId,
    Duration? timeout,
  }) async {
    final fields = <String, String>{'message': message};
    if (sessionId != null) fields['session_id'] = sessionId;
    final resp = await _multipartPost('/api/v1/upload', fields, imageBytes, fileName,
        timeout: timeout);
    return ChatResponse(
      content: resp['analysis']?['vision_analysis'] as String? ?? '',
      sessionId: sessionId ?? '',
      type: 'chat',
    );
  }

  Future<ChatResponse> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    String message = '',
    String? sessionId,
    Duration? timeout,
  }) async {
    final fields = <String, String>{'message': message, 'analysis_type': 'auto'};
    if (sessionId != null) fields['session_id'] = sessionId;
    final resp = await _multipartPost('/api/v1/upload', fields, fileBytes, fileName,
        timeout: timeout);
    final analysis = resp['analysis'] as Map<String, dynamic>? ?? {};
    return ChatResponse(
      content: analysis['text'] as String? ?? jsonEncode(resp),
      sessionId: sessionId ?? '',
      type: 'chat',
    );
  }

  Future<Map<String, dynamic>> generateImage({
    required String prompt,
    String? sessionId,
    Duration? timeout,
  }) async {
    final body = <String, dynamic>{'prompt': prompt};
    if (sessionId != null) body['session_id'] = sessionId;
    return _post('/api/v1/image/generate', body, timeout: timeout);
  }

  Future<List<SearchResult>> search(String query, {
    String category = 'general',
    int numResults = 10,
    Duration? timeout,
  }) async {
    final body = <String, dynamic>{
      'query': query,
      'category': category,
      'num_results': numResults,
    };
    final resp = await _post('/api/v1/search', body, timeout: timeout);
    final results = (resp['results'] as List?) ?? [];
    return results.map((r) => SearchResult.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> analyze(String type, {
    String? content,
    String? filePath,
    String? prompt,
    Duration? timeout,
  }) async {
    final body = <String, dynamic>{
      'type': type,
      if (content != null) 'content': content,
      if (filePath != null) 'file_path': filePath,
      if (prompt != null) 'prompt': prompt,
    };
    return _post('/api/v1/analyze', body, timeout: timeout);
  }

  Future<Map<String, dynamic>> research(String query, {Duration? timeout}) async {
    final fields = <String, String>{'query': query};
    final uri = Uri.parse('$_baseUrl/api/v1/research');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    request.fields.addAll(fields);
    var future = request.send();
    if (timeout != null) future = future.timeout(timeout);
    final streamed = await future;
    return _checkResponse(await http.Response.fromStream(streamed));
  }

  Future<Map<String, dynamic>> extractContent(String url, {Duration? timeout}) async {
    final fields = <String, String>{'url': url};
    final uri = Uri.parse('$_baseUrl/api/v1/extract');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    request.fields.addAll(fields);
    var future = request.send();
    if (timeout != null) future = future.timeout(timeout);
    final streamed = await future;
    return _checkResponse(await http.Response.fromStream(streamed));
  }

  Future<Map<String, dynamic>> transcribe(Uint8List audioBytes, String fileName,
      {Duration? timeout}) async {
    final fields = <String, String>{};
    return _multipartPost('/api/v1/transcribe', fields, audioBytes, fileName,
        timeout: timeout);
  }
}
