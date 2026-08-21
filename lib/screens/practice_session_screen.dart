// screens/practice_session_screen.dart
// Practice flow for mistake words. Same Start Recording -> live coloring
// -> Evaluate -> summary flow as active_session_screen.dart.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/practice_models.dart';
import '../models/word_status.dart';
import '../services/practice_api_service.dart';
import '../widgets/mistake_word_chip.dart';
import '../widgets/pronunciation_word_display.dart';
import '../widgets/session_stats_bar.dart';
import '../services/recording_service.dart';
import '../services/practice_websocket_service.dart';

enum _PracticeState { idle, recording, processing, done }

class PracticeSessionScreen extends StatefulWidget {
  final List<MistakeWord> mistakeWords;
  final String originalSessionId;
  final String mode;

  const PracticeSessionScreen({
    Key? key,
    required this.mistakeWords,
    required this.originalSessionId,
    this.mode = 'sentences',
  }) : super(key: key);

  @override
  _PracticeSessionScreenState createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  final RecordingService _rec = RecordingService();
  final PracticeWebSocketService _ws = PracticeWebSocketService();

  _PracticeState _state = _PracticeState.idle;
  bool _scriptLoadFailed = false;
  PracticeResult? _result;
  String? _practiceScript;
  List<DisplayWord> _liveWords = [];

  StreamSubscription? _wsSub;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  static const _minRecordingSeconds = 3;

  @override
  void initState() {
    super.initState();
    _loadPracticeScript();
  }

