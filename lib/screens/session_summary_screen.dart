import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'active_session_screen.dart';
import 'practice_session_screen.dart';
import '../models/practice_models.dart';
import '../models/word_status.dart';   // ← DisplayWord, WordStatus live here
import '../config.dart';

class SessionSummaryScreen extends StatelessWidget {
  final List<DisplayWord> words;
  final double sessionScore;
  final String script;
  final String sessionTitle;
  final String originalSessionId;
  final String? recordingUrl;

  // ── official backend stats ──
  final double? wordAccuracy;
  final int? correctWords;
  final int? wrongWords;
  final int? totalWords;
  final Map<String, dynamic>? stats;

  // ── Focus Script returned by /api/analyze/ for this session ──
  // (same object the Dashboard's Focus Script card shows). When it is
  // null/empty the Practice Mistakes button fetches the latest one instead.
  final Map<String, dynamic>? focusScript;

  const SessionSummaryScreen({
    super.key,
    required this.words,
    required this.sessionScore,
    required this.script,
    this.sessionTitle = 'Practice',
    this.originalSessionId = '',
    this.recordingUrl,
    this.wordAccuracy,
    this.correctWords,
    this.wrongWords,
    this.totalWords,
    this.stats,
    this.focusScript,
  });

  @override
  Widget build(BuildContext context) {
    // ── Use backend stats when available, otherwise fall back to local ──
    // (The backend decides whether 'minor' reads count as correct; the local
    // fallback below mirrors its default, pipeline.MINOR_COUNTS_AS_CORRECT.)
    final correctCount = correctWords ??
        words.where((w) =>
            w.status == WordStatus.correct ||
            w.status == WordStatus.accent ||
            w.status == WordStatus.minor).length;
    final errorCount = wrongWords ??
        words
            .where((w) =>
                w.status == WordStatus.error ||
                w.status == WordStatus.skipped)
            .length;
    final totalCount = totalWords ?? words.length;
    final displayScore = wordAccuracy ?? sessionScore;
    final grade = _getGrade(displayScore);
    final gradeColor = _gradeColor(displayScore);

    // Hard errors + skipped words: these are the real "Errors".
    // 'accent' (forgiven pronunciation variant) is not a mistake.
    // 'minor' (close-but-not-exact) is shown separately below as
    // "Almost there" in soft amber, so the header "Errors" count and the
    // Errors list always agree.
    final errors = words
        .where((w) =>
            w.status == WordStatus.error ||
            w.status == WordStatus.skipped)
        .toList();
    final almostThere =
        words.where((w) => w.status == WordStatus.minor).toList();

    // Build severity breakdown from error types
    final severityBreakdown = <String, int>{};
    for (final e in errors) {
      final type = (e.type ?? 'unknown').toLowerCase();
      severityBreakdown[type] = (severityBreakdown[type] ?? 0) + 1;
    }

    String? mostCommonError;
    int maxCount = 0;
    severityBreakdown.forEach((type, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommonError = type;
      }
    });

    final topMistakes = errors
        .map((e) => {
              'word': e.text,
              'error_type': e.type ?? 'error',
              'severity':
                  e.score != null ? (100 - e.score!).round().clamp(1, 10) : 5,
              'per_word_score': e.score ?? 0.0,
              'ref_phonemes': <String>[],
              'pred_phonemes': <String>[],
              'explanation': e.tip ?? '',
              'audio_path': e.audioPath,
            })
        .toList();

    // Prefer backend mistake_summary if we have it
    final backendMistakeSummary =
        stats?['mistake_summary'] as Map<String, dynamic>?;
    final mistakeSummary = MistakeSummary(
      mistakeCount: backendMistakeSummary?['mistake_count'] ?? errors.length,
      offerPractice:
          backendMistakeSummary?['offer_practice'] ?? errors.isNotEmpty,
      severityBreakdown: Map<String, int>.from(
          backendMistakeSummary?['severity_breakdown'] ?? severityBreakdown),
      mostCommonError:
          backendMistakeSummary?['most_common_error'] ?? mostCommonError,
      words: List<String>.from(backendMistakeSummary?['words'] ??
          errors.map((e) => e.text).toList()),
      topMistakes: List<Map<String, dynamic>>.from(
          backendMistakeSummary?['top_mistakes'] ?? topMistakes),
    );

