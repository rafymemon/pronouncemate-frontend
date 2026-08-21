import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';

/// Matches consumers.py's per-word 'word_result' message exactly:
/// {'type': 'word_result', 'word_index': int, 'expected': str, 'status': str}
/// status is 'correct' | 'error' | 'skipped'.
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
    final wsBase = AppConfig.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsBase/ws/practice/');
    print('🎤 [WS] Connecting to $uri');

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
        print('🎤 [WS] Received word_result: idx=${data['word_index']} status=${data['status']}'); // TEMP
        _wordResultController.add(WordResult(
          data['word_index'] as int,
          data['expected']?.toString() ?? '',
          data['status']?.toString() ?? 'error',
        ));
      }
    }, onError: (e, st) {
      // Live layer failing shouldn't block the session — final REST
      // result still arrives independently — but log it so a broken
      // connection is visible instead of just "coloring doesn't work".
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