  @override
  void dispose() {
    _rec.dispose();
    _ws.dispose();
    _timer?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPracticeScript() async {
    final response = await PracticeApiService.getPracticeScript(
      widget.mistakeWords,
      mode: widget.mode,
    );

    if (response['success'] == true) {
      setState(() {
        _practiceScript = response['practice_script'];
        _liveWords = _practiceScript!
            .split(RegExp(r'\s+'))
            .where((w) => w.trim().isNotEmpty)
            .map((w) => DisplayWord(w))
            .toList();
        _scriptLoadFailed = false;
      });
    } else {
      setState(() => _scriptLoadFailed = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(response['error']?.toString() ??
                  'Failed to load practice script')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (_practiceScript == null || _practiceScript!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Practice script not loaded yet. Go back and retry.')),
      );
      return;
    }
    if (!await _rec.hasPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required')),
      );
      return;
    }

    setState(() {
      _state = _PracticeState.recording;
      for (final w in _liveWords) {
        w.status = WordStatus.pending;
      }
      _elapsed = Duration.zero;
    });

    _stopwatch
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _stopwatch.elapsed);
    });

    await _ws.connect(_practiceScript!);
    _wsSub = _ws.wordResults.listen((result) {
      if (!mounted) return;
      if (result.wordIndex < 0 || result.wordIndex >= _liveWords.length) return;
      setState(() {
        switch (result.status) {
          case 'correct':
            _liveWords[result.wordIndex].status = WordStatus.correct;
            break;
          case 'skipped':
            _liveWords[result.wordIndex].status = WordStatus.skipped;
            break;
          default:
            _liveWords[result.wordIndex].status = WordStatus.error;
        }
      });
    });

    final stream = await _rec.startLiveStream();
    stream.listen((chunk) => _ws.sendAudioChunk(chunk));
  }

  Future<void> _evaluate() async {
    if (_stopwatch.elapsed.inSeconds < _minRecordingSeconds) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording too short — try again.')),
      );
      return;
    }

    _stopwatch.stop();
    _timer?.cancel();

    final file = await _rec.stopAndSaveWav();
    await _wsSub?.cancel();
    await _ws.close();

    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save recording')),
      );
      setState(() => _state = _PracticeState.idle);
      return;
    }

    setState(() => _state = _PracticeState.processing);
    await _submitPractice(file);
  }

  Future<void> _submitPractice(File audioFile) async {
    try {
      final result = await PracticeApiService.submitPractice(
        audioFile,
        widget.mistakeWords,
        widget.originalSessionId,
        mode: widget.mode,
      );

      final strugglingWords = result.stillStruggling
          .map((w) => (w['word'] as String).toLowerCase())
          .toSet();

      for (final w in _liveWords) {
        final cleanWord = w.text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        if (strugglingWords.contains(cleanWord)) {
          w.status = WordStatus.error;
        } else if (w.status != WordStatus.pending) {
          w.status = WordStatus.correct;
        } else {
          // Never judged live (e.g. word never reached) but backend has
          // no complaint about it — treat as a deletion.
          w.status = WordStatus.skipped;
        }
      }

      setState(() {
        _result = result;
        _state = _PracticeState.done;
      });
    } catch (e) {
      setState(() => _state = _PracticeState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _end() async {
    await _wsSub?.cancel();
    await _ws.close();
    await _rec.stopAndSaveWav();
    _stopwatch.stop();
    _timer?.cancel();
    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Mistakes'),
        backgroundColor: Colors.deepOrange,
        actions: [
          if (_state == _PracticeState.recording)
            TextButton.icon(
              onPressed: _end,
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 18),
              label: const Text('End', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _result != null ? _buildResultView() : _buildPracticeView(),
    );
  }

  Widget _buildPracticeView() {
    final spokenCount =
        _liveWords.where((w) => w.status != WordStatus.pending).length;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_state == _PracticeState.recording)
              SessionStatsBar(
                timerLabel: _formatDuration(_elapsed),
                wordsLabel: '$spokenCount / ${_liveWords.length} words',
                scoreLabel: '--',
                accentColor: Colors.deepOrange,
              ),
            if (_scriptLoadFailed)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Text('Practice script failed to load. Pull down to retry.')),
                ]),
              ),
            if (_practiceScript != null) ...[
              const Text('Practice Script:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: PronunciationWordDisplay(words: _liveWords),
              ),
            ],
            const SizedBox(height: 24),
            const Text('Words to Practice:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.mistakeWords.map((mw) =>
                MistakeWordChip(
                  word: mw.word,
                  errorType: mw.errorType,
                  score: mw.perWordScore,
                ),
              ).toList(),
            ),
            const SizedBox(height: 32),
            _buildBottomBar(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    switch (_state) {
      case _PracticeState.idle:
        return _btn(
          label: 'Start Recording',
          icon: Icons.mic_rounded,
          color: Colors.deepOrange,
          onTap: _startRecording,
        );
      case _PracticeState.recording:
        return _btn(
          label: 'Evaluate',
          icon: Icons.mic_rounded,
          color: Colors.deepOrange,
          onTap: _evaluate,
        );
      case _PracticeState.processing:
        return const Center(child: CircularProgressIndicator());
      case _PracticeState.done:
        return const SizedBox.shrink();
    }
  }

  Widget _btn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildResultView() {
    final result = _result!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(children: [
              Icon(Icons.celebration, color: Colors.green[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(result.message,
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.green[800],
                        fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(children: [
              Text(result.score.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 64, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              Text('${result.grade} — ${result.gradeLabel}',
                  style: const TextStyle(fontSize: 20)),
            ]),
          ),
          const SizedBox(height: 24),
          _buildProgressSection('Cleared', result.clearedWords, Colors.green, Icons.check_circle),
          _buildProgressSection('Improved', result.improvedWords, Colors.orange, Icons.trending_up),
          _buildProgressSection('Still Struggling', result.stillStruggling, Colors.red, Icons.warning),
          const SizedBox(height: 24),
          if (result.stillStruggling.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                final remaining = result.stillStruggling
                    .map((w) => MistakeWord(
                          word: w['word'],
                          errorType: w['error_type'],
                          severity: w['severity'],
                          perWordScore: w['current_score'],
                          refPhonemes: [],
                          predPhonemes: [],
                          explanation: '',
                        ))
                    .toList();

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PracticeSessionScreen(
                      mistakeWords: remaining,
                      originalSessionId: widget.originalSessionId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Practice Remaining Words'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(String title, List<dynamic> items, Color color, IconData icon) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text('$title (${items.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 8),
        ...items.map((item) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Text(item['word'][0].toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
            title: Text(item['word']),
            subtitle: item['improvement'] != null
                ? Text('Improved by ${item['improvement']} points')
                : null,
            trailing: Text('${item['current_score']?.toStringAsFixed(0) ?? 'N/A'}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ),
        )).toList(),
        const SizedBox(height: 16),
      ],
    );
  }
}