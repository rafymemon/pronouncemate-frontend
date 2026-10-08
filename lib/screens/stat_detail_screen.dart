// lib/screens/stat_detail_screen.dart
import 'package:flutter/material.dart';
import '../services/stats_api_service.dart';
import '../theme/app_theme.dart';
import 'session_detail_screen.dart';

enum StatScope { week, all }

/// Drill-down opened by tapping a stat card.
///   metric: 'sessions' | 'accuracy' | 'words' | 'streak' | 'errors'
///   scope:  StatScope.week (Home) | StatScope.all (Dashboard)
class StatDetailScreen extends StatefulWidget {
  final String metric;
  final StatScope scope;
  const StatDetailScreen({
    super.key,
    required this.metric,
    required this.scope,
  });

  @override
  State<StatDetailScreen> createState() => _StatDetailScreenState();
}

class _StatDetailScreenState extends State<StatDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  String _wordFilter = 'all'; // all | needs | clean

  bool get _isWeek => widget.scope == StatScope.week;
  String get _scopeParam => _isWeek ? 'week' : 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res =
        await StatsApiService.getStatDetail(widget.metric, scope: _scopeParam);
    if (!mounted) return;
    if (res['error'] != null) {
      setState(() {
        _error = res['error'].toString();
        _loading = false;
      });
      return;
    }
    setState(() {
      _data = res;
      _loading = false;
    });
  }

  // ── parsing helpers ─────────────────────────────────
  List<Map<String, dynamic>> _maps(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  int? _int(dynamic v) =>
      v is num ? v.toInt() : (v == null ? null : int.tryParse(v.toString()));

  double _dbl(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

  String get _title {
    switch (widget.metric) {
      case 'sessions':
        return 'Sessions';
      case 'accuracy':
        return 'Accuracy';
      case 'words':
        return 'Words Practiced';
      case 'streak':
        return 'Streak';
      case 'errors':
        return 'Errors Detected';
      default:
        return 'Details';
    }
  }

  String get _scopeLabel {
    if (!_isWeek) return 'All time · since your first session';
    final s = parseApiDate(_data['week_start']);
    final e = parseApiDate(_data['week_end']);
    if (s == null || e == null) return 'This week';
    return 'This week · ${formatShortDate(s)} – ${formatShortDate(e)}';
  }

  // ═══════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_title)),
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
              Icon(Icons.wifi_off, size: 52, color: Colors.grey.shade400),
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

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(_scopeLabel,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          ..._content(),
        ],
      ),
    );
  }

  List<Widget> _content() {
    switch (widget.metric) {
      case 'sessions':
        return _sessionsView();
      case 'accuracy':
        return _accuracyView();
      case 'words':
        return _wordsView();
      case 'streak':
        return _streakView();
      case 'errors':
        return _errorsView();
      default:
        return const [];
    }
  }

  // ═══════════════════════════════════════════════════
  // SESSIONS
  // ═══════════════════════════════════════════════════

  List<Widget> _sessionsView() {
    final sessions = _maps(_data['sessions']);
    final total = _int(_data['total']) ?? sessions.length;
    final byDay = _maps(_data['by_day']);
    final activeDays = byDay.where((d) => (_int(d['count']) ?? 0) > 0).length;
    final avg = sessions.isEmpty
        ? 0.0
        : sessions.map((s) => _dbl(s['accuracy'])).reduce((a, b) => a + b) /
            sessions.length;

    return [
      _summaryRow([
        _Summary('$total', 'Sessions', AppColors.primary),
        _Summary('$activeDays', 'Active days', AppColors.accent),
        _Summary('${avg.round()}%', 'Avg. accuracy', AppColors.success),
      ]),
      if (_isWeek && byDay.isNotEmpty) ...[
        const SizedBox(height: 14),
        _weekCountStrip(byDay),
      ],
      const SizedBox(height: 20),
      _sectionTitle(_isWeek ? 'Sessions this week' : 'All sessions'),
      if (sessions.isEmpty)
        _empty(_isWeek
            ? 'No sessions yet this week. Start a practice run to see it here.'
            : 'No sessions yet. Start your first practice!')
      else
        ...sessions.map((s) => _sessionTile(s)),
    ];
  }

  Widget _weekCountStrip(List<Map<String, dynamic>> byDay) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: _cardDecoration(radius: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: byDay.map((d) {
          final date = parseApiDate(d['date']);
          final count = _int(d['count']) ?? 0;
          final active = count > 0;
          return Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.accent
                      : AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$count',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color:
                              active ? Colors.white : AppColors.textHint)),
                ),
              ),
              const SizedBox(height: 6),
              Text(date == null ? '' : _dayLetter(date),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ACCURACY
  // ═══════════════════════════════════════════════════

  List<Widget> _accuracyView() {
    final sessions = _maps(_data['sessions']);
    return [
      _summaryRow([
        _Summary('${_dbl(_data['average']).round()}%', 'Average',
            AppColors.accent),
        _Summary(
            '${_dbl(_data['best']).round()}%', 'Best', AppColors.success),
        _Summary(
            '${_dbl(_data['lowest']).round()}%', 'Lowest', AppColors.warning),
      ]),
      const SizedBox(height: 20),
      _sectionTitle('Accuracy of every session'),
      if (sessions.isEmpty)
        _empty(_isWeek
            ? 'No sessions yet this week.'
            : 'No sessions yet. Start your first practice!')
      else
        ...sessions.map((s) => _sessionTile(s, showBar: true)),
    ];
  }

  // ═══════════════════════════════════════════════════
  // WORDS
  // ═══════════════════════════════════════════════════

  List<Widget> _wordsView() {
    final words = _maps(_data['words']);
    final totalWords = _int(_data['total_words']) ?? 0;
    final unique = _int(_data['unique_words']) ?? words.length;
    final needWork = words.where((w) => w['status'] == 'needs_work').length;

    final filtered = words.where((w) {
      if (_wordFilter == 'needs') return w['status'] == 'needs_work';
      if (_wordFilter == 'clean') return w['status'] != 'needs_work';
      return true;
    }).toList();

    return [
      _summaryRow([
        _Summary('$totalWords', 'Words spoken', AppColors.warning),
        _Summary('$unique', 'Different words', AppColors.accent),
        _Summary('$needWork', 'Need work', AppColors.error),
      ]),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        children: [
          _filterChip('All ($unique)', 'all'),
          _filterChip('Need work ($needWork)', 'needs'),
          _filterChip('Clean (${unique - needWork})', 'clean'),
        ],
      ),
      const SizedBox(height: 14),
      if (filtered.isEmpty)
        _empty(words.isEmpty
            ? (_isWeek
                ? 'No words practiced yet this week.'
                : 'No words practiced yet.')
            : 'No words in this filter.')
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filtered.map(_wordChip).toList(),
        ),
    ];
  }

  Widget _filterChip(String label, String value) {
    final selected = _wordFilter == value;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary)),
      selected: selected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      showCheckmark: false,
      onSelected: (_) => setState(() => _wordFilter = value),
    );
  }

  Widget _wordChip(Map<String, dynamic> w) {
    final errors = _int(w['errors']) ?? 0;
    final minor = _int(w['minor']) ?? 0;
    final times = _int(w['times']) ?? 0;

    final Color bg;
    final Color fg;
    if (errors > 0) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
    } else if (minor > 0) {
      bg = const Color(0xFFFFE9D6);
      fg = const Color(0xFFB35900);
    } else {
      bg = AppColors.successLight;
      fg = AppColors.success;
    }

    return GestureDetector(
      onTap: () => _showWordDialog(w),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${w['word']}',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
            if (times > 1) ...[
              const SizedBox(width: 6),
              Text('×$times',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: fg.withValues(alpha: 0.75))),
            ],
          ],
        ),
      ),
    );
  }

  void _showWordDialog(Map<String, dynamic> w) {
    final last = parseApiDate(w['last_practiced']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${w['word']}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Practiced ${w['times']} time${(_int(w['times']) ?? 0) == 1 ? '' : 's'}'),
            const SizedBox(height: 6),
            Text('Correct: ${w['correct']}'),
            Text('Minor slips: ${w['minor']}'),
            Text('Errors: ${w['errors']}'),
            if (last != null) ...[
              const SizedBox(height: 6),
              Text('Last practiced: ${formatSessionDateTime(last)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // STREAK
  // ═══════════════════════════════════════════════════

  List<Widget> _streakView() {
    final current = _int(_data['current_streak']) ?? 0;
    final longest = _int(_data['longest_streak']) ?? 0;
    final daysPracticed = _int(_data['days_practiced']) ?? 0;
    final weekDays = _maps(_data['week_days']);
    final practiced = _maps(_data['practiced_days']);
    final streakSet = (_data['streak_days'] as List? ?? [])
        .map((e) => e.toString())
        .toSet();

    return [
      _summaryRow([
        _Summary('$current', 'Current streak', AppColors.error),
        _Summary('$longest', 'Longest streak', AppColors.warning),
        _Summary('$daysPracticed',
            _isWeek ? 'Days this week' : 'Days practiced', AppColors.accent),
      ]),
      if (weekDays.isNotEmpty) ...[
        const SizedBox(height: 14),
        _weekCheckStrip(weekDays),
      ],
      const SizedBox(height: 20),
      _sectionTitle(_isWeek ? 'Practice days this week' : 'Practice days'),
      if (practiced.isEmpty)
        _empty(_isWeek
            ? 'You have not practiced yet this week.'
            : 'No practice days yet.')
      else
        ...practiced.map((d) {
          final inStreak = streakSet.contains(d['date'].toString());
          final count = _int(d['session_count']) ?? 0;
          final avg = _dbl(d['avg_accuracy']);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: _cardDecoration(radius: 14),
            child: Row(
              children: [
                Icon(
                  inStreak
                      ? Icons.local_fire_department_rounded
                      : Icons.event_available_rounded,
                  color: inStreak ? AppColors.error : AppColors.textHint,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(formatShortDate(parseApiDate(d['date'])),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                Text(
                    '$count session${count == 1 ? '' : 's'} · avg ${avg.round()}%',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          );
        }),
    ];
  }

  Widget _weekCheckStrip(List<Map<String, dynamic>> weekDays) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: _cardDecoration(radius: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekDays.map((d) {
          final date = parseApiDate(d['date']);
          final done = d['practiced'] == true;
          return Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: done ? AppColors.success : AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    done ? Icons.check_rounded : Icons.remove_rounded,
                    size: 18,
                    color: done ? Colors.white : AppColors.textHint),
              ),
              const SizedBox(height: 6),
              Text(date == null ? '' : _dayLetter(date),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ERRORS
  // ═══════════════════════════════════════════════════

  List<Widget> _errorsView() {
    final total = _int(_data['total_errors']) ?? 0;
    final byType = _data['by_type'] is Map
        ? Map<String, dynamic>.from(_data['by_type'] as Map)
        : <String, dynamic>{};
    final words = _maps(_data['words']);

    return [
      _summaryRow([
        _Summary('$total', 'Total errors', AppColors.error),
        _Summary('${words.length}', 'Different words', AppColors.warning),
      ]),
      if (byType.isNotEmpty) ...[
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: byType.entries.map((e) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text('${errorTypeLabel(e.key)}: ${e.value}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            );
          }).toList(),
        ),
      ],
      const SizedBox(height: 20),
      _sectionTitle('Words with errors'),
      if (words.isEmpty)
        _empty(_isWeek
            ? 'No errors this week. Nice!'
            : 'No errors recorded yet.')
      else
        ...words.map((w) {
          final last = parseApiDate(w['last_seen']);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: _cardDecoration(radius: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('"${w['word']}"',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      if (last != null)
                        Text('Last seen ${formatShortDate(last)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${w['count']}×',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.red.shade700)),
                ),
              ],
            ),
          );
        }),
    ];
  }

  // ═══════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════

  Widget _sessionTile(Map<String, dynamic> s, {bool showBar = false}) {
    final id = _int(s['id']);
    final acc = _dbl(s['accuracy']);
    final color = scoreColor(acc);
    final dt = parseApiDate(s['created_at']);
    final mode = s['mode']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        elevation: 1,
        shadowColor: AppColors.cardShadow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: id == null
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(sessionId: id)),
                  ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 44),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text('${acc.round()}%',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: color)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${s['title'] ?? 'Practice Session'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                              '${formatSessionDateTime(dt)} · ${modeLabel(mode)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${s['grade'] ?? ''}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: color)),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textHint),
                  ],
                ),
                if (showBar) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (acc / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(List<_Summary> items) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: _cardDecoration(),
      child: Row(
        children: items
            .map((i) => Expanded(
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(i.value,
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: i.color)),
                      ),
                      const SizedBox(height: 4),
                      Text(i.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
    );
  }

  Widget _empty(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Text(message,
          textAlign: TextAlign.center,
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
    );
  }

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

  String _dayLetter(DateTime d) => 'MTWTFSS'[d.weekday - 1];
}

class _Summary {
  final String value;
  final String label;
  final Color color;
  const _Summary(this.value, this.label, this.color);
}