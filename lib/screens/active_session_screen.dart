// lib/screens/active_session_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_theme.dart';
import '../services/recording_service.dart';
import '../services/api_service.dart';
import '../services/focus_api_service.dart';
import '../services/practice_websocket_service.dart';
import '../config.dart';
import '../models/word_status.dart';
import '../widgets/pronunciation_word_display.dart';
import '../widgets/session_stats_bar.dart';
import 'session_summary_screen.dart';
import 'focus_script_result_screen.dart';

enum _SessionState { idle, recording, processing, done }

class ActiveSessionScreen extends StatefulWidget {
  final String scriptText;
  final String sessionTitle;
  final String? scriptId;
  final int? focusScriptId;
  final List<String>? focusScriptWords;

  const ActiveSessionScreen({
    Key? key,
    required this.scriptText,
    this.scriptId,
    this.sessionTitle = 'Practice',
    this.focusScriptId,
    this.focusScriptWords,
  }) : super(key: key);

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionState();
}

class _ActiveSessionState extends State<ActiveSessionScreen> {
  Map<String, dynamic> _sessionStats = {};

  static const _olive = AppColors.brandOlive;
  static const _bg = AppColors.sessionBackground;
  static const _cardBg = AppColors.surface;
  static const _textDark = AppColors.textPrimary;
  static const _textGrey = AppColors.textSecondary;

  final RecordingService _rec = RecordingService();
  final AudioPlayer _player = AudioPlayer();
  final PracticeWebSocketService _ws = PracticeWebSocketService();

  _SessionState _state = _SessionState.idle;
  late List<DisplayWord> _words;
  int _correctCount = 0;
  double _score = 0;
  String? _latestFeedback;
  String? _audioPath;
  String? _recordingUrl;
  Duration _elapsed = Duration.zero;
  late Stopwatch _stopwatch;
  late String _sessionId;
  StreamSubscription? _wsSub;

  // ── Live In-Session Delta ──────────────────────────
  double? _historicalAvg;
  int _liveCorrect = 0;
  int _liveJudged = 0;
  static const _minRecordingSeconds = 3;

  // ── Focus Script mode ──────────────────────────────
  // Before/after comparison returned by the backend once the Focus Script
  // practice run has been evaluated.
  Map<String, dynamic>? _focusResult;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';
    _words = widget.scriptText
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .map((w) => DisplayWord(w.replaceAll(RegExp(r"[^\w']"), '').toLowerCase()))
        .toList();

    // Pre-highlight the Focus Script's error words so the user can see
    // them before practicing.
    final targets = (widget.focusScriptWords ?? [])
        .map((w) => w.toLowerCase().trim())
        .where((w) => w.isNotEmpty)
        .toSet();
    for (final w in _words) {
      if (targets.contains(w.text)) {
        w.isTarget = true;
        w.tip = 'This word was a recurring error — read it carefully.';
      }
    }
    if (widget.focusScriptId != null && targets.isNotEmpty) {
      _loadFocusBaseline();
    }

