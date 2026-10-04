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

    // Word whose pronunciation audio is used for the "Correct" button.
    final DisplayWord? audioSource = errors.isNotEmpty
        ? errors.first
        : (almostThere.isNotEmpty ? almostThere.first : null);

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
                        "Compare your recording with the correct pronunciation",
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
                          child: _AudioPlayButton(
                            label: "Correct",
                            icon: Icons.record_voice_over,
                            audioUrl: audioSource != null
                                ? AppConfig.mediaUrl(audioSource.audioPath)
                                : null,
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
// Audio Playback Button — for error word TTS
// ═══════════════════════════════════════════════════════════
class PronunciationAudioButton extends StatefulWidget {
  final String? audioUrl;
  const PronunciationAudioButton({super.key, this.audioUrl});

  @override
  State<PronunciationAudioButton> createState() =>
      _PronunciationAudioButtonState();
}

class _PronunciationAudioButtonState extends State<PronunciationAudioButton> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio not available')),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);
      await _player.setUrl(widget.audioUrl!);
      await _player.play();
      setState(() {
        _isLoading = false;
        _isPlaying = true;
      });

      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _isPlaying = false);
        }
      });
    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = false;
        });
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
      onTap: _isLoading ? null : _play,
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
                _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
                color: AppColors.brandBlue,
                size: 18,
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Full-width audio play button for Recording Playback
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
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) return;

    try {
      setState(() => _isLoading = true);
      await _player.setUrl(widget.audioUrl!);
      await _player.play();
      setState(() {
        _isLoading = false;
        _isPlaying = true;
      });

      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _isPlaying = false);
        }
      });
    } catch (e) {
      debugPrint('Playback error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAudio =
        widget.audioUrl != null && widget.audioUrl!.isNotEmpty;

    return ElevatedButton.icon(
      onPressed: hasAudio && !_isLoading ? _play : null,
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
              _isPlaying ? Icons.stop : widget.icon,
              size: 18,
            ),
      label: Text(widget.label,
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