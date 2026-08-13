// services/practice_api_service.dart
// API calls for Practice Mistakes feature

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/practice_models.dart';
import '../config.dart';

class PracticeApiService {
  static String get baseUrl => "${AppConfig.baseUrl}/api";

  // ── Auth token (all practice endpoints require IsAuthenticated) ──
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _authHeaders({String contentType = 'application/json'}) async {
    final token = await _getToken();
    return {
      if (token != null) 'Authorization': 'Token $token',
      'Content-Type': contentType,
    };
  }

  /// Submit audio for main pronunciation evaluation
  static Future<Map<String, dynamic>> submitPronunciation(
    File audioFile,
    String script, {
    String? userId,
  }) async {
    final token = await _getToken();
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/pronounce/'),
    );
    if (token != null) request.headers['Authorization'] = 'Token $token';

    request.files.add(await http.MultipartFile.fromPath(
      'audio',
      audioFile.path,
      contentType: MediaType('audio', 'wav'),
    ));

    request.fields['script'] = script;
    if (userId != null) request.fields['user_id'] = userId;

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    return jsonDecode(responseData);
  }

  /// Get practice script preview (before recording)
  static Future<Map<String, dynamic>> getPracticeScript(
    List<MistakeWord> mistakeWords, {
    String mode = 'sentences',
  }) async {
    var response = await http.post(
      Uri.parse('$baseUrl/practice/script/'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'mistake_data': mistakeWords.map((w) => w.toJson()).toList(),
        'mode': mode,
      }),
    );

    if (response.statusCode == 401) {
      return {'success': false, 'error': 'Not authenticated. Please log in again.'};
    }

    return jsonDecode(response.body);
  }

  /// Submit audio for practice session
  static Future<PracticeResult> submitPractice(
    File audioFile,
    List<MistakeWord> mistakeWords,
    String originalSessionId, {
    String mode = 'sentences',
  }) async {
    final token = await _getToken();
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/practice/'),
    );
    if (token != null) request.headers['Authorization'] = 'Token $token';

    request.files.add(await http.MultipartFile.fromPath(
      'audio',
      audioFile.path,
      contentType: MediaType('audio', 'wav'),
    ));

    request.fields['original_session_id'] = originalSessionId;
    request.fields['mode'] = mode;
    request.fields['mistake_data'] = jsonEncode(
      mistakeWords.map((w) => w.toJson()).toList(),
    );

    var response = await request.send();
    var responseData = await response.stream.bytesToString();

    if (response.statusCode == 401) {
      throw Exception('Not authenticated. Please log in again.');
    }

    return PracticeResult.fromJson(jsonDecode(responseData));
  }
}