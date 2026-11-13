import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Cau hinh khi build: --dart-define=API_BASE_URL=https://... --dart-define=APP_TOKEN=...
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8787');
const appToken = String.fromEnvironment('APP_TOKEN', defaultValue: 'dev-token');

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Map<String, String> get _headers => {'Content-Type': 'application/json', 'X-App-Token': appToken};

  Future<Map<String, dynamic>> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    Future<http.Response> once() {
      final f = method == 'GET'
          ? _client.get(uri, headers: _headers)
          : _client.post(uri, headers: _headers, body: jsonEncode(body ?? {}));
      return f.timeout(const Duration(seconds: 120));
    }

    http.Response r;
    try {
      try {
        r = await once();
      } on SocketException {
        r = await once(); // thu lai 1 lan khi mang chap chon
      }
    } on TimeoutException {
      throw ApiException('AI phản hồi quá lâu. Hãy thử tài liệu ngắn hơn hoặc thử lại.');
    } on SocketException {
      throw ApiException('Không kết nối được máy chủ. Kiểm tra mạng (Wi-Fi/4G) rồi thử lại.');
    } on http.ClientException {
      throw ApiException('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Máy chủ trả về dữ liệu không đọc được (mã ${r.statusCode}).');
    }
    if (r.statusCode >= 400) {
      throw ApiException(switch (r.statusCode) {
        401 => 'Ứng dụng chưa được cấp quyền gọi máy chủ (sai APP_TOKEN).',
        413 => 'Tài liệu quá lớn (tối đa ~4MB). Hãy dùng PDF ngắn hơn hoặc chụp từng trang.',
        429 => 'AI đang quá tải hoặc hết lượt. Đợi vài giây rồi thử lại.',
        503 => 'Máy chủ AI đang quá tải tạm thời. Hãy thử lại sau ít phút.',
        _ => 'AI gặp lỗi khi xử lý (${data['error'] ?? r.statusCode}). Hãy thử lại.',
      });
    }
    return data;
  }

  Future<bool> health() async {
    try {
      await _send('GET', '/api/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> upload({required String filename, required String mimeType, required List<int> bytes}) =>
      _send('POST', '/api/upload', {'filename': filename, 'mimeType': mimeType, 'dataBase64': base64Encode(bytes)});

  Future<Map<String, dynamic>> outline(Map<String, dynamic> body) => _send('POST', '/api/course/outline', body);
  Future<Map<String, dynamic>> lesson(Map<String, dynamic> body) => _send('POST', '/api/lesson', body);
  Future<Map<String, dynamic>> interactive(Map<String, dynamic> body) => _send('POST', '/api/interactive', body);
  Future<Map<String, dynamic>> explain(Map<String, dynamic> body) => _send('POST', '/api/explain', body);
  Future<Map<String, dynamic>> simulation(Map<String, dynamic> body) => _send('POST', '/api/simulation', body);
  Future<Map<String, dynamic>> ask(Map<String, dynamic> body) => _send('POST', '/api/ask', body);
  Future<Map<String, dynamic>> exercises(Map<String, dynamic> body) => _send('POST', '/api/exercises', body);
  Future<Map<String, dynamic>> searchSources(String topic, String role) =>
      _send('POST', '/api/sources/search', {'topic': topic, 'role': role});
}
