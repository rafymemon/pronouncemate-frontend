// providers/practice_provider.dart
// State management for Practice Mistakes

import 'package:flutter/foundation.dart';
import '../models/practice_models.dart';

class PracticeProvider extends ChangeNotifier {
  List<MistakeWord> _mistakeWords = [];
  String? _originalSessionId;
  PracticeResult? _lastPracticeResult;
  bool _isLoading = false;

  List<MistakeWord> get mistakeWords => _mistakeWords;
  String? get originalSessionId => _originalSessionId;
  PracticeResult? get lastPracticeResult => _lastPracticeResult;
  bool get isLoading => _isLoading;
  bool get hasMistakes => _mistakeWords.isNotEmpty;
  int get clearedCount => _mistakeWords.where((w) => w.cleared).length;

  void setMistakesFromSession(List<dynamic> words, String sessionId) {
    _originalSessionId = sessionId;
    _mistakeWords = words
        .where((w) => w['type'] != 'correct')
        .map((w) => MistakeWord.fromJson(w))
        .toList();
    notifyListeners();
  }

  void updateAfterPractice(PracticeResult result) {
    _lastPracticeResult = result;

    for (var cleared in result.clearedWords) {
      final index = _mistakeWords.indexWhere((w) => w.word == cleared['word']);
      if (index != -1) {
        _mistakeWords[index] = MistakeWord(
          word: _mistakeWords[index].word,
          errorType: _mistakeWords[index].errorType,
          severity: cleared['severity'] ?? 0,
          perWordScore: cleared['current_score'] ?? 100.0,
          refPhonemes: _mistakeWords[index].refPhonemes,
          predPhonemes: _mistakeWords[index].predPhonemes,
          explanation: _mistakeWords[index].explanation,
          audioPath: _mistakeWords[index].audioPath,
          attemptCount: _mistakeWords[index].attemptCount + 1,
          bestScore: cleared['current_score'] ?? _mistakeWords[index].bestScore,
          cleared: true,
        );
      }
    }

    notifyListeners();
  }

  void clearMistakes() {
    _mistakeWords = [];
    _originalSessionId = null;
    _lastPracticeResult = null;
    notifyListeners();
  }
}