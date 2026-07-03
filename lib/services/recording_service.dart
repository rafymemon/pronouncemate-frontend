import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    final dir  = await getTemporaryDirectory();
    _currentPath = '${dir.path}/chunk_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,       // MUST be 16000 — required by Whisper
        numChannels: 1,          // MUST be mono
        bitRate: 256000,
      ),
      path: _currentPath!,
    );
  }

  Future<File?> stopRecording() async {
    final path = await _recorder.stop();
    if (path != null) {
      return File(path);
    }
    return null;
  }

  bool get isRecording => _recorder.isRecording as bool;

  void dispose() {
    _recorder.dispose();
  }
}