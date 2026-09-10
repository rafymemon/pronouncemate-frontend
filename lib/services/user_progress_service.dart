import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import 'user_session.dart';

/// Home screen's progress summary. IMPORTANT SCOPE NOTE:
/// totalSessions, bestScore, averageAccuracy, wordsPracticed, recentSessions,
/// weeklyAccuracy, and todaySessions are all scoped to the LAST 7 DAYS —
/// this class exists to power the Home screen's "recent activity" section.
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

/// A single practice session, always drawn from the last-7-days window
/// (see UserProgressSummary's scope note).
class SessionSnapshot {
  final String title;
  final String dateLabel;
  final double score;
  final String grade;
  final String? durationLabel;

  const SessionSnapshot({
    required this.title,
    required this.dateLabel,
    required this.score,
    required this.grade,
    required this.durationLabel,
  });
}

/// One calendar day's aggregated practice accuracy, used to drive the
/// "Weekly Activity" heatmap. Sourced from the backend's
/// `weekly_accuracy` (a real GROUP BY date query — see
/// `_compute_weekly_accuracy` in api/views.py), with a client-side
/// fallback computed from the 7-day session list if that field is
/// missing (e.g. talking to an older backend, or offline/cached data).
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
        // Backend-filtered to the last 7 days. This IS the recent-activity
        // window Home shows — not an approximation of it.
        ApiService.getSessions(days: 7),
      ]);

      final profile = results[0] as Map<String, dynamic>;
      final sessions = (results[1] as List).whereType<Map>().map((item) {
        return item.map((key, value) => MapEntry(key.toString(), value));
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
      // which is already the exact 7-day window — not a fallback, the
      // primary source. All-time equivalents live only in DashboardScreen,
      // which never touches this service. ──
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
      // window). The client fallback can only detect up to 7 consecutive
      // days since `sessions` here is 7-day-scoped; that's an accepted
      // limitation of the fallback path only.
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

      // ── Weekly heatmap: backend-computed (real GROUP BY date), with a
      // client-side fallback if the field is absent. ──
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
        weeklyAccuracy: _emptyWeek(),
      );
    }
  }

  static void cache(UserProgressSummary summary) {
    _cachedSummary = summary;
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

  /// Best score within the given session list (7-day window in normal use).
  static double _bestScoreFromSessions(List<Map<String, dynamic>> sessions) {
    var best = 0.0;
    for (final session in sessions) {
      final score = _readDouble(session, const ['accuracy', 'score']);
      if (score != null && score > best) best = score;
    }
    return best;
  }

  /// Average accuracy within the given session list (7-day window in normal use).
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

  /// Words practiced within the given session list (7-day window in normal
  /// use). No backend-aggregated equivalent is used here on purpose — the
  /// backend's `words_practiced` on ProfileView is an ALL-TIME sum
  /// (Dashboard's "Words" quick stat uses the equivalent all-time value);
  /// Home needs the 7-day figure, which this list already is.
  static int? _wordsPracticedFromSessions(List<Map<String, dynamic>> sessions) {
    var total = 0;
    var foundAny = false;
    for (final session in sessions) {
      final directCount =
          _readInt(session, const ['words_practiced', 'word_count']);
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

      final scriptText = _readString(session, const ['script_text', 'script']);
      if (scriptText != null) {
        total += scriptText
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .length;
        foundAny = true;
      }
    }
    return foundAny ? total : null;
  }

  /// Parses the backend's `weekly_accuracy` field —
  /// `[{date, average_accuracy, session_count}, ...]`, oldest → newest —
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
  static List<DayAccuracy> _weeklyAccuracyFromSessions(
      List<Map<String, dynamic>> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final Map<String, List<double>> scoresByDay = {};
    for (final session in sessions) {
      final date = _parseDate(session['created_at']?.toString());
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      final diff = today.difference(day).inDays;
      if (diff < 0 || diff > 6) continue;

      final score = _readDouble(session, const ['accuracy', 'score']);
      if (score == null) continue;

      scoresByDay.putIfAbsent(_dayKey(day), () => []).add(score);
    }

    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
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

  static List<DayAccuracy> _emptyWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
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