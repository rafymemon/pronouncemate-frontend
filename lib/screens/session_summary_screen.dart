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

    final backendMistakeCount =
        (backendMistakeSummary?['mistake_count'] as num?)?.toInt() ?? 0;
    final canPractice = errors.isNotEmpty || backendMistakeCount > 0;

    // "Recurrent" = words that were missed more than once in this session.
    final wordFreq = <String, int>{};
    for (final e in errors) {
      wordFreq[e.text] = (wordFreq[e.text] ?? 0) + 1;
    }
    final recurrentCount = wordFreq.values.where((c) => c > 1).length;

    // Word whose pronunciation audio is used for the "Correct" comparison.
    final DisplayWord? audioSource = errors.isNotEmpty
        ? errors.first
        : (almostThere.isNotEmpty ? almostThere.first : null);

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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1–2. Score card with animated ring ─────────────
            _FadeIn(
              index: 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
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
                      color: Colors.white.withOpacity(0.16),
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

            // ── Stats row overlapping the score card ───────────
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
                        iconBg: const Color(0xFFDCFCE7),
                        iconColor: const Color(0xFF16A34A),
                        value: '$correctCount',
                        label: 'Correct',
                      ),
                      _statTile(
                        icon: Icons.close_rounded,
                        iconBg: const Color(0xFFFEE2E2),
                        iconColor: const Color(0xFFDC2626),
                        value: '$errorCount',
                        label: 'Errors',
                      ),
                      _statTile(
                        icon: Icons.format_list_numbered_rounded,
                        iconBg: const Color(0xFFF1F5F9),
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

            // ── 3. Recording playback ──────────────────────────
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
                            color: AppColors.brandBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.graphic_eq_rounded,
                              color: AppColors.brandBlue, size: 20),
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
                                      color: AppColors.brandBlue)),
                              SizedBox(height: 2),
                              Text(
                                  "Listen to how you performed — compare with the correct pronunciation",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _RecordingPlayer(
                        audioUrl: AppConfig.mediaUrl(widget.recordingUrl),
                        compareUrl: audioSource != null
                            ? AppConfig.mediaUrl(audioSource.audioPath)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

            if (widget.recordingUrl != null &&
                widget.recordingUrl!.isNotEmpty)
              const SizedBox(height: 16),

            // ── 4. Mistake overview ────────────────────────────
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
                              color: AppColors.brandBlue)),
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
                      color: const Color(0xFFFFF7E8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFE1B3)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFEDCC),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lightbulb_outline_rounded,
                            color: Color(0xFFB45309), size: 20),
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
                                    color: Color(0xFFB45309))),
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

            // ── 5. Top mistakes ────────────────────────────────
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
                    Text("${errors.length} ${errors.length == 1 ? 'word' : 'words'}",
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
                        foregroundColor: AppColors.brandBlue),
                  ),
                ),
              ],
            ],

            // ── Almost there (minor slips) ─────────────────────
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

            // ── Perfect session state ──────────────────────────
            if (errors.isEmpty)
              _FadeIn(
                index: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
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
              ),

            const SizedBox(height: 28),

            // ── 7. Actions ─────────────────────────────────────
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
                        backgroundColor: AppColors.brandOlive,
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
                        side: const BorderSide(color: AppColors.brandBlue),
                        foregroundColor: AppColors.brandBlue,
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
                        backgroundColor: AppColors.brandBlue,
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

  Widget _sectionTitle(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.brandBlue)),
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
                Text(_prettyType(e.type ?? 'error'),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
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
                    fontSize: 12, fontWeight: FontWeight.bold, color: chipText)),
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
    if (score < 70) return const Color(0xFFFEE2E2);
    if (score < 85) return const Color(0xFFFEF3C7);
    return const Color(0xFFDCFCE7);
  }

  Color _scoreChipTextColor(double score) {
    if (score < 70) return const Color(0xFFDC2626);
    if (score < 85) return const Color(0xFFB45309);
    return const Color(0xFF16A34A);
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
    if (score >= 80) return Colors.greenAccent;
    if (score >= 60) return Colors.yellowAccent;
    return Colors.redAccent;
  }

  /// Practice Mistakes → opens the same Focus Script the Dashboard shows.
  /// (Logic unchanged from the previous screen.)
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
                        color: Colors.white)),
                const SizedBox(height: 2),
                const Text("Overall Score",
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
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
      ..color = Colors.white.withOpacity(0.18)
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
  _ChartSegment({required this.label, required this.value, required this.color});
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
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start,
          useGap ? sweep - gap : sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

// ═══════════════════════════════════════════════════════════
// Recording player — play/pause, progress, waveform, compare
// ═══════════════════════════════════════════════════════════
class _RecordingPlayer extends StatefulWidget {
  final String? audioUrl;
  final String? compareUrl;
  const _RecordingPlayer({this.audioUrl, this.compareUrl});

  @override
  State<_RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<_RecordingPlayer> {
  final AudioPlayer _player = AudioPlayer();
  final math.Random _rand = math.Random(11);

  late final List<double> _bars =
      List.generate(38, (_) => 5 + _rand.nextInt(22).toDouble());

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        _player.seek(Duration.zero);
      }
    });
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
        setState(() => _isPlaying = false);
        return;
      }
      if (_duration == Duration.zero) {
        setState(() => _isLoading = true);
        await _player.setUrl(widget.audioUrl!);
      }
      await _player.play();
      setState(() {
        _isLoading = false;
        _isPlaying = true;
      });
    } catch (e) {
      debugPrint('Playback error: $e');
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

  Future<void> _playCompare() async {
    if (widget.compareUrl == null || widget.compareUrl!.isEmpty) return;
    try {
      final compare = AudioPlayer();
      await compare.setUrl(widget.compareUrl!);
      await compare.play();
      compare.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) compare.dispose();
      });
    } catch (e) {
      debugPrint('Compare playback error: $e');
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hasAudio = widget.audioUrl != null && widget.audioUrl!.isNotEmpty;
    final hasCompare =
        widget.compareUrl != null && widget.compareUrl!.isNotEmpty;

    return Column(children: [
      Row(children: [
        GestureDetector(
          onTap: hasAudio && !_isLoading ? _toggle : null,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: hasAudio
                  ? AppColors.brandBlue
                  : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? _position;
              _position = pos;
              return StreamBuilder<Duration?>(
                stream: _player.durationStream,
                builder: (context, dSnap) {
                  final dur = dSnap.data ?? _duration;
                  _duration = dur ?? Duration.zero;
                  final totalMs = _duration.inMilliseconds;
                  final progress =
                      totalMs > 0 ? (pos.inMilliseconds / totalMs) : 0.0;
                  return Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                        Text(_fmt(_duration),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.brandBlue),
                      ),
                    ),
                  ]);
                },
              );
            },
          ),
        ),
        if (hasCompare) ...[
          const SizedBox(width: 10),
          Tooltip(
            message: "Hear the correct pronunciation",
            child: InkWell(
              onTap: _playCompare,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.brandOlive.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.record_voice_over_rounded,
                      color: AppColors.brandOlive, size: 16),
                  SizedBox(width: 4),
                  Text("Correct",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandOlive)),
                ]),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      // Decorative waveform (fills with progress while playing)
      SizedBox(
        height: 30,
        child: StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, snap) {
            final pos = snap.data ?? _position;
            final totalMs = _duration.inMilliseconds;
            final progress = totalMs > 0
                ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0)
                : 0.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < _bars.length; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: _bars[i],
                      decoration: BoxDecoration(
                        color: (i / _bars.length) <= progress
                            ? AppColors.brandBlue
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ]);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }
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
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
      ),
      child: child,
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
      return const Icon(Icons.volume_off,
          color: AppColors.textFaint, size: 18);
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
