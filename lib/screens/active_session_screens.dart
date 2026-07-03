// lib/screens/active_session_screen.dart — full rewrite

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/recording_service.dart';
import '../services/api_service.dart';

enum WordStatus { pending, correct, error }
enum SessionState { idle, recording, processing, done }

class WordResult {
  final String word;
  final WordStatus status;
  final double score;
  final String type;
  final String? explanation;

  const WordResult({
    required this.word,
    this.status = WordStatus.pending,
    this.score  = 100.0,
    this.type   = 'pending',
    this.explanation,
  });

  WordResult update({WordStatus? status, double? score,
      String? type, String? explanation}) {
    return WordResult(
      word:        word,
      status:      status      ?? this.status,
      score:       score       ?? this.score,
      type:        type        ?? this.type,
      explanation: explanation ?? this.explanation,
    );
  }
}

class ActiveSessionScreen extends StatefulWidget {
  final String scriptText;
  final String sessionTitle;

  const ActiveSessionScreen({
    super.key,
    required this.scriptText,
    this.sessionTitle = 'Practice Session',
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionState();
}

class _ActiveSessionState extends State<ActiveSessionScreen> {

  final RecordingService _rec    = RecordingService();
  final AudioPlayer      _player = AudioPlayer();

  SessionState     _state     = SessionState.idle;
  List<WordResult> _words     = [];
  double           _score     = 0;
  String           _grade     = '';
  List<dynamic>    _feedback  = [];
  String?          _errorMsg;
  Duration         _elapsed   = Duration.zero;
  late Stopwatch   _stopwatch;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _words = widget.scriptText.toLowerCase().trim().split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => WordResult(word: w.replaceAll(RegExp(r'[^\w]'), '')))
        .toList();
  }

  // ── Start Recording ───────────────────────────────────
  Future<void> _startRecording() async {
    final ok = await _rec.hasPermission();
    if (!ok) {
      setState(() => _errorMsg = 'Microphone permission denied');
      return;
    }
    await _rec.startRecording();
    _stopwatch.reset();
    _stopwatch.start();

    // Update timer display every second
    _startTimer();

    setState(() {
      _state    = SessionState.recording;
      _errorMsg = null;
      // Reset words to pending on retry
      _words = _words.map((w) => WordResult(word: w.word)).toList();
      _feedback = [];
      _score    = 0;
      _grade    = '';
    });
  }

  // ── Stop and Evaluate ─────────────────────────────────
  Future<void> _evaluate() async {
    _stopwatch.stop();
    final file = await _rec.stopRecording();

    if (file == null) {
      setState(() => _errorMsg = 'Recording failed. Please try again.');
      return;
    }

    setState(() => _state = SessionState.processing);

    try {
      final result = await ApiService.analyzeAudio(
        file,
        widget.scriptText,
      );

      final wordList = (result['words'] as List?) ?? [];
      final feedback = (result['feedback'] as List?) ?? [];
      final score    = (result['score'] as num?)?.toDouble() ?? 0.0;
      final grade    = result['grade']?.toString() ?? '';

      // Map results to word list
      final Map<String, dynamic> wordMap = {};
      for (final w in wordList) {
        wordMap[w['word'].toString().toLowerCase()] = w;
      }

      setState(() {
        _score    = score;
        _grade    = grade;
        _feedback = feedback;
        _state    = SessionState.done;
        _words    = _words.map((wr) {
          final r = wordMap[wr.word];
          if (r == null) return wr;
          return wr.update(
            status: r['type'] == 'correct'
                ? WordStatus.correct
                : WordStatus.error,
            score: (r['per_word_score'] as num?)?.toDouble() ?? 0.0,
            type:  r['type'],
            explanation: r['explanation'],
          );
        }).toList();
      });

    } catch (e) {
      setState(() {
        _errorMsg = 'Analysis failed. Check your connection and try again.';
        _state    = SessionState.idle;
      });
    } finally {
      file.delete();
    }
  }

