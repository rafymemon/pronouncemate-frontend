import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import 'user_session.dart';

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
  });

  // 👇 FIXED: Added clamp to prevent UI crashes if the user exceeds their daily goal (e.g. 3/2 sessions = 1.5)
  double get goalProgress => (goalTarget == 0 ? 0.0 : todaySessions / goalTarget).clamp(0.0, 1.0);
}

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
        ApiService.getSessions(),
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

      final totalSessions = _readInt(profile, const [
            'total_sessions',
            'session_count',
            'total_session_count',
          ]) ??
          sessions.length;

      final bestScore = _readDouble(profile, const [
            'best_score',
            'best_accuracy',
            'max_score',
          ]) ??
          _bestScoreFromSessions(sessions);

      final averageAccuracy = _averageAccuracy(sessions);
      final streakDays = _readInt(profile, const [
            'streak_days',
            'current_streak',
            'streak',
          ]) ??
          _streakFromSessions(sessions);

      final wordsPracticed = _readInt(profile, const [
            'words_practiced',
            'words_practiced_total',
            'total_words',
            'word_count',
          ]) ??
          _wordsPracticedFromSessions(sessions);

      final todaySessions = sessions.where((session) {
        final date = _parseDate(session['created_at']?.toString());
        return date != null && _isSameDay(date, DateTime.now());
      }).length;

      final recentSessions = sessions.take(3).map((session) {
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

  static double _bestScoreFromSessions(List<Map<String, dynamic>> sessions) {
    var best = 0.0;
    for (final session in sessions) {
      final score = _readDouble(session, const ['accuracy', 'score']);
      if (score != null && score > best) best = score;
    }
    return best;
  }

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