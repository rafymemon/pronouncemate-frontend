// models/practice_models.dart
// Data models for Practice Mistakes feature

class MistakeWord {
  final String word;
  final String errorType;
  final int severity;
  final double perWordScore;
  final List<String> refPhonemes;
  final List<String> predPhonemes;
  final String explanation;
  final String? audioPath;
  final int attemptCount;
  final double bestScore;
  final bool cleared;

  MistakeWord({
    required this.word,
    required this.errorType,
    required this.severity,
    required this.perWordScore,
    required this.refPhonemes,
    required this.predPhonemes,
    required this.explanation,
    this.audioPath,
    this.attemptCount = 1,
    this.bestScore = 0.0,
    this.cleared = false,
  });

  factory MistakeWord.fromJson(Map<String, dynamic> json) {
    return MistakeWord(
      word: json['word'] ?? '',
      errorType: json['error_type'] ?? '',
      severity: json['severity'] ?? 0,
      perWordScore: (json['per_word_score'] ?? 0.0).toDouble(),
      refPhonemes: List<String>.from(json['ref_phonemes'] ?? []),
      predPhonemes: List<String>.from(json['pred_phonemes'] ?? []),
      explanation: json['explanation'] ?? '',
      audioPath: json['audio_path'],
      attemptCount: json['attempt_count'] ?? 1,
      bestScore: (json['best_score'] ?? 0.0).toDouble(),
      cleared: json['cleared'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'error_type': errorType,
    'severity': severity,
    'per_word_score': perWordScore,
    'ref_phonemes': refPhonemes,
    'pred_phonemes': predPhonemes,
    'explanation': explanation,
    'audio_path': audioPath,
    'attempt_count': attemptCount,
    'best_score': bestScore,
    'cleared': cleared,
  };
}

class MistakeSummary {
  final int mistakeCount;
  final bool offerPractice;
  final Map<String, int> severityBreakdown;
  final String? mostCommonError;
  final List<String> words;
  final List<Map<String, dynamic>> topMistakes;

  MistakeSummary({
    required this.mistakeCount,
    required this.offerPractice,
    required this.severityBreakdown,
    this.mostCommonError,
    required this.words,
    required this.topMistakes,
  });

  factory MistakeSummary.fromJson(Map<String, dynamic> json) {
    return MistakeSummary(
      mistakeCount: json['mistake_count'] ?? 0,
      offerPractice: json['offer_practice'] ?? false,
      severityBreakdown: Map<String, int>.from(json['severity_breakdown'] ?? {}),
      mostCommonError: json['most_common_error'],
      words: List<String>.from(json['words'] ?? []),
      topMistakes: List<Map<String, dynamic>>.from(json['top_mistakes'] ?? []),
    );
  }
}

class PracticeResult {
  final bool success;
  final String sessionType;
  final String? originalSessionId;
  final String practiceScript;
  final String mode;
  final double score;
  final String grade;
  final String gradeLabel;
  final int clearedCount;
  final int improvedCount;
  final int strugglingCount;
  final int totalPracticed;
  final String message;
  final List<dynamic> clearedWords;
  final List<dynamic> improvedWords;
  final List<dynamic> stillStruggling;
  final List<dynamic> words;
  final List<dynamic> feedback;

  PracticeResult({
    required this.success,
    required this.sessionType,
    this.originalSessionId,
    required this.practiceScript,
    required this.mode,
    required this.score,
    required this.grade,
    required this.gradeLabel,
    required this.clearedCount,
    required this.improvedCount,
    required this.strugglingCount,
    required this.totalPracticed,
    required this.message,
    required this.clearedWords,
    required this.improvedWords,
    required this.stillStruggling,
    required this.words,
    required this.feedback,
  });

  factory PracticeResult.fromJson(Map<String, dynamic> json) {
    return PracticeResult(
      success: json['success'] ?? false,
      sessionType: json['session_type'] ?? '',
      originalSessionId: json['original_session_id'],
      practiceScript: json['practice_script'] ?? '',
      mode: json['mode'] ?? 'sentences',
      score: (json['score'] ?? 0.0).toDouble(),
      grade: json['grade'] ?? 'D',
      gradeLabel: json['grade_label'] ?? 'Focus Required',
      clearedCount: json['cleared_count'] ?? 0,
      improvedCount: json['improved_count'] ?? 0,
      strugglingCount: json['struggling_count'] ?? 0,
      totalPracticed: json['total_practiced'] ?? 0,
      message: json['message'] ?? '',
      clearedWords: json['cleared_words'] ?? [],
      improvedWords: json['improved_words'] ?? [],
      stillStruggling: json['still_struggling'] ?? [],
      words: json['words'] ?? [],
      feedback: json['feedback'] ?? [],
    );
  }
}