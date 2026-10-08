// lib/screens/session_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../config.dart';
import '../services/stats_api_service.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════
// SHARED HELPERS (also used by stat_detail_screen.dart)
// ═══════════════════════════════════════════════════════

const List<String> _weekdayNames = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
];
const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

DateTime? parseApiDate(dynamic value) {
  if (value == null) return null;
  try {
    return DateTime.parse(value.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

/// "Mon, 5 Oct"
String formatShortDate(DateTime? d) {
  if (d == null) return '';
  return '${_weekdayNames[d.weekday - 1]}, ${d.day} ${_monthNames[d.month - 1]}';
}

/// "Mon, 5 Oct 2026 · 3:42 PM"
String formatSessionDateTime(DateTime? d) {
  if (d == null) return 'Unknown date';
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour < 12 ? 'AM' : 'PM';
  return '${formatShortDate(d)} ${d.year} · $hour:$minute $period';
}

String modeLabel(String? mode) {
  switch (mode) {
    case 'public_speaking':
      return 'Public Speaking';
    case 'daily_conversation':
      return 'Daily Conversation';
    case 'script_based':
      return 'Script-Based';
    default:
      return 'Practice';
  }
}

IconData modeIcon(String? mode) {
  switch (mode) {
    case 'public_speaking':
      return Icons.campaign_rounded;
    case 'daily_conversation':
      return Icons.chat_bubble_rounded;
    default:
      return Icons.description_rounded;
  }
}

Color scoreColor(num? score) {
  final s = score?.toDouble() ?? 0;
  if (s >= 80) return AppColors.success;
  if (s >= 60) return AppColors.accent;
  if (s >= 40) return AppColors.warning;
  return AppColors.error;
}

String errorTypeLabel(String? type) {
  switch (type) {
    case 'substitution':
      return 'Wrong sound';
    case 'omission':
      return 'Missing sound';
    case 'insertion':
      return 'Extra sound';
    case 'skipped':
      return 'Skipped word';
    case 'minor':
      return 'Minor slip';
    case 'accent':
      return 'Accent variation';
    case 'inserted':
      return 'Extra word';
    case 'correct':
      return 'Correct';
    default:
      return 'Mispronounced';
  }
}

class _WordStyle {
  final Color? background;
  final Color foreground;
  const _WordStyle(this.background, this.foreground);
}

_WordStyle _wordStyleFor(String type) {
  switch (type) {
    case 'correct':
      return const _WordStyle(null, AppColors.textPrimary);
    case 'accent':
      return const _WordStyle(Color(0xFFDCF3F1), Color(0xFF1B7A72));
    case 'minor':
      return const _WordStyle(Color(0xFFFFE9D6), Color(0xFFB35900));
    case 'skipped':
      return const _WordStyle(Color(0xFFFFF3CD), Color(0xFF856404));
    default:
      return _WordStyle(Colors.red.shade50, Colors.red.shade700);
  }
}

// ═══════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _d = {};

  final AudioPlayer _player = AudioPlayer();
  String? _playingKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await StatsApiService.getSessionDetail(widget.sessionId);
    if (!mounted) return;
    if (res['error'] != null) {
      setState(() {
        _error = res['error'].toString();
        _loading = false;
      });
      return;
    }
    setState(() {
      _d = res;
      _loading = false;
    });
  }

  // ── tiny parsing helpers ────────────────────────────
  List<Map<String, dynamic>> _maps(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  int? _int(dynamic v) =>
      v is num ? v.toInt() : (v == null ? null : int.tryParse(v.toString()));

  double? _dbl(dynamic v) =>
      v is num ? v.toDouble() : (v == null ? null : double.tryParse(v.toString()));

  String _type(Map<String, dynamic> w) => (w['type'] ?? 'correct').toString();

  String _phonemes(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).join(' ');
    if (v is String) return v;
    return '';
  }

  Future<void> _play(String? path, String key) async {
    if (path == null || path.isEmpty) return;
    try {
      if (_playingKey == key && _player.playing) {
        await _player.stop();
        if (mounted) setState(() => _playingKey = null);
        return;
      }
      final url = AppConfig.mediaUrl(path);
      if (url == null) return;
      await _player.setUrl(url);
      if (mounted) setState(() => _playingKey = key);
      await _player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play this audio.')),
        );
      }
    } finally {
      if (mounted && _playingKey == key) setState(() => _playingKey = null);
    }
  }

  // ═══════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Session Details')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 52, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final words = _maps(_d['words']);
    final scriptWords = words.where((w) => _type(w) != 'inserted').toList();
    final inserted = (_d['inserted_words'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final transcript = (_d['transcript'] ?? '').toString().trim();
    final recordingUrl = (_d['recording_url'] ?? '').toString();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _header(),
          const SizedBox(height: 16),
          _statsRow(scriptWords),
          if (recordingUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            _recordingCard(recordingUrl),
          ],
          const SizedBox(height: 16),
          _scriptCard(scriptWords),
          const SizedBox(height: 16),
          _errorsCard(scriptWords),
          if (inserted.isNotEmpty) ...[
            const SizedBox(height: 16),
            _insertedCard(inserted),
          ],
          if (transcript.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionCard(
              title: 'What we heard',
              child: Text(transcript,
                  style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary)),
            ),
          ],
          ..._feedbackSection(),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────
  Widget _header() {
    final acc = _dbl(_d['accuracy']) ?? 0;
    final color = scoreColor(acc);
    final mode = _d['mode']?.toString();
    final level =
        (_d['level_at_time'] ?? _d['level'])?.toString();
    final grade = (_d['grade'] ?? '').toString();
    final gradeLabel = (_d['grade_label'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (acc / 100).clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text('${acc.round()}%',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_d['title'] ?? 'Practice Session').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  formatSessionDateTime(parseApiDate(_d['created_at'])),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(modeLabel(mode), AppColors.primary,
                        icon: modeIcon(mode)),
                    if (level != null && level.isNotEmpty)
                      _chip(
                          level[0].toUpperCase() + level.substring(1),
                          AppColors.accent),
                    if (grade.isNotEmpty)
                      _chip(
                          gradeLabel.isEmpty
                              ? 'Grade $grade'
                              : 'Grade $grade · $gradeLabel',
                          color),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats row ───────────────────────────────────────
  Widget _statsRow(List<Map<String, dynamic>> scriptWords) {
    final stats = _d['stats'] is Map
        ? Map<String, dynamic>.from(_d['stats'] as Map)
        : <String, dynamic>{};

    final total = _int(stats['total_words']) ?? scriptWords.length;
    final correct = _int(stats['correct_words']) ??
        scriptWords
            .where((w) => _type(w) == 'correct' || _type(w) == 'accent')
            .length;
    final skipped = _int(stats['skipped_words']) ??
        scriptWords.where((w) => _type(w) == 'skipped').length;
    final errors = _int(stats['wrong_words']) ??
        scriptWords
            .where((w) => !['correct', 'accent', 'minor', 'skipped']
                .contains(_type(w)))
            .length;

    return Row(
      children: [
        Expanded(child: _miniStat('$total', 'Words', AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(child: _miniStat('$correct', 'Correct', AppColors.success)),
        const SizedBox(width: 10),
        Expanded(child: _miniStat('$errors', 'Errors', AppColors.error)),
        const SizedBox(width: 10),
        Expanded(child: _miniStat('$skipped', 'Skipped', AppColors.warning)),
      ],
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: _cardDecoration(radius: 16),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ── Recording ───────────────────────────────────────
  Widget _recordingCard(String url) {
    final playing = _playingKey == 'rec';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _play(url, 'rec'),
              icon: Icon(
                  playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Your recording',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ── Script (colored word by word) ───────────────────
  Widget _scriptCard(List<Map<String, dynamic>> scriptWords) {
    final source = (_d['script_source'] ?? '').toString();
    final scriptText = (_d['script_text'] ?? '').toString().trim();

    return _sectionCard(
      title: 'Script',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (scriptWords.isEmpty)
            Text(
              scriptText.isEmpty
                  ? 'The script for this session was not saved.'
                  : scriptText,
              style: const TextStyle(
                  fontSize: 15, height: 1.6, color: AppColors.textPrimary),
            )
          else ...[
            Wrap(
              spacing: 4,
              runSpacing: 6,
              children: scriptWords.map(_wordChip).toList(),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _legend('Wrong', Colors.red.shade700),
                _legend('Skipped', const Color(0xFF856404)),
                _legend('Minor slip', const Color(0xFFB35900)),
                _legend('Accent', const Color(0xFF1B7A72)),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Tap a word for details.',
                style: TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
          if (source == 'script' && scriptText.isNotEmpty && scriptWords.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Original script text',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(scriptText,
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          if (source == 'reconstructed')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'This was a custom script, so the text is rebuilt from the analysis (punctuation is not kept).',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ),
        ],
      ),
    );
  }

  Widget _wordChip(Map<String, dynamic> w) {
    final type = _type(w);
    final style = _wordStyleFor(type);
    return GestureDetector(
      onTap: () => _showWordSheet(w),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          (w['word'] ?? '').toString(),
          style: TextStyle(
            fontSize: 15,
            height: 1.3,
            color: style.foreground,
            fontWeight: type == 'correct' ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _legend(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color)),
        ),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  // ── Errors detected ─────────────────────────────────
  int _rank(String type) {
    switch (type) {
      case 'skipped':
        return 1;
      case 'minor':
        return 2;
      case 'accent':
        return 3;
      default:
        return 0; // hard errors first
    }
  }

  Widget _errorsCard(List<Map<String, dynamic>> scriptWords) {
    final flagged = scriptWords.where((w) => _type(w) != 'correct').toList()
      ..sort((a, b) => _rank(_type(a)).compareTo(_rank(_type(b))));

    // Fallback for sessions whose analysis JSON has no word list.
    final savedErrors = _maps(_d['errors']);

    if (flagged.isEmpty && savedErrors.isEmpty) {
      return _sectionCard(
        title: 'Errors detected',
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('No errors detected in this session. Great job!',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];
    if (flagged.isNotEmpty) {
      for (final w in flagged) {
        children.add(_errorTile(w));
      }
    } else {
      for (final e in savedErrors) {
        children.add(_errorTile({
          'word': e['word'],
          'type': e['error_type'],
          'severity': e['severity'],
        }));
      }
    }

    return _sectionCard(
      title: 'Errors detected (${children.length})',
      child: Column(children: children),
    );
  }

  Widget _errorTile(Map<String, dynamic> w) {
    final type = _type(w);
    final style = _wordStyleFor(type);
    final fg = style.foreground;
    final explanation = (w['explanation'] ?? '').toString().trim();
    final ref = _phonemes(w['ref_phonemes']);
    final pred = _phonemes(w['pred_phonemes']);
    final severity = _int(w['severity']);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showWordSheet(w),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                  color: fg, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text('"${w['word']}"',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                      ),
                      const SizedBox(width: 8),
                      _chip(errorTypeLabel(type), fg),
                      if (severity != null && severity > 0) ...[
                        const SizedBox(width: 6),
                        Text('severity $severity',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textHint)),
                      ],
                    ],
                  ),
                  if (ref.isNotEmpty || pred.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Expected: ${ref.isEmpty ? '—' : ref}   →   You said: ${pred.isEmpty ? '—' : pred}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  if (explanation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(explanation,
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Extra words ─────────────────────────────────────
  Widget _insertedCard(List<String> inserted) {
    return _sectionCard(
      title: 'Extra words you said',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: inserted
            .map((w) => _chip('"$w"', AppColors.textSecondary))
            .toList(),
      ),
    );
  }

  // ── Feedback ────────────────────────────────────────
  List<Widget> _feedbackSection() {
    final feedback = _maps(_d['feedback'])
        .where((f) => (f['explanation'] ?? '').toString().trim().isNotEmpty)
        .take(5)
        .toList();
    if (feedback.isEmpty) return [];

    return [
      const SizedBox(height: 16),
      _sectionCard(
        title: 'Feedback',
        child: Column(
          children: [
            for (var i = 0; i < feedback.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        size: 18, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(feedback[i]['explanation'].toString(),
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: AppColors.textSecondary)),
                    ),
                    if ((feedback[i]['audio_path'] ?? '').toString().isNotEmpty)
                      GestureDetector(
                        onTap: () =>
                            _play(feedback[i]['audio_path'].toString(), 'fb$i'),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                              _playingKey == 'fb$i'
                                  ? Icons.stop_circle_rounded
                                  : Icons.volume_up_rounded,
                              size: 22,
                              color: AppColors.primary),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  // ── Word bottom sheet ───────────────────────────────
  void _showWordSheet(Map<String, dynamic> w) {
    final type = _type(w);
    final style = _wordStyleFor(type);
    final explanation = (w['explanation'] ?? '').toString().trim();
    final ref = _phonemes(w['ref_phonemes']);
    final pred = _phonemes(w['pred_phonemes']);
    final audio = (w['audio_path'] ?? '').toString();

    double? score = _dbl(w['per_word_score']);
    if (score != null && score <= 1.0) score = score * 100;
    if (score != null && (score < 0 || score > 100)) score = null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: style.background ?? AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${w['word']}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: type == 'correct'
                              ? AppColors.success
                              : style.foreground)),
                ),
                const SizedBox(width: 10),
                _chip(errorTypeLabel(type),
                    type == 'correct' ? AppColors.success : style.foreground),
                const Spacer(),
                if (audio.isNotEmpty)
                  IconButton(
                    onPressed: () => _play(audio, 'w:${w['word']}'),
                    icon: const Icon(Icons.volume_up_rounded,
                        color: AppColors.primary),
                  ),
              ],
            ),
            if (score != null) ...[
              const SizedBox(height: 14),
              Text('Word score: ${score.round()}%',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
            if (ref.isNotEmpty || pred.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Expected sounds: ${ref.isEmpty ? '—' : ref}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('What you said: ${pred.isEmpty ? '—' : pred}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 12),
            Text(
              explanation.isNotEmpty
                  ? explanation
                  : (type == 'correct'
                      ? 'You pronounced this word correctly.'
                      : 'No extra explanation was saved for this word.'),
              style: const TextStyle(
                  fontSize: 15, height: 1.55, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // SMALL UI HELPERS
  // ═══════════════════════════════════════════════════

  BoxDecoration _cardDecoration({double radius = 20}) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      );

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _chip(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}