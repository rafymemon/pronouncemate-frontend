import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'active_session_screen.dart';
import 'practice_session_screen.dart';
import '../models/practice_models.dart';
import '../models/word_status.dart';
import '../config.dart';


class SessionSummaryScreen extends StatefulWidget {
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
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  bool _showAllMistakes = false;

  /// Colors for the error-type donut. These sit inside the same
  /// blue / amber / red family the app already uses so the chart
  /// reads as part of the existing design, not a new palette.
  static const _chartColors = [
    Color(0xFFEF4444), // substitution — red
    Color(0xFFF59E0B), // omission — amber
    Color(0xFF3B82F6), // insertion — blue
    Color(0xFF8B5CF6), // stress — purple
    Color(0xFF10B981), // other — green
  ];

  @override
  Widget build(BuildContext context) {
    // ── Use backend stats when available, otherwise fall back to local ──
    // (The backend decides whether 'minor' reads count as correct; the local
    // fallback below mirrors its default, pipeline.MINOR_COUNTS_AS_CORRECT.)
    final correctCount = widget.correctWords ??
        widget.words.where((w) =>
            w.status == WordStatus.correct ||
            w.status == WordStatus.accent ||
            w.status == WordStatus.minor).length;
    final errorCount = widget.wrongWords ??
        widget.words
            .where((w) =>
                w.status == WordStatus.error ||
                w.status == WordStatus.skipped)
            .length;
    final totalCount = widget.totalWords ?? widget.words.length;
    final displayScore = widget.wordAccuracy ?? widget.sessionScore;
    final grade = _getGrade(displayScore);
    final gradeColor = _gradeColor(displayScore);

    // Hard errors + skipped words: these are the real "Errors".
    // 'accent' (forgiven pronunciation variant) is not a mistake.
    // 'minor' (close-but-not-exact) is shown separately below as
    // "Almost there" in soft amber, so the header "Errors" count and the
    // Errors list always agree.
    final errors = widget.words
        .where((w) =>
            w.status == WordStatus.error ||
            w.status == WordStatus.skipped)
        .toList();
    final almostThere =
        widget.words.where((w) => w.status == WordStatus.minor).toList();

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
        widget.stats?['mistake_summary'] as Map<String, dynamic>?;
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

    // "Recurrent" = words that were missed more than once in this session.
    final wordFreq = <String, int>{};
    for (final e in errors) {
      wordFreq[e.text] = (wordFreq[e.text] ?? 0) + 1;
    }
    final recurrentCount = wordFreq.values.where((c) => c > 1).length;

    // Words the "Correct" button cycles through, one per tap: the error
    // words first; only if there are none, the 'almost there' words.
    final pronunciationItems =
        _pronunciationItems(errors.isNotEmpty ? errors : almostThere);

    // Donut segments (sorted, colored round-robin from the chart palette).
    final sortedTypes = mistakeSummary.severityBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final segments = <_ChartSegment>[];
    for (var i = 0; i < sortedTypes.length; i++) {
      segments.add(_ChartSegment(
        label: _prettyType(sortedTypes[i].key),
        value: sortedTypes[i].value,
        color: _chartColors[i % _chartColors.length],
      ));
    }

    final visibleMistakes =
        _showAllMistakes ? errors : errors.take(5).toList();

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        title: const Text("Session Summary"),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Score card with animated ring ─────────────────
            _FadeIn(
              index: 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.softBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(children: [
                  _ScoreRing(
                    percent: displayScore,
                    grade: grade,
                    gradeColor: gradeColor,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: gradeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text("Grade  $grade",
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: gradeColor)),
                  ),
                ]),
              ),
            ),

            // ── Stats row overlapping the score card ──────────
            _FadeIn(
              index: 1,
              child: Transform.translate(
                offset: const Offset(0, -26),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statTile(
                        icon: Icons.check_rounded,
                        iconBg: AppColors.successLight,
                        iconColor: AppColors.success,
                        value: '$correctCount',
                        label: 'Correct',
                      ),
                      _statTile(
                        icon: Icons.close_rounded,
                        iconBg: AppColors.errorLight,
                        iconColor: AppColors.error,
                        value: '$errorCount',
                        label: 'Errors',
                      ),
                      _statTile(
                        icon: Icons.format_list_numbered_rounded,
                        iconBg: AppColors.surfaceVariant,
                        iconColor: AppColors.textSlate,
                        value: '$totalCount',
                        label: 'Total',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // ── Recording playback ────────────────────────────
            if (widget.recordingUrl != null &&
                widget.recordingUrl!.isNotEmpty)
              _FadeIn(
                index: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.softBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.graphic_eq_rounded,
                              color: AppColors.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Your Recording",
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent)),
                              SizedBox(height: 2),
                              Text(
                                  "Play your recording, then tap Correct to hear each error word, one per tap",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _AudioPlayButton(
                              label: "My Recording",
                              icon: Icons.mic,
                              audioUrl:
                                  AppConfig.mediaUrl(widget.recordingUrl),
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CorrectPronunciationButton(
                              items: pronunciationItems,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            if (widget.recordingUrl != null &&
                widget.recordingUrl!.isNotEmpty)
              const SizedBox(height: 16),

            // ── Mistake overview ──────────────────────────────
            if (errors.isNotEmpty) ...[
              _FadeIn(
                index: 3,
                child: _sectionTitle("Mistake Summary",
                    "Key insights from your session"),
              ),
              const SizedBox(height: 12),
              _FadeIn(
                index: 4,
                child: Row(children: [
                  _insightChip(
                      '${mistakeSummary.mistakeCount}',
                      'Total\nMistakes',
                      const Color(0xFFFEE2E2),
                      const Color(0xFFDC2626)),
                  const SizedBox(width: 10),
                  _insightChip(
                      '${mistakeSummary.words.length}',
                      'Practice\nSuggested',
                      const Color(0xFFDBEAFE),
                      const Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  _insightChip(
                      '$recurrentCount',
                      'Recurrent\nErrors',
                      const Color(0xFFFEF3C7),
                      const Color(0xFFB45309)),
                ]),
              ),
              const SizedBox(height: 12),
              _FadeIn(
                index: 5,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.softBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Error Types",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent)),
                      const SizedBox(height: 14),
                      Row(children: [
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: Stack(children: [
                            CustomPaint(
                              size: const Size(96, 96),
                              painter: _DonutPainter(segments),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${mistakeSummary.mistakeCount}',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textSlate)),
                                  const Text("Mistakes",
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: segments
                                .map((s) => _legendRow(
                                      s,
                                      mistakeSummary.mistakeCount,
                                    ))
                                .toList(),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (mistakeSummary.mostCommonError != null)
                _FadeIn(
                  index: 6,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lightbulb_outline_rounded,
                            color: AppColors.warning, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Most Common Error",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warning)),
                            const SizedBox(height: 2),
                            Text(
                                _prettyType(
                                    mistakeSummary.mostCommonError!),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSlate)),
                            Text(
                                "$maxCount ${maxCount == 1 ? 'occurrence' : 'occurrences'}",
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
            ],

            // ── Top mistakes ──────────────────────────────────
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 20),
              _FadeIn(
                index: 7,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _sectionTitle("Top Mistakes",
                        "Review and practice these words"),
                    const Spacer(),
                    Text(
                        "${errors.length} ${errors.length == 1 ? 'word' : 'words'}",
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FadeIn(
                index: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.softBorder),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < visibleMistakes.length; i++)
                        _mistakeTile(visibleMistakes[i], i + 1,
                            isLast: i == visibleMistakes.length - 1),
                    ],
                  ),
                ),
              ),
              if (errors.length > 5) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _showAllMistakes = !_showAllMistakes),
                    icon: Icon(
                        _showAllMistakes
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18),
                    label: Text(
                        _showAllMistakes
                            ? "Show Less"
                            : "View All ${errors.length} Mistakes",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent),
                  ),
                ),
              ],
            ],

            // ── Almost there (minor slips) ────────────────────
            if (almostThere.isNotEmpty) ...[
              const SizedBox(height: 8),
              _FadeIn(
                index: 9,
                child: _sectionTitle("Almost there",
                    "Close reads with a small slip — worth a second look."),
              ),
              const SizedBox(height: 12),
              _FadeIn(
                index: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.softBorder),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < almostThere.length; i++)
                        _mistakeTile(almostThere[i], null,
                            isLast: i == almostThere.length - 1),
                    ],
                  ),
                ),
              ),
            ],

            // ── Perfect session state ─────────────────────────
            if (errors.isEmpty)
              _FadeIn(
                index: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 28),
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
              ),

            const SizedBox(height: 28),

            // ── Actions ───────────────────────────────────────
            _FadeIn(
              index: 11,
              child: Column(children: [
                if (canPractice)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _startPracticeSession(
                          context, [...errors, ...almostThere]),
                      icon: const Icon(Icons.school_rounded),
                      label: const Text('Continue Practice',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (canPractice) const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActiveSessionScreen(
                              scriptText: widget.script,
                              sessionTitle: "Retry Session"),
                        ),
                      ),
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text("Retry"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.accent),
                        foregroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context, '/home', (_) => false),
                      icon: const Icon(Icons.home_rounded, size: 18),
                      label: const Text("Back to Home"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI pieces ─────────────────────────────────────────────

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

  Widget _sectionTitle(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.accent)),
      const SizedBox(height: 2),
      Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
    ]);
  }

  Widget _statTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration:
            BoxDecoration(color: iconBg, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      const SizedBox(height: 8),
      Text(value,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSlate)),
      Text(label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
    ]);
  }

  Widget _insightChip(
      String value, String label, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: fg)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: fg.withOpacity(0.85))),
        ]),
      ),
    );
  }

  Widget _legendRow(_ChartSegment s, int total) {
    final pct = total > 0 ? ((s.value / total) * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(s.label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSlate)),
        ),
        Text("${s.value}  ($pct%)",
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]),
    );
  }

  /// Ranked mistake row. `rank` is null for the soft "almost there" rows.
  Widget _mistakeTile(DisplayWord e, int? rank, {bool isLast = false}) {
    final isMinor = e.status == WordStatus.minor;
    final score = e.score ?? 0;
    final chipColor =
        isMinor ? const Color(0xFFFFE9D6) : _scoreChipColor(score);
    final chipText =
        isMinor ? const Color(0xFFB35900) : _scoreChipTextColor(score);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          if (rank != null) ...[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: chipColor,
                shape: BoxShape.circle,
              ),
              child: Text('$rank',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: chipText)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.text,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSlate)),
                const SizedBox(height: 2),
                Text(_prettyType(e.type ?? 'error').toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        letterSpacing: 1)),
                if (e.tip != null && e.tip!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(e.tip!,
                        style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${score.toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: chipText)),
          ),
          const SizedBox(width: 4),
          PronunciationAudioButton(
            audioUrl: AppConfig.mediaUrl(e.audioPath),
          ),
        ]),
      ),
      if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14),
    ]);
  }

  Color _scoreChipColor(double score) {
    if (score < 70) return AppColors.errorLight;
    if (score < 85) return AppColors.warningLight;
    return AppColors.successLight;
  }

  Color _scoreChipTextColor(double score) {
    if (score < 70) return AppColors.error;
    if (score < 85) return AppColors.warning;
    return AppColors.success;
  }

  String _prettyType(String type) {
    if (type.isEmpty) return 'Other';
    return type[0].toUpperCase() + type.substring(1);
  }

  String _getGrade(double score) {
    if (score >= 90) return "A+";
    if (score >= 80) return "A";
    if (score >= 70) return "B";
    if (score >= 60) return "C";
    return "D";
  }

  Color _gradeColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
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
    Map<String, dynamic>? focusMap =
        _asValidFocusScriptMap(widget.focusScript);

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
          originalSessionId: widget.originalSessionId.isNotEmpty
              ? widget.originalSessionId
              : DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Score ring — animated circular progress with % in the center