  // ── Timer ─────────────────────────────────────────────
  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_state != SessionState.recording) return false;
      setState(() => _elapsed = _stopwatch.elapsed);
      return true;
    });
  }

  String get _timerText {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Play audio feedback ───────────────────────────────
  Future<void> _playAudio(String audioPath) async {
    try {
      // audioPath is a relative server path e.g. /media/feedback/word.mp3
      final url = 'http://10.0.2.2:8000$audioPath';
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      print('Audio playback error: $e');
    }
  }

  // ── Colors ────────────────────────────────────────────
  Color _bgColor(WordStatus s) {
    switch (s) {
      case WordStatus.correct: return const Color(0xFFDCFCE7);
      case WordStatus.error:   return const Color(0xFFFEE2E2);
      case WordStatus.pending: return const Color(0xFFF1F5F9);
    }
  }

  Color _textColor(WordStatus s) {
    switch (s) {
      case WordStatus.correct: return const Color(0xFF166534);
      case WordStatus.error:   return const Color(0xFF991B1B);
      case WordStatus.pending: return const Color(0xFF475569);
    }
  }

  Color _gradeColor(double s) {
    if (s >= 85) return Colors.green;
    if (s >= 65) return Colors.orange;
    return Colors.red;
  }

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.sessionTitle),
        backgroundColor: const Color(0xFF1A3A6B),
        foregroundColor: Colors.white,
      ),
      body: Column(children: [

        // ── Status bar ──────────────────────────────────
        _buildStatusBar(),

        // ── Script area ─────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Instruction
                Text(
                  _state == SessionState.idle
                      ? 'Press Start Recording then read the script below'
                      : _state == SessionState.recording
                          ? 'Read this aloud — press Evaluate when done'
                          : _state == SessionState.processing
                              ? 'Analyzing your pronunciation...'
                              : 'Results — tap any red word for details',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),

                // Script words
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: _words.map((wr) => _wordChip(wr)).toList(),
                ),

                const SizedBox(height: 24),

                // Score display after evaluation
                if (_state == SessionState.done) ...[
                  _buildScoreCard(),
                  const SizedBox(height: 20),
                  if (_feedback.isNotEmpty) _buildFeedbackList(),
                ],

                // Error message
                if (_errorMsg != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade600, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMsg!,
                          style: TextStyle(color: Colors.red.shade700))),
                    ]),
                  ),

                const SizedBox(height: 100), // padding above buttons
              ],
            ),
          ),
        ),

        // ── Bottom action buttons ────────────────────────
        _buildBottomBar(),
      ]),
    );
  }

  // ── Status bar ────────────────────────────────────────
  Widget _buildStatusBar() {
    if (_state == SessionState.idle) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: _state == SessionState.recording
          ? const Color(0xFF1A3A6B)
          : _state == SessionState.processing
              ? Colors.orange.shade700
              : Colors.green.shade700,
      child: Row(children: [
        if (_state == SessionState.recording)
          const Icon(Icons.fiber_manual_record,
              color: Colors.redAccent, size: 16),
        if (_state == SessionState.processing)
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          ),
        if (_state == SessionState.done)
          const Icon(Icons.check_circle, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(
          _state == SessionState.recording
              ? 'Recording — $_timerText'
              : _state == SessionState.processing
                  ? 'Analyzing pronunciation...'
                  : 'Evaluation complete',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ]),
    );
  }

  // ── Word chip ─────────────────────────────────────────
  Widget _wordChip(WordResult wr) {
    return GestureDetector(
      onTap: wr.status == WordStatus.error && wr.explanation != null
          ? () => _showWordDetail(wr)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _bgColor(wr.status),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: wr.status == WordStatus.pending
                ? const Color(0xFFCBD5E1)
                : Colors.transparent,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(wr.word,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _textColor(wr.status),
              )),
          if (wr.status == WordStatus.error) ...[
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 14,
                color: Colors.red.shade400),
          ],
        ]),
      ),
    );
  }

  void _showWordDetail(WordResult wr) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(wr.word,
                  style: TextStyle(fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700)),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(wr.type.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11, letterSpacing: 1,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold)),
              Text('Score: ${wr.score.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 14,
                      color: Color(0xFF475569))),
            ]),
          ]),
          const SizedBox(height: 16),
          if (wr.explanation != null)
            Text(wr.explanation!,
                style: const TextStyle(fontSize: 15,
                    color: Color(0xFF334155), height: 1.5)),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Score card ────────────────────────────────────────
  Widget _buildScoreCard() {
    final correct = _words.where((w) => w.status == WordStatus.correct).length;
    final errors  = _words.where((w) => w.status == WordStatus.error).length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A6B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_grade,
              style: TextStyle(fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: _gradeColor(_score))),
          Text('${_score.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 22,
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
        const Spacer(),
        Column(children: [
          _scorePill('✓  $correct', Colors.greenAccent),
          const SizedBox(height: 8),
          _scorePill('✗  $errors', Colors.redAccent),
        ]),
      ]),
    );
  }

  Widget _scorePill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(color: color,
              fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  // ── Feedback list ─────────────────────────────────────
  Widget _buildFeedbackList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Corrections',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: Color(0xFF1A3A6B))),
        const SizedBox(height: 10),
        ..._feedback.map((f) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade100),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.record_voice_over,
                color: Colors.orange.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(f['word'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(f['explanation'] ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF64748B))),
              ]),
            ),
            if (f['audio_path'] != null)
              IconButton(
                icon: const Icon(Icons.volume_up),
                color: const Color(0xFF1A3A6B),
                onPressed: () => _playAudio(f['audio_path']),
              ),
          ]),
        )),
      ],
    );
  }

  // ── Bottom action bar ─────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10, offset: const Offset(0, -4),
        )],
      ),
      child: Row(children: [

        // IDLE STATE — single Start button
        if (_state == SessionState.idle)
          Expanded(
            child: _actionButton(
              label: 'Start Recording',
              icon: Icons.mic,
              color: const Color(0xFF1A3A6B),
              onTap: _startRecording,
            ),
          ),

        // RECORDING STATE — Evaluate button + Cancel
        if (_state == SessionState.recording) ...[
          Expanded(
            flex: 2,
            child: _actionButton(
              label: 'Evaluate',
              icon: Icons.analytics,
              color: const Color(0xFF0F6E56),
              onTap: _evaluate,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionButton(
              label: 'Cancel',
              icon: Icons.close,
              color: Colors.grey.shade400,
              onTap: () async {
                await _rec.stopRecording();
                setState(() => _state = SessionState.idle);
              },
            ),
          ),
        ],

        // PROCESSING STATE — disabled spinner button
        if (_state == SessionState.processing)
          Expanded(
            child: _actionButton(
              label: 'Analyzing...',
              icon: Icons.hourglass_empty,
              color: Colors.grey.shade400,
              onTap: null,  // disabled
            ),
          ),

        // DONE STATE — Retry + Next
        if (_state == SessionState.done) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF1A3A6B)),
                foregroundColor: const Color(0xFF1A3A6B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionButton(
              label: 'Next Script',
              icon: Icons.arrow_forward,
              color: const Color(0xFF1A3A6B),
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 15)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  @override
  void dispose() {
    _rec.dispose();
    _player.dispose();
    super.dispose();
  }
}