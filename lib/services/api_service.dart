// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../config.dart';
import 'auth_service.dart';

class ApiService {
  static String get baseUrl => "${AppConfig.baseUrl}/api";

  // ── Token management ───────────────────────────────────
  // Auth (register/login/logout) is handled exclusively by AuthService.
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

  /// A 401 means the server no longer accepts our token (revoked, password
  /// changed on another device, account removed). End the session; the app
  /// root then returns the user to the login screen.
  static void _checkAuth(http.Response response) {
    if (response.statusCode == 401) {
      unawaited(AuthService.instance.handleUnauthorized());
    }
  }

  // ── Core analyze endpoint ───────────────────────────────
  static Future<Map<String, dynamic>> analyzeAudio(
      File audioFile, String scriptText, {String? scriptId}) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/analyze/'),
    );
    request.headers['Authorization'] = 'Token $token';
    request.fields['script_text'] = scriptText;

    if (scriptId != null && scriptId.isNotEmpty) {
      request.fields['script_id'] = scriptId;
    }

    request.files.add(
      await http.MultipartFile.fromPath('audio', audioFile.path),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    _checkAuth(response);
    return jsonDecode(response.body);
  }

  // ── Session history ─────────────────────────────────────
  static Future<List<dynamic>> getSessions({int? days}) async {
    final params = <String, String>{};
    if (days != null) params['days'] = days.toString();

    final uri = Uri.parse('$baseUrl/sessions/').replace(
      queryParameters: params.isEmpty ? null : params,
    );

    final response = await http.get(uri, headers: await authHeaders);
    _checkAuth(response);
    if (response.statusCode == 401) return <dynamic>[];
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile/'),
        headers: await authHeaders,
      ).timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> data) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/profile/'),
        headers: await authHeaders,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Update failed ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> clearSessionHistory() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/profile/'),
        headers: await authHeaders,
      ).timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Failed ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ── Scripts ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getScripts({
    String? mode,
    String? level,
  }) async {
    try {
      final params = <String, String>{};
      if (mode != null) params['mode'] = mode;
      if (level != null) params['level'] = level;

      final uri = Uri.parse('$baseUrl/scripts/').replace(queryParameters: params);

      final token = await getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Token $token',
      };

      final response = await http.get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {
        'builtin': [],
        'uploaded': [],
        'error': 'Server error ${response.statusCode}'
      };
    } catch (e) {
      return {'builtin': [], 'uploaded': [], 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getRotatedScripts({
    String? mode,
    String? level,
    int count = 5,
  }) async {
    try {
      final params = <String, String>{'count': count.toString()};
      if (mode != null) params['mode'] = mode;
      if (level != null) params['level'] = level;

      final uri = Uri.parse('$baseUrl/scripts/rotation/')
          .replace(queryParameters: params);

      final response = await http
          .get(uri, headers: await authHeaders)
          .timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'scripts': List<Map<String, dynamic>>.from(
            (data['scripts'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e)),
          ),
        };
      }
      return {'scripts': [], 'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'scripts': [], 'error': e.toString()};
    }
  }

  // FIX: `level` is now optional. When omitted, the backend auto-assigns
  // difficulty from the script's word count instead of always defaulting
  // to 'intermediate'. Used by the "type or paste text" upload dialog,
  // which no longer shows a manual difficulty picker.
  static Future<Map<String, dynamic>> uploadScriptText({
    required String title,
    required String content,
    String? level,
    String? mode,
  }) async {
    final body = {
      'title': title,
      'content': content,
      if (level != null) 'level': level,
      if (mode != null) 'mode': mode,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/scripts/upload/'),
      headers: await authHeaders,
      body: jsonEncode(body),
    );
    _checkAuth(response);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> uploadScriptFile(
    File file, {
    String? title,
    String level = 'intermediate',
    String? mode,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/scripts/upload/'),
    );
    request.headers['Authorization'] = 'Token $token';
    if (title != null) request.fields['title'] = title;
    request.fields['level'] = level;
    if (mode != null) request.fields['mode'] = mode;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _checkAuth(response);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> generateAiScript({
    required String topic,
    required int wordLimit,
    required String mode,
    required String level,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/scripts/generate/'),
        headers: await authHeaders,
        body: jsonEncode({
          'topic': topic,
          'word_limit': wordLimit,
          'mode': mode,
          'level': level,
        }),
      ).timeout(const Duration(seconds: 30));
      _checkAuth(response);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        return data;
      }
      return {
        'error': data['error']?.toString() ?? 'Server error ${response.statusCode}'
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ── Dashboard ───────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/dashboard/'),
            headers: await authHeaders,
          )
          .timeout(const Duration(seconds: 15));
      _checkAuth(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getProgressAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/'),
        headers: await authHeaders,
      ).timeout(const Duration(seconds: 15));
      _checkAuth(response);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ── Improvement Phase ───────────────────────────────────
  static Future<Map<String, dynamic>> getProgressionStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/progression/'),
        headers: await authHeaders,
      ).timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> confirmPromotion() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/progression/confirm/'),
        headers: await authHeaders,
      ).timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200 || response.statusCode == 400) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getWordMastery({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;

      final uri = Uri.parse('$baseUrl/mastery/').replace(queryParameters: params);

      final response = await http.get(uri, headers: await authHeaders)
          .timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'words': List<Map<String, dynamic>>.from(
            (data as List).map((e) => Map<String, dynamic>.from(e)),
          ),
        };
      }
      return {'words': [], 'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'words': [], 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getLatestFocusScript() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/focus-scripts/latest/'),
        headers: await authHeaders,
      ).timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'focus_script': null, 'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'focus_script': null, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> completeFocusScript(
    int scriptId, {
    required double postErrorRate,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/focus-scripts/$scriptId/complete/'),
        headers: await authHeaders,
        body: jsonEncode({'post_error_rate': postErrorRate}),
      ).timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getFocusScriptHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/focus-scripts/'),
        headers: await authHeaders,
      ).timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'scripts': List<Map<String, dynamic>>.from(
            (data as List).map((e) => Map<String, dynamic>.from(e)),
          ),
        };
      }
      return {'scripts': [], 'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'scripts': [], 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getFocusScriptStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/focus-scripts/stats/'),
        headers: await authHeaders,
      ).timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ── Notifications ────────────────────────────────────────
  static Future<Map<String, dynamic>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/'),
        headers: await authHeaders,
      ).timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'notifications': [], 'unread_count': 0, 'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'notifications': [], 'unread_count': 0, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> markNotificationsRead() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/read/'),
        headers: await authHeaders,
      ).timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Deletes one notification (swipe-to-dismiss). A 404 is treated as
  /// success: the notification is already gone, which is what the user
  /// wanted.
  static Future<Map<String, dynamic>> deleteNotification(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$id/'),
        headers: await authHeaders,
      ).timeout(const Duration(seconds: 10));
      _checkAuth(response);

      if (response.statusCode == 200 || response.statusCode == 404) {
        return {'message': 'Notification deleted'};
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}