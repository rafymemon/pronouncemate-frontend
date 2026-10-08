// lib/services/stats_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Drill-down endpoints behind the Home / Dashboard stat cards and the
/// session rows.
class StatsApiService {
  /// metric: 'sessions' | 'accuracy' | 'words' | 'streak' | 'errors'
  /// scope:  'week' (current calendar week) | 'all' (since the beginning)
  static Future<Map<String, dynamic>> getStatDetail(
    String metric, {
    String scope = 'week',
  }) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/stats/$metric/')
          .replace(queryParameters: {'scope': scope});
      final response = await http
          .get(uri, headers: await ApiService.authHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Everything saved about one practice session.
  static Future<Map<String, dynamic>> getSessionDetail(int sessionId) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/sessions/$sessionId/'),
            headers: await ApiService.authHeaders,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 404) {
        return {'error': 'This session no longer exists.'};
      }
      return {'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}