// lib/services/focus_api_service.dart
// Focus Script before/after endpoints.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class FocusApiService {
  static String get _baseUrl => "${AppConfig.baseUrl}/api";

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    };
  }

  /// One Focus Script, including `baseline`
  /// ([{word, error_type, error_count}]) for pre-highlighting.
  static Future<Map<String, dynamic>> getFocusScript(int id) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/focus-scripts/$id/'),
              headers: await _headers())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Marks the Focus Script complete using the practice session's id.
  /// The backend compares that session with the original errors and
  /// returns the Focus Script with a full `result` comparison.
  static Future<Map<String, dynamic>> completeWithSession(
    int focusScriptId, {
    required int sessionId,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/focus-scripts/$focusScriptId/complete/'),
            headers: await _headers(),
            body: jsonEncode({'session_id': sessionId}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}