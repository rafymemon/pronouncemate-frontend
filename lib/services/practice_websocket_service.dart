import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';
import 'auth_service.dart';

/// Matches consumers.py's per-word 'word_result' message exactly:
/// {'type': 'word_result', 'word_index': int, 'expected': str, 'status': str}
/// status is 'correct' | 'unsure' | 'skipped' | 'error'.
class WordResult {
  final int wordIndex;
  final String expected;
  final String status;
  WordResult(this.wordIndex, this.expected, this.status);
}

class PracticeWebSocketService {
  WebSocketChannel? _channel;
  final _wordResultController = StreamController<WordResult>.broadcast();

  Stream<WordResult> get wordResults => _wordResultController.stream;

  Future<void> connect(String scriptText) async {
    // The server only accepts authenticated connections.
    final token = await AuthService.instance.getToken();
    if (token == null) {
      print('🎤 [WS] No auth token — live feedback disabled');
      return;
    }

    final wsBase = AppConfig.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsBase/ws/practice/')
        .replace(queryParameters: {'token': token});
    // Never print the token itself.
    print('🎤 [WS] Connecting to $wsBase/ws/practice/');

    try {
      _channel = WebSocketChannel.connect(uri);
    } catch (e) {
      print('🎤 [WS] connect() threw: $e');
      return;
    }

    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      final type = data['type'];

      if (type == 'ready') {
        print('🎤 [WS] Server ready, total_words=${data['total_words']}');
      } else if (type == 'word_result') {
        _wordResultController.add(WordResult(
          data['word_index'] as int,
          data['expected']?.toString() ?? '',
          data['status']?.toString() ?? 'error',
        ));
      } else if (type == 'error') {
        print('🎤 [WS] Server error: ${data['message']}');
      }
    }, onError: (e, st) {
      // Live layer failing shouldn't block the session — the final REST
      // result still arrives independently (and the server rejects an
      // expired token here too) — but log it so a broken connection is
      // visible instead of just "coloring doesn't work".
      print('🎤 [WS] stream error: $e');
    }, onDone: () {
      print('🎤 [WS] Connection closed. '
          'code=${_channel?.closeCode} reason=${_channel?.closeReason}');
    });

    _channel!.sink.add(jsonEncode({'type': 'init', 'script_text': scriptText}));
  }

  void sendAudioChunk(Uint8List chunk) {
    _channel?.sink.add(chunk);
  }

  Future<void> close() async {
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _wordResultController.close();
  }
}