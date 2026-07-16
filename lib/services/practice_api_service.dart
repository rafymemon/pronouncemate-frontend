// services/practice_api_service.dart
// API calls for Practice Mistakes feature

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/practice_models.dart';

class PracticeApiService {
  static const String baseUrl = 'http://your-server:8000/api';

  /// Submit audio for main pronunciation evaluation
  static Future<Map<String, dynamic>> submitPronunciation(
    File audioFile,
    String script, {
    String? userId,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/pronounce/'),
    );

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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mistake_data': mistakeWords.map((w) => w.toJson()).toList(),
        'mode': mode,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Submit audio for practice session
  static Future<PracticeResult> submitPractice(
    File audioFile,
    List<MistakeWord> mistakeWords,
    String originalSessionId, {
    String mode = 'sentences',
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/practice/'),
    );

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
    return PracticeResult.fromJson(jsonDecode(responseData));
  }
}