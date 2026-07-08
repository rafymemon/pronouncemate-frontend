import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  // Renamed to 'start' to perfectly match your UI screen
  Future<void> start() async {
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

  // Renamed to 'stop' to perfectly match your UI screen
  Future<File?> stop() async {
    final path = await _recorder.stop();
    if (path != null) {
      return File(path);
    }
    return null;
  }

  // Updated to safely handle the Future<bool> required by the record package
  Future<bool> get isRecording async => await _recorder.isRecording();

  void dispose() {
    _recorder.dispose();
  }
}