    // Practice Mistakes is offered when there are real errors, or when the
    // backend itself reports practiceable mistakes (e.g. if it was
    // configured to include minor slips).
    final backendMistakeCount =
        (backendMistakeSummary?['mistake_count'] as num?)?.toInt() ?? 0;
    final canPractice = errors.isNotEmpty || backendMistakeCount > 0;

    // Words the "Correct" button cycles through, one per tap: the error
    // words first; only if there are none, the 'almost there' words.
    final pronunciationItems =
        _pronunciationItems(errors.isNotEmpty ? errors : almostThere);

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        title: const Text("Session Summary"),
        backgroundColor: const Color.fromARGB(255, 207, 235, 238),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Score card ────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brandBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                Text(grade, style: TextStyle(fontSize: 52, color: gradeColor)),
                const SizedBox(height: 4),
                Text("${displayScore.toStringAsFixed(1)}%",
                    style: const TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _scoreItem(
                        "✓  $correctCount", "Correct", Colors.greenAccent),
                    _scoreItem("✗  $errorCount", "Errors", Colors.redAccent),
                    _scoreItem("$totalCount", "Total", Colors.white70),
                  ],
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Recording Playback Card ───────────────────
            if (recordingUrl != null && recordingUrl!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.softBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Hear Yourself",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandBlue)),
                    const SizedBox(height: 4),
                    const Text(
                        "Play your recording, then tap Correct to hear each error word, one per tap",
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _AudioPlayButton(
                            label: "My Recording",
                            icon: Icons.mic,
                            audioUrl: AppConfig.mediaUrl(recordingUrl),
                            color: AppColors.brandBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CorrectPronunciationButton(
                            items: pronunciationItems,
                            color: AppColors.brandOlive,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            if (recordingUrl != null && recordingUrl!.isNotEmpty)
              const SizedBox(height: 24),

            // ── Errors list ───────────────────────────────
            if (errors.isNotEmpty) ...[
              const Text("Errors Detected",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandBlue)),
              const SizedBox(height: 12),
              ...errors.map(_errorCard),
            ],

            // ── Almost there (minor slips) ────────────────
            if (almostThere.isNotEmpty) ...[
              if (errors.isNotEmpty) const SizedBox(height: 12),
              const Text("Almost there",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandBlue)),
              const SizedBox(height: 4),
              const Text("Close reads with a small slip — worth a second look.",
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              ...almostThere.map(_errorCard),
            ],

            if (errors.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        almostThere.isEmpty
                            ? "Perfect pronunciation! No errors detected."
                            : "No pronunciation errors — just a few small slips to polish.",
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ]),
              ),

            const SizedBox(height: 32),

            // ── Action buttons ────────────────────────────
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActiveSessionScreen(
                          scriptText: script, sessionTitle: "Retry Session"),
                    ),
                  ),
                  icon: const Icon(Icons.replay),
                  label: const Text("Retry"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.brandBlue),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (_) => false),
                  icon: const Icon(Icons.home),
                  label: const Text("Home"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // ── Practice Mistakes Button ──────────────────
            if (canPractice)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startPracticeSession(
                      context, [...errors, ...almostThere]),
                  icon: const Icon(Icons.school),
                  label: const Text('Practice Mistakes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOlive,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Unique (by word) error words that have pronunciation audio, in reading order.
  List<_PronunciationItem> _pronunciationItems(List<DisplayWord> ws) {
    final seen = <String>{};
    final items = <_PronunciationItem>[];
    for (final w in ws) {
      final url = AppConfig.mediaUrl(w.audioPath);
      if (url == null || url.isEmpty) continue;
      if (!seen.add(w.text)) continue;
      items.add(_PronunciationItem(w.text, url));
    }
    return items;
  }

  /// One word card. 'minor' slips get softer amber styling instead of red —
  /// they're flagged for a second look, but visually distinct from a hard
  /// error/omission/substitution so the severity actually reads as different,
  /// not just internally scored differently.
  Widget _errorCard(DisplayWord e) {
    final isMinor = e.status == WordStatus.minor;
    final cardBorder = isMinor ? const Color(0xFFFFD9A8) : Colors.red.shade100;
    final chipBg = isMinor ? const Color(0xFFFFE9D6) : Colors.red.shade50;
    final chipText = isMinor ? const Color(0xFFB35900) : Colors.red.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.text,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: chipText)),
                const SizedBox(width: 4),
                PronunciationAudioButton(
                  audioUrl: AppConfig.mediaUrl(e.audioPath),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((e.type ?? 'error').toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1)),
                Text("Score: ${(e.score ?? 0).toStringAsFixed(0)}%",
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSlate)),
                if (e.tip != null)
                  Text(e.tip!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreItem(String value, String label, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
    ]);
  }

  String _getGrade(double score) {
    if (score >= 90) return "A+";
    if (score >= 80) return "A";
    if (score >= 70) return "B";
    if (score >= 60) return "C";
    return "D";
  }

  Color _gradeColor(double score) {
    if (score >= 80) return Colors.greenAccent;
    if (score >= 60) return Colors.yellowAccent;
    return Colors.redAccent;
  }


  /// Practice Mistakes → opens the same Focus Script the Dashboard shows.
  ///
  /// 1. Uses the focus script that came back with this session's analysis
  ///    (`focusScript`, no extra request).
  /// 2. If that is missing, asks the backend for the latest one
  ///    (getLatestFocusScript — exactly what the Dashboard calls).
  /// 3. If there is still none (nothing generated yet, network error, empty
  ///    script) it falls back to the old word-by-word PracticeSessionScreen
  ///    so the button never dead-ends.
  /// Pulls the full Focus Script map out of a candidate value, or null.
  static Map<String, dynamic>? _asValidFocusScriptMap(dynamic focusScript) {
    if (focusScript is Map) {
      final text = focusScript['script_text'];
      if (text is String && text.trim().isNotEmpty) {
        return Map<String, dynamic>.from(focusScript);
      }
    }
    return null;
  }

  Future<void> _startPracticeSession(
      BuildContext context, List<DisplayWord> errorWords) async {
    Map<String, dynamic>? focusMap = _asValidFocusScriptMap(focusScript);

    if (focusMap == null) {
      final rootNavigator = Navigator.of(context, rootNavigator: true);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      try {
        final data = await ApiService.getLatestFocusScript();
        focusMap = _asValidFocusScriptMap(data['focus_script']);
      } catch (e) {
        debugPrint('Focus script fetch failed: $e');
      }

      if (rootNavigator.canPop()) rootNavigator.pop();
      if (!context.mounted) return;
    }

    // ── Preferred path: the session's Focus Script ──
    // FIX: now passes focusScriptId + focusScriptWords through, so
    // ActiveSessionScreen can call completeFocusScript() once this
    // practice run finishes — previously the script was opened with no
    // id at all, so it never got marked completed and History always
    // showed it as pending regardless of what was actually practiced.
    if (focusMap != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveSessionScreen(
            scriptText: focusMap!['script_text'] as String,
            sessionTitle: 'Focus Script',
            focusScriptId: (focusMap['id'] as num?)?.toInt(),
            focusScriptWords:
                List<String>.from(focusMap['source_words'] ?? []),
          ),
        ),
      );
      return;
    }

    // ── Fallback: previous per-word practice flow ──
    final mistakeWords = errorWords
        .map((e) => MistakeWord(
              word: e.text,
              errorType: e.type ?? 'error',
              severity:
                  e.score != null ? (100 - e.score!).round().clamp(1, 10) : 5,
              perWordScore: e.score ?? 0.0,
              refPhonemes: [],
              predPhonemes: [],
              explanation: e.tip ?? '',
              audioPath: e.audioPath,
            ))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PracticeSessionScreen(
          mistakeWords: mistakeWords,
          originalSessionId: originalSessionId.isNotEmpty
              ? originalSessionId
              : DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      ),
    );
  }
}
// ═══════════════════════════════════════════════════════════
// Audio widgets
//
// NOTE on just_audio: `await player.play()` only completes when playback
// ENDS (or is paused/stopped). The old code set `_isPlaying = true` after
// that await, so the button never showed "playing" — and tapping it again
// just restarted the clip — until the whole recording had finished. These
// widgets instead drive their state from `playerStateStream` and never
// await play().
// ═══════════════════════════════════════════════════════════