// ═══════════════════════════════════════════════════════════
class _ScoreRing extends StatelessWidget {
  final double percent;
  final String grade;
  final Color gradeColor;

  const _ScoreRing({
    required this.percent,
    required this.grade,
    required this.gradeColor,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped / 100),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return SizedBox(
          width: 170,
          height: 170,
          child: CustomPaint(
            painter: _RingPainter(progress: v, color: gradeColor),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text("${(v * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                const Text("Overall Score",
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 10;
    const stroke = 12.0;

    final bg = Paint()
      ..color = AppColors.softBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2,
        false,
        bg);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        fg);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ═══════════════════════════════════════════════════════════
// Donut chart for error types
// ═══════════════════════════════════════════════════════════
class _ChartSegment {
  final String label;
  final int value;
  final Color color;
  _ChartSegment(
      {required this.label, required this.value, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_ChartSegment> segments;
  _DonutPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    const stroke = 17.0;
    final r = radius - stroke / 2;

    final bg = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, r, bg);

    final total = segments.fold<int>(0, (a, s) => a + s.value);
    if (total == 0) return;

    const gap = 0.07; // small gap between segments
    double start = -math.pi / 2;
    final useGap = segments.length > 1;

    for (final s in segments) {
      final sweep = (s.value / total) * math.pi * 2;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          start,
          useGap ? sweep - gap : sweep,
          false,
          paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

// ═══════════════════════════════════════════════════════════
// Staggered fade/slide entrance (matches the storyboard reveal)
// ═══════════════════════════════════════════════════════════
class _FadeIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _FadeIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 110)),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
            offset: Offset(0, 14 * (1 - v)), child: child),
      ),
      child: child,
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
                  color: AppColors.accent,
                ),
              )
            : Icon(
                _isPlaying ? Icons.pause : Icons.volume_up_outlined,
                color: AppColors.accent,
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
  int _next = 0; // index the next tap will play
  int? _current; // index most recently started
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
