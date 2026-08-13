import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  // ── File-based mode (used by active_session_screen.dart) ──────
  String? _currentPath;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    _currentPath = '${dir.path}/chunk_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: _currentPath!,
    );
  }

  Future<File?> stop() async {
    final path = await _recorder.stop();
    if (path != null) {
      return File(path);
    }
    return null;
  }

  // ── Streaming mode (used by practice_session_screen.dart) ──────
  final List<int> _pcmBuffer = [];
  StreamSubscription<Uint8List>? _streamSub;

  Future<Stream<Uint8List>> startLiveStream() async {
    _pcmBuffer.clear();

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    final controller = StreamController<Uint8List>.broadcast();
    _streamSub = stream.listen((chunk) {
      _pcmBuffer.addAll(chunk);
      controller.add(chunk);
    }, onDone: () => controller.close());

    return controller.stream;
  }

  Future<File?> stopAndSaveWav() async {
    await _recorder.stop();
    await _streamSub?.cancel();
    _streamSub = null;

    if (_pcmBuffer.isEmpty) return null;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/practice_${DateTime.now().millisecondsSinceEpoch}.wav';
    final file = File(path);

    final pcmBytes = Uint8List.fromList(_pcmBuffer);
    final wavBytes = _wrapPcmAsWav(pcmBytes, sampleRate: 16000, numChannels: 1);
    await file.writeAsBytes(wavBytes);

    _pcmBuffer.clear();
    return file;
  }

  Uint8List _wrapPcmAsWav(Uint8List pcm, {required int sampleRate, required int numChannels}) {
    final byteRate = sampleRate * numChannels * 2;
    final blockAlign = numChannels * 2;
    final dataLength = pcm.length;
    final header = BytesBuilder();

    void writeString(String s) => header.add(s.codeUnits);
    void writeUint32(int v) => header.add([
          v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff
        ]);
    void writeUint16(int v) => header.add([v & 0xff, (v >> 8) & 0xff]);

    writeString('RIFF');
    writeUint32(36 + dataLength);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16);
    writeUint16(1);
    writeUint16(numChannels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(16);
    writeString('data');
    writeUint32(dataLength);

    final result = BytesBuilder();
    result.add(header.toBytes());
    result.add(pcm);
    return result.toBytes();
  }

  // ── Shared ───────────────────────────────────────────────────
  Future<bool> get isRecording async => await _recorder.isRecording();

  void dispose() {
    _streamSub?.cancel();
    _recorder.dispose();
  }
}