/// Small speaker button next to an error word (tap = play, tap again = stop).
class PronunciationAudioButton extends StatefulWidget {
  final String? audioUrl;
  const PronunciationAudioButton({super.key, this.audioUrl});

  @override
  State<PronunciationAudioButton> createState() =>
      _PronunciationAudioButtonState();
}

class _PronunciationAudioButtonState extends State<PronunciationAudioButton> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _sub;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _sub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final completed = state.processingState == ProcessingState.completed;
      final loading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      setState(() {
        _isPlaying = state.playing && !completed;
        _isLoading = loading;
      });
      if (completed) {
        _player.pause();
        _player.seek(Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio not available')),
      );
      return;
    }

    try {
      if (_isPlaying) {
        await _player.pause();
        return;
      }
      if (!_loaded) {
        await _player.setUrl(widget.audioUrl!);
        _loaded = true;
      }
      unawaited(_player.play());
    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to play audio')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) {
      return const Icon(Icons.volume_off, color: AppColors.textFaint, size: 18);
    }

    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandBlue,
                ),
              )
            : Icon(
                _isPlaying ? Icons.pause : Icons.volume_up_outlined,
                color: AppColors.brandBlue,
                size: 18,
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// "My Recording" — play / pause / resume
// ═══════════════════════════════════════════════════════════
class _AudioPlayButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final String? audioUrl;
  final Color color;

  const _AudioPlayButton({
    required this.label,
    required this.icon,
    this.audioUrl,
    required this.color,
  });

  @override
  State<_AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends State<_AudioPlayButton> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _sub;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _sub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final completed = state.processingState == ProcessingState.completed;
      final loading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      setState(() {
        _isPlaying = state.playing && !completed;
        _isLoading = loading;
      });
      if (completed) {
        // Back to the start, paused, so the next tap replays from 0.
        _player.pause();
        _player.seek(Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) return;

    try {
      if (_isPlaying) {
        // Pause immediately; a later tap resumes from the same position.
        await _player.pause();
        return;
      }
      if (!_loaded) {
        await _player.setUrl(widget.audioUrl!);
        _loaded = true;
      }
      // Do NOT await: play() completes only when playback ends.
      unawaited(_player.play());
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAudio =
        widget.audioUrl != null && widget.audioUrl!.isNotEmpty;

    return ElevatedButton.icon(
      onPressed: hasAudio ? _toggle : null,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              _isPlaying ? Icons.pause : widget.icon,
              size: 18,
            ),
      label: Text(_isPlaying ? 'Pause' : widget.label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// "Correct" — each tap plays the NEXT error word's pronunciation
// ═══════════════════════════════════════════════════════════
class _PronunciationItem {
  final String word;
  final String url;
  const _PronunciationItem(this.word, this.url);
}

class _CorrectPronunciationButton extends StatefulWidget {
  final List<_PronunciationItem> items;
  final Color color;

  const _CorrectPronunciationButton({
    required this.items,
    required this.color,
  });

  @override
  State<_CorrectPronunciationButton> createState() =>
      _CorrectPronunciationButtonState();
}

class _CorrectPronunciationButtonState
    extends State<_CorrectPronunciationButton> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _sub;
  int _next = 0;        // index the next tap will play
  int? _current;        // index most recently started
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final completed = state.processingState == ProcessingState.completed;
      final loading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      setState(() {
        _isPlaying = state.playing && !completed;
        _isLoading = loading;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    final items = widget.items;
    if (items.isEmpty) return;

    final idx = _next % items.length;
    final item = items[idx];
    // Advance first, so rapid taps always move forward through the list
    // and wrap back to the first word after the last.
    _next = (idx + 1) % items.length;
    setState(() => _current = idx);

    try {
      await _player.stop(); // cut off the previous word, if still playing
      await _player.setUrl(item.url);
      unawaited(_player.play()); // never await: completes when playback ends
    } catch (e) {
      debugPrint('Pronunciation playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play "${item.word}"')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final hasAudio = items.isNotEmpty;

    String label = 'Correct';
    if (_current != null && _current! < items.length) {
      label = '${items[_current!].word} (${_current! + 1}/${items.length})';
    }

    return ElevatedButton.icon(
      onPressed: hasAudio ? _onTap : null,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(_isPlaying ? Icons.volume_up : Icons.record_voice_over,
              size: 18),
      label: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}