// lib/screens/active_session_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/recording_service.dart';
import '../services/api_service.dart';
import 'session_summary_screen.dart';

enum WordStatus { pending, correct, error }

class WordResult {
  final String text;
  WordStatus status;
  String? tip;
  double? score;
  String? type;
  String? audioPath;

  WordResult(this.text) : status = WordStatus.pending;
}

enum _SessionState { idle, recording, processing, done }

class ActiveSessionScreen extends StatefulWidget {
  final String scriptText;
  final String sessionTitle;

  const ActiveSessionScreen({
    Key? key,
    required this.scriptText,
    this.sessionTitle = 'Practice',
  }) : super(key: key);

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionState();
}

class _ActiveSessionState extends State<ActiveSessionScreen> {

  static const _olive    = Color(0xFF6B7C2A);
  static const _bg       = Color(0xFFD6E9EB);
  static const _cardBg   = Color(0xFFFFFFFF);
  static const _textDark = Color(0xFF1A2A1A);
  static const _textGrey = Color(0xFF6B7B7B);

  final RecordingService _rec    = RecordingService();
  final AudioPlayer      _player = AudioPlayer();

  _SessionState _state    = _SessionState.idle;
  late List<WordResult> _words;
  int      _correctCount  = 0;
  double   _score         = 0;
  String   _grade         = '';
  String?  _latestFeedback;
  String?  _latestFeedbackWord;
  String?  _audioPath;
  Duration _elapsed        = Duration.zero;
  late Stopwatch _stopwatch;
  late String _sessionId;  // ← ADDED: unique ID for this session

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';  // ← ADDED
    _words = widget.scriptText
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .map((w) => WordResult(w.replaceAll(RegExp(r"[^\w']"), '').toLowerCase()))
        .toList();
  }

  Future<void> _startRecording() async {
    final ok = await _rec.hasPermission();
    if (!ok) {
      _snack('Microphone permission required', error: true); return;
    }
    await _rec.start();
    _stopwatch.reset();
    _stopwatch.start();
    _startTimer();
    setState(() {
      _state           = _SessionState.recording;
      _latestFeedback  = null;
      _audioPath       = null;
      _correctCount    = 0;
      _score           = 0;
      _grade           = '';
      for (final w in _words) {
        w.status = WordStatus.pending;
        w.audioPath = null;
      }
    });
  }

  Future<void> _evaluate() async {
    _stopwatch.stop();
    final file = await _rec.stop();
    if (file == null) {
      _snack('Recording failed', error: true); return;
    }
    setState(() => _state = _SessionState.processing);

    try {
      final result = await ApiService.analyzeAudio(file, widget.scriptText);

      final wordList = (result['words'] as List?) ?? [];
      final feedback = (result['feedback'] as List?) ?? [];
      final score    = (result['score'] as num?)?.toDouble() ?? 0.0;
      final grade    = result['grade']?.toString() ?? '';

      final Map<String, dynamic> wordMap = {};
      for (final w in wordList) {
        wordMap[w['word'].toString().toLowerCase()] = w;
      }

      int correct = 0;
      for (final w in _words) {
        final r = wordMap[w.text];
        if (r == null) continue;
        final type = r['type']?.toString() ?? 'correct';
        w.status = type == 'correct' ? WordStatus.correct : WordStatus.error;
        w.type = type;
        if (type == 'correct') correct++;
        w.tip = r['explanation']?.toString();
        w.score = (r['score'] as num?)?.toDouble();
        w.audioPath = r['audio_path']?.toString();
      }

      String? fbText;
      String? fbWord;
      String? fbAudio;
      if (feedback.isNotEmpty) {
        final f = feedback.first;
        fbWord  = f['word']?.toString();
        fbText  = f['explanation']?.toString();
        fbAudio = f['audio_path']?.toString();
      }

      setState(() {
        _state           = _SessionState.done;
        _score           = score;
        _grade           = grade;
        _correctCount    = correct;
        _latestFeedback  = fbText;
        _latestFeedbackWord = fbWord;
        _audioPath       = fbAudio;
      });

      _navigateToSummary();

    } catch (e) {
      setState(() => _state = _SessionState.idle);
      _snack('Analysis failed. Try again.', error: true);
    } finally {
      file.delete();
    }
  }

  // ── FIXED: Pass originalSessionId to SessionSummaryScreen ──
  void _navigateToSummary() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SessionSummaryScreen(
          words: _words,
          sessionScore: _score,
          script: widget.scriptText,
          sessionTitle: widget.sessionTitle,
          originalSessionId: _sessionId,  // ← ADDED
        ),
      ),
    );
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_state != _SessionState.recording) return false;
      if (!mounted) return false;
      setState(() => _elapsed = _stopwatch.elapsed);
      return true;
    });
  }

  String get _timerStr {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _playAudio() async {
    if (_audioPath == null) return;
    try {
      final url = 'http://10.0.2.2:8000$_audioPath';
      await _player.setUrl(url);
      await _player.play();
    } catch (_) {}
  }

  void _end() {
    _rec.stop();
    _stopwatch.stop();
    Navigator.pop(context);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  Color _wordBg(WordStatus s) {
    switch (s) {
      case WordStatus.correct: return const Color(0xFFD4EDDA);
      case WordStatus.error:   return const Color(0xFFFFE0E0);
      case WordStatus.pending: return Colors.transparent;
    }
  }

  Color _wordText(WordStatus s) {
    switch (s) {
      case WordStatus.correct: return const Color(0xFF2E7D32);
      case WordStatus.error:   return const Color(0xFFC62828);
      case WordStatus.pending: return _textDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(widget.sessionTitle,
            style: const TextStyle(
                color: _textDark, fontWeight: FontWeight.bold,
                fontSize: 17)),
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textDark),
        actions: [
          if (_state == _SessionState.recording ||
              _state == _SessionState.done)
            TextButton.icon(
              onPressed: _end,
              icon: Icon(
                _state == _SessionState.recording
                    ? Icons.stop_circle_outlined
                    : Icons.close_rounded,
                color: Colors.red.shade400, size: 18,
              ),
              label: Text(
                _state == _SessionState.recording ? 'End' : 'Close',
                style: TextStyle(color: Colors.red.shade400,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Column(children: [

        if (_state == _SessionState.recording ||
            _state == _SessionState.done)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statItem(Icons.timer_outlined,
                    _timerStr, const Color(0xFF2196F3)),
                _statDivider(),
                _statItem(Icons.text_fields_rounded,
                    '${_correctCount} / ${_words.length} words',
                    _olive),
                _statDivider(),
                _statItem(Icons.analytics_outlined,
                    _state == _SessionState.done
                        ? '${_score.toStringAsFixed(0)}%'
                        : '--',
                    _olive),
              ],
            ),
          ),

        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.sessionTitle,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold,
                        color: _textDark)),
                const Divider(height: 20),

                Expanded(
                  child: SingleChildScrollView(
                    child: _buildScriptText(),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_latestFeedback != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEEE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFCCCC)),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade400, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _latestFeedback!,
                  style: TextStyle(
                      fontSize: 13, color: Colors.red.shade700,
                      fontWeight: FontWeight.w500, height: 1.4),
                ),
              ),
              if (_audioPath != null)
                IconButton(
                  icon: Icon(Icons.volume_up_rounded,
                      color: _olive, size: 22),
                  onPressed: _playAudio,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ]),
          ),

        _buildBottomBar(),

        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildScriptText() {
    return RichText(
      text: TextSpan(
        children: _words.map((w) {
          final hasTip = w.status == WordStatus.error && w.tip != null;
          return WidgetSpan(
            child: GestureDetector(
              onTap: hasTip ? () => _showWordTip(w) : null,
              child: Container(
                margin: const EdgeInsets.only(right: 6, bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _wordBg(w.status),
                  borderRadius: BorderRadius.circular(6),
                  border: w.status == WordStatus.error
                      ? Border(bottom: BorderSide(
                          color: Colors.red.shade400, width: 2))
                      : null,
                ),
                child: Text(w.text,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                      color: _wordText(w.status),
                      fontFamily: 'serif',
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showWordTip(WordResult w) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(w.text,
                style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700)),
          ),
          const SizedBox(height: 14),
          Text(w.tip ?? '',
              style: const TextStyle(fontSize: 15,
                  color: _textGrey, height: 1.55)),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [

        if (_state == _SessionState.idle) ...[
          Expanded(
            child: _btn(
              label: 'Start Recording',
              icon: Icons.mic_rounded,
              color: _olive,
              onTap: _startRecording,
            ),
          ),
        ],

        if (_state == _SessionState.recording) ...[
          Expanded(
            flex: 1,
            child: OutlinedButton.icon(
              onPressed: _end,
              icon: Icon(Icons.stop_circle_outlined,
                  color: Colors.red.shade400, size: 18),
              label: Text('End',
                  style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.red.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _btn(
              label: 'Evaluate',
              icon: Icons.mic_rounded,
              color: _olive,
              onTap: _evaluate,
            ),
          ),
        ],

        if (_state == _SessionState.processing)
          Expanded(child: _btn(
            label: 'Analyzing...',
            icon: Icons.hourglass_empty,
            color: Colors.grey.shade400,
            onTap: null,
          )),

        if (_state == _SessionState.done) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: _olive),
                foregroundColor: _olive,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _btn(
              label: 'Done',
              icon: Icons.check_rounded,
              color: _olive,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _btn({
    required String   label,
    required IconData icon,
    required Color    color,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _statItem(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: color)),
    ]);
  }

  Widget _statDivider() {
    return Container(
        width: 1, height: 20, color: Colors.grey.shade200);
  }

  @override
  void dispose() {
    _rec.dispose();
    _player.dispose();
    super.dispose();
  }
}