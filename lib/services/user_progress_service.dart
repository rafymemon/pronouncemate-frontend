import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import 'user_session.dart';

/// Home screen's progress summary. IMPORTANT SCOPE NOTE:
/// totalSessions, bestScore, averageAccuracy, wordsPracticed, recentSessions,
/// weeklyAccuracy, and todaySessions are all scoped to the CURRENT CALENDAR
/// WEEK (Monday 00:00 → Sunday). When a new week starts they reset to empty
/// and fill up again with the new week's sessions. This class exists to
/// power the Home screen's "this week" section.
/// All-time totals live separately in DashboardScreen, which fetches its
/// own unfiltered aggregates via ApiService.getDashboardSummary() and does
/// not use this class at all.
///
/// streakDays is the one exception: it's a running consecutive-days count,
/// not a windowed stat, so it remains all-time (sourced from the backend).
class UserProgressSummary {
  final String displayName;
  final int totalSessions;
  final double bestScore;
  final double averageAccuracy;
  final int streakDays;
  final int? wordsPracticed;
  final int todaySessions;
  final int goalTarget;
  final List<SessionSnapshot> recentSessions;
  final List<DayAccuracy> weeklyAccuracy;

  const UserProgressSummary({
    required this.displayName,
    required this.totalSessions,
    required this.bestScore,
    required this.averageAccuracy,
    required this.streakDays,
    required this.wordsPracticed,
    required this.todaySessions,
    required this.goalTarget,
    required this.recentSessions,
    required this.weeklyAccuracy,
  });

  // 👇 FIXED: Added clamp to prevent UI crashes if the user exceeds their daily goal (e.g. 3/2 sessions = 1.5)
  double get goalProgress => (goalTarget == 0 ? 0.0 : todaySessions / goalTarget).clamp(0.0, 1.0);
}

/// A single practice session, always drawn from the current calendar week
/// (see UserProgressSummary's scope note).
class SessionSnapshot {
  /// Database id of the PracticeSession. Lets a tapped row open the full
  /// session detail screen. Null only if the backend didn't send one.
  final int? id;
  final String title;
  final String dateLabel;
  final double score;
  final String grade;
  final String? durationLabel;

  const SessionSnapshot({
    this.id,
    required this.title,
    required this.dateLabel,
    required this.score,
    required this.grade,
    required this.durationLabel,
  });
}

/// One calendar day's aggregated practice accuracy, used to drive the
/// "Weekly Activity" heatmap (Monday → Sunday of the current week).
/// Sourced from the backend's `weekly_accuracy` (a real GROUP BY date
/// query — see `_compute_weekly_accuracy` in api/views.py), with a
/// client-side fallback computed from this week's session list if that
/// field is missing (e.g. talking to an older backend, or offline/cached
/// data).
class DayAccuracy {
  final DateTime date;
  final double averageAccuracy;
  final int sessionCount;

  const DayAccuracy({
    required this.date,
    required this.averageAccuracy,
    required this.sessionCount,
  });
}

class UserProgressService extends ChangeNotifier {
  static final UserProgressService instance = UserProgressService._internal();
  UserProgressService._internal();
  static UserProgressSummary? _cachedSummary;

  static UserProgressSummary? get cachedSummary => _cachedSummary;

  Future<void> invalidate() async {
    notifyListeners();
  }

