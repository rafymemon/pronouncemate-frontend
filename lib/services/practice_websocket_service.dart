import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';

class WordResult {
  final int wordIndex;
  final bool correct;
  WordResult(this.wordIndex, this.correct);
}

class PracticeWebSocketService {
  WebSocketChannel? _channel;
  final _wordResultController = StreamController<WordResult>.broadcast();

  Stream<WordResult> get wordResults => _wordResultController.stream;

  Future<void> connect(String scriptText) async {
    final wsBase = AppConfig.baseUrl.replaceFirst('http', 'ws');
    _channel = WebSocketChannel.connect(Uri.parse('$wsBase/ws/practice/'));

    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['type'] == 'word_result') {
        _wordResultController.add(
          WordResult(data['word_index'], data['correct'] == true),
        );
      }
    }, onError: (e) {
      // Live layer failing shouldn't block the session — final REST
      // result still arrives independently.
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