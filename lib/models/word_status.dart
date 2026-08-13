import 'package:flutter/foundation.dart';

enum WordStatus { pending, correct, error }

/// Single shared model for how a word is drawn on screen.
/// Used by both active_session_screen.dart (full evaluation)
/// and practice_session_screen.dart (mistake-word retry + live coloring).
class DisplayWord {
  final String text;
  WordStatus status;
  String? tip;
  double? score;
  String? type;
  String? audioPath;

  DisplayWord(
    this.text, {
    this.status = WordStatus.pending,
    this.tip,
    this.score,
    this.type,
    this.audioPath,
  });
}