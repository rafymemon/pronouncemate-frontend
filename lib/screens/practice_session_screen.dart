// screens/practice_session_screen.dart
// Practice flow for mistake words, with live word-by-word coloring
// while the user is still speaking (via WebSocket), reconciled against
// the accurate backend pipeline once recording stops.

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

  bool _isRecording = false;
  bool _isProcessing = false;
  PracticeResult? _result;
  String? _practiceScript;
  List<DisplayWord> _liveWords = [];

  StreamSubscription? _wsSub;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Duration _elapsed = Duration.zero;

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
    if (response['success']) {
      setState(() {
        _practiceScript = response['practice_script'];
        _liveWords = _practiceScript!
            .split(RegExp(r'\s+'))
            .where((w) => w.trim().isNotEmpty)
            .map((w) => DisplayWord(w))
            .toList();
      });
    }
  }

  Future<void> _startRecording() async {
  if (_practiceScript == null || _practiceScript!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Practice script not loaded yet — please wait or go back and retry')),
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
      _isRecording = true;
      for (final w in _liveWords) {
        w.status = WordStatus.pending;
      }
      _elapsed = Duration.zero;
    });

    _stopwatch
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() => _elapsed = _stopwatch.elapsed);
    });

    await _ws.connect(_practiceScript ?? '');
    _wsSub = _ws.wordResults.listen((result) {
      if (result.wordIndex < 0 || result.wordIndex >= _liveWords.length) return;
      setState(() {
        _liveWords[result.wordIndex].status =
            result.correct ? WordStatus.correct : WordStatus.error;
      });
    });

    final stream = await _rec.startLiveStream();
    stream.listen((chunk) => _ws.sendAudioChunk(chunk));
  }

  Future<void> _stopAndSubmit() async {
    if (!_isRecording) return;

    _stopwatch.stop();
    _timer?.cancel();
    setState(() => _isRecording = false);

    final file = await _rec.stopAndSaveWav();
    await _wsSub?.cancel();
    await _ws.close();

    if (file != null) {
      _submitPractice(file);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save recording')),
      );
    }
  }

  Future<void> _submitPractice(File audioFile) async {
    setState(() => _isProcessing = true);

    try {
      final result = await PracticeApiService.submitPractice(
        audioFile,
        widget.mistakeWords,
        widget.originalSessionId,
        mode: widget.mode,
      );

      // Reconcile provisional colors with the accurate backend pipeline.
      final strugglingWords = result.stillStruggling
          .map((w) => (w['word'] as String).toLowerCase())
          .toSet();

      for (final w in _liveWords) {
        final cleanWord = w.text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        if (w.status != WordStatus.pending) {
          w.status = strugglingWords.contains(cleanWord)
              ? WordStatus.error
              : WordStatus.correct;
        }
      }

      setState(() {
        _result = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
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
            if (_isRecording || _result != null)
              SessionStatsBar(
                timerLabel: _formatDuration(_elapsed),
                wordsLabel: '$spokenCount / ${_liveWords.length} words',
                scoreLabel: '--',
                accentColor: Colors.deepOrange,
              ),
            if (_practiceScript != null) ...[
              const Text(
                'Practice Script:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
            const Text(
              'Words to Practice:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
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
            Center(
              child: GestureDetector(
                onTapDown: (_) => _startRecording(),
                onTapUp: (_) => _stopAndSubmit(),
                onTapCancel: () => _stopAndSubmit(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isRecording ? 100 : 80,
                  height: _isRecording ? 100 : 80,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : Colors.deepOrange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? Colors.red : Colors.deepOrange)
                            .withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 24),
          ],
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
            child: Row(
              children: [
                Icon(Icons.celebration, color: Colors.green[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.message,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  result.score.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                Text(
                  '${result.grade} — ${result.gradeLabel}',
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
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
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              '$title (${items.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Text(
                item['word'][0].toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(item['word']),
            subtitle: item['improvement'] != null
                ? Text('Improved by ${item['improvement']} points')
                : null,
            trailing: Text(
              '${item['current_score']?.toStringAsFixed(0) ?? 'N/A'}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        )).toList(),
        const SizedBox(height: 16),
      ],
    );
  }
}