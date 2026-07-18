import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'active_session_screen.dart';
import '../widgets/practice_mistake_button.dart';
import '../providers/practice_provider.dart';
import 'practice_session_screen.dart';
import '../models/practice_models.dart';
import '../config.dart';  // ← ADDED: central config

class SessionSummaryScreen extends StatelessWidget {
  final List<WordResult> words;
  final double sessionScore;
  final String script;
  final String sessionTitle;
  final String originalSessionId;
  final String? recordingUrl;

  const SessionSummaryScreen({
    super.key,
    required this.words,
    required this.sessionScore,
    required this.script,
    this.sessionTitle = 'Practice',
    this.originalSessionId = '',
    this.recordingUrl,
  });

  @override
  Widget build(BuildContext context) {
    final correct  = words.where((w) => w.status == WordStatus.correct).length;
    final errors   = words.where((w) => w.status == WordStatus.error).toList();
    final grade    = _getGrade(sessionScore);
    final gradeColor = _gradeColor(sessionScore);

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

    final topMistakes = errors.map((e) => {
      'word': e.text,
      'error_type': e.type ?? 'error',
      'severity': e.score != null ? (100 - e.score!).round().clamp(1, 10) : 5,
      'per_word_score': e.score ?? 0.0,
      'ref_phonemes': <String>[],
      'pred_phonemes': <String>[],
      'explanation': e.tip ?? '',
      'audio_path': e.audioPath,
    }).toList();

    final mistakeSummary = MistakeSummary(
      mistakeCount: errors.length,
      offerPractice: errors.isNotEmpty,
      severityBreakdown: severityBreakdown,
      mostCommonError: mostCommonError,
      words: errors.map((e) => e.text).toList(),
      topMistakes: topMistakes,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Session Summary"),
        backgroundColor: const Color(0xFF1A3A6B),
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
                color: const Color(0xFF1A3A6B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                Text(grade,
                    style: TextStyle(
                        fontSize: 52, fontWeight: FontWeight.bold,
                        color: gradeColor)),
                const SizedBox(height: 4),
                Text("${sessionScore.toStringAsFixed(1)}%",
                    style: const TextStyle(
                        fontSize: 28, color: Colors.white,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _scoreItem("✓  $correct", "Correct", Colors.greenAccent),
                    _scoreItem("✗  ${errors.length}", "Errors", Colors.redAccent),
                    _scoreItem("${words.length}", "Total", Colors.white70),
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
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Hear Yourself",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A3A6B))),
                    const SizedBox(height: 4),
                    const Text("Compare your recording with the correct pronunciation",
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _AudioPlayButton(
                            label: "My Recording",
                            icon: Icons.mic,
                            audioUrl: AppConfig.mediaUrl(recordingUrl),  // ← USE CONFIG
                            color: const Color(0xFF1A3A6B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AudioPlayButton(
                            label: "Correct",
                            icon: Icons.record_voice_over,
                            audioUrl: errors.isNotEmpty
                                ? AppConfig.mediaUrl(errors.first.audioPath)  // ← USE CONFIG
                                : null,
                            color: const Color(0xFF6B7C2A),
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                      color: Color(0xFF1A3A6B))),
              const SizedBox(height: 12),
              ...errors.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e.text,
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700)),
                          const SizedBox(width: 4),
                          PronunciationAudioButton(
                            audioUrl: AppConfig.mediaUrl(e.audioPath),  // ← USE CONFIG
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
                                  fontSize: 11, color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1)),
                          Text("Score: ${(e.score ?? 0).toStringAsFixed(0)}%",
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF475569))),
                          if (e.tip != null)
                            Text(e.tip!,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],

            if (errors.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
                  const SizedBox(width: 12),
                  const Text("Perfect pronunciation! No errors detected.",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
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
                    side: const BorderSide(color: Color(0xFF1A3A6B)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/home', (_) => false),
                  icon: const Icon(Icons.home),
                  label: const Text("Home"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A3A6B),
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
            if (errors.isNotEmpty)
              PracticeMistakesButton(
                mistakeSummary: mistakeSummary,
                onPressed: () => _startPracticeSession(context, errors),
              ),
          ],
        ),
      ),
    );
  }

  // REMOVED: old _fullAudioUrl() — now uses AppConfig.mediaUrl()

  Widget _scoreItem(String value, String label, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 20,
          fontWeight: FontWeight.bold, color: color)),
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

  void _startPracticeSession(BuildContext context, List<WordResult> errorWords) {
    final mistakeWords = errorWords.map((e) => MistakeWord(
      word: e.text,
      errorType: e.type ?? 'error',
      severity: e.score != null ? (100 - e.score!).round().clamp(1, 10) : 5,
      perWordScore: e.score ?? 0.0,
      refPhonemes: [],
      predPhonemes: [],
      explanation: e.tip ?? '',
      audioPath: e.audioPath,
    )).toList();

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
  State<PronunciationAudioButton> createState() => _PronunciationAudioButtonState();
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
      return const Icon(Icons.volume_off, color: Color(0xFFCBD5E1), size: 18);
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
                  color: Color(0xFF1A3A6B),
                ),
              )
            : Icon(
                _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
                color: const Color(0xFF1A3A6B),
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
    final bool hasAudio = widget.audioUrl != null && widget.audioUrl!.isNotEmpty;

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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}