    _loadHistoricalAverage();
    _checkLevelUpPrompt();
  }

  /// Loads how each target word was wrong before and turns it into the
  /// tip shown when the user taps a highlighted word.
  Future<void> _loadFocusBaseline() async {
    final res = await FocusApiService.getFocusScript(widget.focusScriptId!);
    if (!mounted || res['error'] != null) return;

    final baseline = (res['baseline'] as List?) ?? [];
    final byWord = <String, Map<String, dynamic>>{};
    for (final b in baseline) {
      final m = Map<String, dynamic>.from(b as Map);
      final word = (m['word'] ?? '').toString().toLowerCase();
      if (word.isNotEmpty) byWord[word] = m;
    }

    setState(() {
      for (final w in _words) {
        if (!w.isTarget) continue;
        final b = byWord[w.text];
        if (b != null) w.tip = _baselineTip(b);
      }
    });
  }

  String _baselineTip(Map<String, dynamic> b) {
    final count = (b['error_count'] as num?)?.toInt() ?? 0;
    final type = b['error_type']?.toString() ?? '';
    const reasons = {
      'substitution': 'a sound was replaced',
      'omission': 'a sound was dropped',
      'insertion': 'an extra sound was added',
      'skipped': 'the word was skipped',
      'minor': 'a small slip',
    };
    final reason = reasons[type] ?? 'it was mispronounced';
    final times = count > 1 ? '$count times' : 'before';
    return 'You had trouble with this word $times — $reason. '
        'Read it slowly and clearly this time.';
  }

  Future<void> _checkLevelUpPrompt() async {
    final progression = await ApiService.getProgressionStatus();
    if (!mounted) return;
    if (progression['error'] != null) return;
    if (progression['eligible_for_promotion'] != true) return;

    final nextLevelLabel = {
      'beginner': 'Intermediate',
      'intermediate': 'Expert',
    }[progression['current_level']?.toString()];
    if (nextLevelLabel == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("You're ready to level up!"),
        content: Text(
          "You've met all the criteria for $nextLevelLabel. Want to move up before this session?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await ApiService.confirmPromotion();
              if (!mounted) return;
              if (result['promoted'] == true) {
                _snack('You leveled up to ${result['new_level']}!');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _olive,
              foregroundColor: Colors.white,
            ),
            child: const Text('Level Up'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadHistoricalAverage() async {
    final profile = await ApiService.getProfile();
    if (!mounted) return;
    final avg = (profile['avg_accuracy'] as num?)?.toDouble();
    if (avg != null && avg > 0) {
      setState(() => _historicalAvg = avg);
    }
  }

  Future<void> _startRecording() async {
    final ok = await _rec.hasPermission();
    if (!ok) {
      _snack('Microphone permission required', error: true);
      return;
    }

    setState(() {
      _state = _SessionState.recording;
      _latestFeedback = null;
      _audioPath = null;
      _recordingUrl = null;
      _correctCount = 0;
      _score = 0;
      _liveCorrect = 0;
      _liveJudged = 0;
      for (final w in _words) {
        w.status = WordStatus.pending;
        w.audioPath = null;
      }
    });

    _stopwatch.reset();
    _stopwatch.start();
    _startTimer();

    // Live layer: word-by-word coloring while speaking.
    await _ws.connect(widget.scriptText);
    _wsSub = _ws.wordResults.listen((result) {
      if (!mounted) return;
      if (result.wordIndex < 0 || result.wordIndex >= _words.length) return;
      print(
          '🎤 [UI] setState idx=${result.wordIndex} status=${result.status}'); // TEMP
      setState(() {
        switch (result.status) {
          case 'correct':
            _words[result.wordIndex].status = WordStatus.correct;
            break;
          case 'skipped':
            _words[result.wordIndex].status = WordStatus.skipped;
            break;
          default:
            _words[result.wordIndex].status = WordStatus.error;
        }
        // Recomputed from scratch each time (not incremented) so a word
        // whose status changes mid-stream is never double-counted.
        _liveJudged = _words.where((w) => w.status != WordStatus.pending).length;
        _liveCorrect = _words.where((w) => w.status == WordStatus.correct).length;
      });
    });

    final stream = await _rec.startLiveStream();
    stream.listen((chunk) => _ws.sendAudioChunk(chunk));
  }

  Future<void> _evaluate() async {
    if (_stopwatch.elapsed.inSeconds < _minRecordingSeconds) {
      _snack('Recording too short — try reading the full script.', error: true);
      return;
    }

    _stopwatch.stop();
    final file = await _rec.stopAndSaveWav();
    await _wsSub?.cancel();
    await _ws.close();

    if (file == null) {
      _snack('Recording failed', error: true);
      return;
    }
    setState(() => _state = _SessionState.processing);

    try {
      final result = await ApiService.analyzeAudio(file, widget.scriptText,
          scriptId: widget.scriptId);

      final stats = (result['stats'] as Map?)?.cast<String, dynamic>() ?? {};
      final wordList = (result['words'] as List?) ?? [];
      final feedback = (result['feedback'] as List?) ?? [];
      final score = (result['score'] as num?)?.toDouble() ?? 0.0;
      final grade = result['grade']?.toString() ?? '';

      final backendCorrect = (stats['correct_words'] as num?)?.toInt() ?? 0;
      final backendWrong = (stats['wrong_words'] as num?)?.toInt() ?? 0;
      final backendTotal = (stats['total_words'] as num?)?.toInt() ?? 0;
      final wordAccuracy =
          (stats['word_accuracy'] as num?)?.toDouble() ?? score;

      // The saved PracticeSession's database id (set by AnalyzeView).
      final serverSessionId = int.tryParse('${result['session_id']}');

      final Map<String, List<Map<String, dynamic>>> wordQueue = {};
      for (final w in wordList) {
        final key = w['word']?.toString().toLowerCase() ?? '';
        if (key.isNotEmpty) {
          wordQueue.putIfAbsent(key, () => []).add(w);
        }
      }

      int correct = 0;
      for (final w in _words) {
        final queue = wordQueue[w.text];
        if (queue == null || queue.isEmpty) {
          // Word never appeared in the transcript = deletion.
          w.status = WordStatus.skipped;
          w.type = 'skipped';
          continue;
        }
        final r = queue.removeAt(0);
        final type = r['type']?.toString() ?? 'correct';
        w.type = type;

        // Map every backend `type` to its own WordStatus tier instead of
        // collapsing everything non-'correct' into WordStatus.error.
        // 'accent' (forgiven Pakistani-accent variant) and 'minor'
        // (close-but-not-exact acoustic read) were previously both being
        // shown identically to a hard error — this was hiding both the
        // accent-tolerance feature's output AND the graded-score work
        // from the person actually using the app.
        switch (type) {
          case 'correct':
            w.status = WordStatus.correct;
            break;
          case 'accent':
            w.status = WordStatus.accent;
            break;
          case 'minor':
            w.status = WordStatus.minor;
            break;
          default:
            w.status = WordStatus.error;
        }

        // 'correct' and 'accent' both count toward the on-screen correct
        // tally — accent variants are, by design, not penalized. 'minor'
        // does NOT count as correct here, matching pipeline.py's
        // correct_count, which only includes ('correct', 'accent').
        if (type == 'correct' || type == 'accent') correct++;
        w.tip = r['explanation']?.toString();
        w.score = (r['per_word_score'] as num?)?.toDouble();
        w.audioPath = r['audio_path']?.toString();
      }

      // ── Focus Script: complete it and get the before/after result ──
      if (widget.focusScriptId != null) {
        Map<String, dynamic>? focusResult;

        // Preferred: the backend compares this session against the
        // original errors and returns a full per-word result.
        if (serverSessionId != null) {
          final res = await FocusApiService.completeWithSession(
            widget.focusScriptId!,
            sessionId: serverSessionId,
          );
          if (res['error'] == null && res['result'] is Map) {
            focusResult = Map<String, dynamic>.from(res['result'] as Map);
          }
        }

        // Fallback: old client-side error rate, so the script is still
        // marked complete even if the comparison request fails.
        if (focusResult == null &&
            widget.focusScriptWords != null &&
            widget.focusScriptWords!.isNotEmpty) {
          final targetSet =
              widget.focusScriptWords!.map((w) => w.toLowerCase()).toSet();
          final targetHits =
              _words.where((w) => targetSet.contains(w.text)).toList();

          if (targetHits.isNotEmpty) {
            final targetErrors = targetHits
                .where((w) =>
                    w.status == WordStatus.error ||
                    w.status == WordStatus.skipped)
                .length;
            final postErrorRate = (targetErrors / targetHits.length) * 100;
            try {
              await ApiService.completeFocusScript(
                widget.focusScriptId!,
                postErrorRate: postErrorRate,
              );
            } catch (_) {
              // Non-fatal — session results still display normally.
            }
          }
        }

        _focusResult = focusResult;
      }

      String? fbText;
      String? fbAudio;
      if (feedback.isNotEmpty) {
        final f = feedback.first;
        fbText = f['explanation']?.toString();
        fbAudio = f['audio_path']?.toString();
      }

      _recordingUrl = result['recording_url']?.toString();
      _sessionStats = {
        'word_accuracy': wordAccuracy,
        'correct_words': backendCorrect,
        'wrong_words': backendWrong,
        'total_words': backendTotal,
        'score': score,
        'grade': grade,
        'mistake_summary': result['mistake_summary'],
        // AnalyzeView already computes and attaches the session's
        // Focus Script so the "Practice Mistakes" button opens the exact
        // same script the Dashboard card shows.
        'focus_script': result['focus_script'],
      };

      setState(() {
        _state = _SessionState.done;
        _score = score;
        _correctCount = correct;
        _latestFeedback = fbText;
        _audioPath = fbAudio;
      });

      _navigateToSummary();
    } catch (e) {
      setState(() => _state = _SessionState.idle);
      _snack('Analysis failed. Try again.', error: true);
    }
  }

  void _navigateToSummary() {
    // Capture everything up front: the summary is built lazily (from the
    // Focus Script result screen), possibly after this screen is disposed.
    final words = _words;
    final score = _score;
    final stats = _sessionStats;
    final scriptText = widget.scriptText;
    final title = widget.sessionTitle;
    final originalSessionId = _sessionId;
    final recordingUrl = _recordingUrl;
    final focusResult = _focusResult;

    Widget buildSummary() => SessionSummaryScreen(
          words: words,
          sessionScore: score,
          wordAccuracy: (stats['word_accuracy'] as num?)?.toDouble() ?? score,
          correctWords: (stats['correct_words'] as num?)?.toInt(),
          wrongWords: (stats['wrong_words'] as num?)?.toInt(),
          totalWords: (stats['total_words'] as num?)?.toInt(),
          stats: stats,
          script: scriptText,
          sessionTitle: title,
          originalSessionId: originalSessionId,
          recordingUrl: recordingUrl,
          focusScript: stats['focus_script'] as Map<String, dynamic>?,
        );

    // Focus Script run → show the before/after results first.
    if (focusResult != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FocusScriptResultScreen(
            result: focusResult,
            sessionTitle: title,
            summaryBuilder: (_) => buildSummary(),
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => buildSummary()),
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
      final url = AppConfig.mediaUrl(_audioPath)!;
      await _player.setUrl(url);
      await _player.play();
    } catch (_) {}
  }

  Future<void> _end() async {
    await _wsSub?.cancel();
    await _ws.close();
    await _rec.stopAndSaveWav();
    _stopwatch.stop();
    if (mounted) Navigator.pop(context);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(widget.sessionTitle,
            style: const TextStyle(
                color: _textDark, fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textDark),
        actions: [
          if (_state == _SessionState.recording || _state == _SessionState.done)
            TextButton.icon(
              onPressed: _end,
              icon: Icon(
                _state == _SessionState.recording
                    ? Icons.stop_circle_outlined
                    : Icons.close_rounded,
                color: Colors.red.shade400,
                size: 18,
              ),
              label: Text(
                _state == _SessionState.recording ? 'End' : 'Close',
                style: TextStyle(
                    color: Colors.red.shade400, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Column(children: [
        if (_state == _SessionState.recording || _state == _SessionState.done)
          SessionStatsBar(
            timerLabel: _timerStr,
            wordsLabel: '${_correctCount} / ${_words.length} words',
            scoreLabel:
                _state == _SessionState.done ? '${_score.toStringAsFixed(0)}%' : '--',
            accentColor: _olive,
            cardColor: _cardBg,
          ),
        _buildLiveDeltaBadge(),
        _buildFocusBanner(),
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
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _textDark)),
                const Divider(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: PronunciationWordDisplay(
                      words: _words,
                      onWordTap: _showWordTip,
                      pendingTextColor: _textDark,
                      highlightTargets: _state == _SessionState.idle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_latestFeedback != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      fontSize: 13,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                      height: 1.4),
                ),
              ),
              if (_audioPath != null)
                IconButton(
                  icon: Icon(Icons.volume_up_rounded, color: _olive, size: 22),
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

  /// Shown above a Focus Script before recording starts.
  Widget _buildFocusBanner() {
    if (widget.focusScriptId == null || _state != _SessionState.idle) {
      return const SizedBox.shrink();
    }
    final count =
        _words.where((w) => w.isTarget).map((w) => w.text).toSet().length;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCCCC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_rounded, size: 18, color: Colors.red.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count error ${count == 1 ? 'word is' : 'words are'} highlighted in red. '
              'Tap one to see what went wrong before, then record and read the whole script.',
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showWordTip(DisplayWord w) {
    final Color chipBg;
    final Color chipText;
    final String fallbackTip;

    switch (w.status) {
      case WordStatus.skipped:
        chipBg = const Color(0xFFFFF3CD);
        chipText = const Color(0xFF856404);
        fallbackTip = 'This word was skipped — try including it next time.';
        break;
      case WordStatus.accent:
        chipBg = const Color(0xFFDCF3F1);
        chipText = const Color(0xFF1B7A72);
        fallbackTip =
            'This is a common regional pronunciation variation — it is not counted as an error.';
        break;
      case WordStatus.minor:
        chipBg = const Color(0xFFFFE9D6);
        chipText = const Color(0xFFB35900);
        fallbackTip =
            "You're very close on this one — just a small pronunciation slip.";
        break;
      default:
        chipBg = Colors.red.shade50;
        chipText = Colors.red.shade700;
        fallbackTip = '';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(w.text,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: chipText)),
              ),
              const SizedBox(height: 14),
              Text(
                  w.tip ?? fallbackTip,
                  style: const TextStyle(
                      fontSize: 15, color: _textGrey, height: 1.55)),
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
                      color: Colors.red.shade400, fontWeight: FontWeight.w600)),
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
          Expanded(
              child: _btn(
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
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLiveDeltaBadge() {
    if (_state != _SessionState.recording || _historicalAvg == null || _liveJudged < 3) {
      return const SizedBox.shrink();
    }
    final liveAccuracy = (_liveCorrect / _liveJudged) * 100;
    final delta = liveAccuracy - _historicalAvg!;
    final isAbove = delta >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isAbove ? const Color(0xFFDCFCE7) : const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAbove ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 16,
            color: isAbove ? const Color(0xFF16A34A) : const Color(0xFF856404),
          ),
          const SizedBox(width: 8),
          Text(
            isAbove
                ? '${delta.toStringAsFixed(0)}% above your average'
                : '${delta.abs().toStringAsFixed(0)}% below your average',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isAbove ? const Color(0xFF16A34A) : const Color(0xFF856404),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rec.dispose();
    _player.dispose();
    _ws.dispose();
    _wsSub?.cancel();
    super.dispose();
  }
}