  static Future<UserProgressSummary> load({int goalTarget = 2}) async {
    try {
      final results = await Future.wait([
        ApiService.getProfile(),
        // The backend returns the last 7 days, which always covers the
        // whole current calendar week (Monday is at most 6 days back).
        // We trim it to the current week below so the Home screen resets
        // on Monday.
        ApiService.getSessions(days: 7),
      ]);

      final profile = results[0] as Map<String, dynamic>;
      final allRecent = (results[1] as List).whereType<Map>().map((item) {
        return item.map((key, value) => MapEntry(key.toString(), value));
      }).toList();

      // ── Keep only sessions from the current calendar week ──
      final weekStart = _currentWeekStart();
      final sessions = allRecent.where((session) {
        final date = _parseDate(session['created_at']?.toString());
        return date != null && !date.isBefore(weekStart);
      }).toList();

      sessions.sort((left, right) {
        final leftDate = _parseDate(left['created_at']?.toString());
        final rightDate = _parseDate(right['created_at']?.toString());
        if (leftDate == null && rightDate == null) return 0;
        if (leftDate == null) return 1;
        if (rightDate == null) return -1;
        return rightDate.compareTo(leftDate);
      });

      // ── Everything below (except streak) is computed from `sessions`,
      // which is exactly this calendar week — not a fallback, the primary
      // source. All-time equivalents live only in DashboardScreen, which
      // never touches this service. ──
      final totalSessions = sessions.length;
      final bestScore = _bestScoreFromSessions(sessions);
      final averageAccuracy = _averageAccuracy(sessions);
      final wordsPracticed = _wordsPracticedFromSessions(sessions);

      final todaySessions = sessions.where((session) {
        final date = _parseDate(session['created_at']?.toString());
        return date != null && _isSameDay(date, DateTime.now());
      }).length;

      // Streak is a running consecutive-days status, not a windowed stat —
      // stays all-time, sourced from the backend (accurate regardless of
      // window). The client fallback can only detect consecutive days
      // within this week; that's an accepted limitation of the fallback
      // path only.
      final streakDays = _readInt(profile, const [
            'streak_days',
            'current_streak',
            'streak',
          ]) ??
          _streakFromSessions(sessions);

      final recentSessions = sessions.map((session) {
        final date = _parseDate(session['created_at']?.toString());
        final score = _readDouble(session, const ['accuracy', 'score']) ?? 0;
        return SessionSnapshot(
          id: _readInt(session, const ['id']),
          title: _readString(session, const [
                'session_title',
                'title',
                'mode',
                'practice_mode',
                'script_title',
              ]) ??
              'Session',
          dateLabel: _formatDateLabel(date),
          score: score,
          grade:
              _readString(session, const ['grade']) ?? _gradeFromScore(score),
          durationLabel: _formatDuration(session),
        );
      }).toList();

      // ── Weekly heatmap: backend-computed (real GROUP BY date, Monday →
      // Sunday), with a client-side fallback if the field is absent. ──
      final weeklyAccuracy = _parseWeeklyAccuracy(profile['weekly_accuracy']) ??
          _weeklyAccuracyFromSessions(sessions);

      final summary = UserProgressSummary(
        displayName: UserSession.instance.name,
        totalSessions: totalSessions,
        bestScore: bestScore,
        averageAccuracy: averageAccuracy,
        streakDays: streakDays,
        wordsPracticed: wordsPracticed,
        todaySessions: todaySessions,
        goalTarget: goalTarget,
        recentSessions: recentSessions,
        weeklyAccuracy: weeklyAccuracy,
      );
      _cachedSummary = summary;
      return summary;
    } catch (error) {
      debugPrint('UserProgressService.load failed: $error');
      final cachedSummary = _cachedSummary;
      if (cachedSummary != null) {
        return cachedSummary;
      }
      return UserProgressSummary(
        displayName: UserSession.instance.name,
        totalSessions: 0,
        bestScore: 0,
        averageAccuracy: 0,
        streakDays: 0,
        wordsPracticed: 0,
        todaySessions: 0,
        goalTarget: goalTarget,
        recentSessions: const [],
        weeklyAccuracy: emptyWeek(),
      );
    }
  }

  static void cache(UserProgressSummary summary) {
    _cachedSummary = summary;
  }

  /// Local midnight of this week's Monday.
  static DateTime _currentWeekStart() {
    final now = DateTime.now();
    return DateTime(
        now.year, now.month, now.day - (now.weekday - DateTime.monday));
  }

