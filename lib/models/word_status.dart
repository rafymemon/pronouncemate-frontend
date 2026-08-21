enum WordStatus { pending, correct, error, skipped }

/// Shared word model. `skipped` = yellow = a script word that was never
/// spoken (deletion). Insertions (extra spoken words not in the script)
/// have no slot here — they're reported only in the final summary.
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