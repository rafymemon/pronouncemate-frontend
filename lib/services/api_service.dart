import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Android emulator → use 10.0.2.2 to reach your laptop
  // Physical device → use your laptop's actual IP (e.g. 192.168.1.5)
  // Find your IP: ipconfig (Windows) / ifconfig (Mac/Linux)
  static const String baseUrl = "http://10.0.2.2:8000/api";

  // ── Token management ───────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<Map<String, String>> get authHeaders async {
    final token = await getToken();
    return {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    };
  }

  // ── Auth endpoints ─────────────────────────────────────
  static Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['token'] != null) {
      await saveToken(data['token']);
    }
    return data;
  }

  static Future<void> logout() async {
    await clearToken();
  }

  // ── Core analyze endpoint ───────────────────────────────
  static Future<Map<String, dynamic>> analyzeAudio(
      File audioFile, String scriptText) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/analyze/'),
    );
    request.headers['Authorization'] = 'Token $token';
    request.fields['script_text'] = scriptText;
    request.files.add(
      await http.MultipartFile.fromPath('audio', audioFile.path),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body);
  }

  // ── Session history ─────────────────────────────────────
  static Future<List<dynamic>> getSessions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/sessions/'),
      headers: await authHeaders,
    );
    return jsonDecode(response.body);
  }

  // ── User profile ────────────────────────────────────────
  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile/'),
      headers: await authHeaders,
    );
    return jsonDecode(response.body);
  }

  // lib/services/api_service.dart — add these methods

  static Future<Map<String, dynamic>> getScripts({
    String? level,
    String? mode,
  }) async {
    String url = '$baseUrl/scripts/';
    final params = <String>[];
    if (level != null) params.add('level=$level');
    if (mode != null) params.add('mode=$mode');
    if (params.isNotEmpty) url += '?${params.join('&')}';

    final response = await http.get(
      Uri.parse(url),
      headers: await authHeaders,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> uploadScriptText({
    required String title,
    required String content,
    String level = 'intermediate',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/scripts/upload/'),
      headers: await authHeaders,
      body: jsonEncode({
        'title': title,
        'content': content,
        'level': level,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> uploadScriptFile(File file,
      {String? title, String level = 'intermediate'}) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/scripts/upload/'),
    );
    request.headers['Authorization'] = 'Token $token';
    if (title != null) request.fields['title'] = title;
    request.fields['level'] = level;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return jsonDecode(response.body);
  }
}