  static int? _readInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is int) return value;
      if (value is double) return value.round();
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  static double? _readDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// Best score within the given session list (this week in normal use).
  static double _bestScoreFromSessions(List<Map<String, dynamic>> sessions) {
    var best = 0.0;
    for (final session in sessions) {
      final score = _readDouble(session, const ['accuracy', 'score']);
      if (score != null && score > best) best = score;
    }
    return best;
  }

  /// Average accuracy within the given session list (this week in normal use).
  static double _averageAccuracy(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 0;
    var total = 0.0;
    var count = 0;
    for (final session in sessions) {
      final score = _readDouble(session, const ['accuracy', 'score']);
      if (score == null) continue;
      total += score;
      count += 1;
    }
    return count == 0 ? 0 : total / count;
  }

  static int _streakFromSessions(List<Map<String, dynamic>> sessions) {
    final days = <String>{};
    for (final session in sessions) {
      final date = _parseDate(session['created_at']?.toString());
      if (date == null) continue;
      days.add(_dayKey(date));
    }
    if (days.isEmpty) return 0;

    var streak = 0;
    var cursor = DateTime.now();
    while (days.contains(_dayKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Words practiced within the given session list (this week in normal
  /// use). `total_words` is the value the backend stores on every
  /// PracticeSession (and now always includes in /api/sessions/), so it is
  /// read first. No backend-aggregated equivalent is used here on purpose —
  /// the backend's `words_practiced` on ProfileView is an ALL-TIME sum
  /// (Dashboard's "Words" quick stat uses the equivalent all-time value);
  /// Home needs the weekly figure, which this list already is.
  static int? _wordsPracticedFromSessions(List<Map<String, dynamic>> sessions) {
    var total = 0;
    var foundAny = false;
    for (final session in sessions) {
      final directCount = _readInt(
          session, const ['total_words', 'words_practiced', 'word_count']);
      if (directCount != null) {
        total += directCount;
        foundAny = true;
        continue;
      }

      final words = session['words'];
      if (words is List) {
        total += words.length;
        foundAny = true;
        continue;
      }

      // NOTE: only `script_text` is used here. A bare `script` key from the
      // API is a database id, not text, and must not be word-counted.
      final scriptText = _readString(session, const ['script_text']);
      if (scriptText != null) {
        total += scriptText
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .length;
        foundAny = true;
      }
    }
    // A week with no sessions is a real 0, not "unknown".
    if (sessions.isEmpty) return 0;
    return foundAny ? total : null;
  }

  /// Parses the backend's `weekly_accuracy` field —
  /// `[{date, average_accuracy, session_count}, ...]`, Monday → Sunday —
  /// into `DayAccuracy` objects. Returns null if the field is missing or
  /// malformed, so the caller can fall back to client-side computation.
  static List<DayAccuracy>? _parseWeeklyAccuracy(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    try {
      return raw.map((entry) {
        final map = Map<String, dynamic>.from(entry as Map);
        return DayAccuracy(
          date: DateTime.parse(map['date'].toString()),
          averageAccuracy:
              (map['average_accuracy'] as num?)?.toDouble() ?? 0.0,
          sessionCount: (map['session_count'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Fallback only — used if the backend's `weekly_accuracy` field is
  /// absent (e.g. talking to an older API version) or unparsable.
  /// Monday → Sunday of the current week.
  static List<DayAccuracy> _weeklyAccuracyFromSessions(
      List<Map<String, dynamic>> sessions) {
    final weekStart = _currentWeekStart();

    final Map<String, List<double>> scoresByDay = {};
    for (final session in sessions) {
      final date = _parseDate(session['created_at']?.toString());
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      if (day.isBefore(weekStart)) continue;

      final score = _readDouble(session, const ['accuracy', 'score']);
      if (score == null) continue;

      scoresByDay.putIfAbsent(_dayKey(day), () => []).add(score);
    }

    return List.generate(7, (i) {
      final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      final scores = scoresByDay[_dayKey(day)] ?? const <double>[];
      final avg = scores.isEmpty
          ? 0.0
          : scores.reduce((a, b) => a + b) / scores.length;
      return DayAccuracy(
        date: day,
        averageAccuracy: avg,
        sessionCount: scores.length,
      );
    });
  }

  /// An empty Monday → Sunday week (used before data loads / on failure).
  static List<DayAccuracy> emptyWeek() {
    final weekStart = _currentWeekStart();
    return List.generate(7, (i) {
      final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      return DayAccuracy(date: day, averageAccuracy: 0, sessionCount: 0);
    });
  }

  // 👇 FIXED: Changed return type to String? and removed literal 'null.toString()'
  static String? _formatDuration(Map<String, dynamic> session) {
    final direct = _readString(session, const ['duration', 'duration_label']);
    if (direct != null) return direct;

    final seconds =
        _readInt(session, const ['duration_seconds', 'elapsed_seconds']);
    if (seconds == null || seconds <= 0) return null;

    final minutes = seconds ~/ 60;
    if (minutes == 0) return '${seconds}s';
    return '$minutes min';
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }

  static bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static String _dayKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateLabel(DateTime? value) {
    if (value == null) return 'Recently';

    final now = DateTime.now();
    if (_isSameDay(value, now)) {
      return 'Today, ${_formatTime(value)}';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(value, yesterday)) {
      return 'Yesterday, ${_formatTime(value)}';
    }

    return '${_shortWeekday(value.weekday)}, ${value.month}/${value.day}';
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  static String _shortWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      default:
        return 'Sun';
    }
  }

  static String _gradeFromScore(double score) {
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    return 'D';
  }
}