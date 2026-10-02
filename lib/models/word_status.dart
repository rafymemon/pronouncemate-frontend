enum WordStatus { pending, correct, accent, minor, error, skipped }

/// Shared word model.
/// - `skipped` = yellow = a script word that was never spoken (deletion).
/// - `accent` = teal = a forgiven Pakistani-accent phoneme pattern — not
///   penalized, shown distinctly from `correct` so the pronunciation
///   adaptation is visible rather than silently invisible.
/// - `minor` = amber = a close-but-not-exact acoustic read (e.g. a
///   dropped plural -s, a slightly shortened vowel) — flagged but far
///   less alarming than a hard `error`.
/// - `isTarget` = this word is one of a Focus Script's error words
///   (pre-highlighted before practice).
/// Insertions (extra spoken words not in the script) have no slot here —
/// they're reported only in the final summary.
class DisplayWord {
  final String text;
  WordStatus status;
  String? tip;
  double? score;
  String? type;
  String? audioPath;
  bool isTarget;

  DisplayWord(
    this.text, {
    this.status = WordStatus.pending,
    this.tip,
    this.score,
    this.type,
    this.audioPath,
    this.isTarget = false,
  });
}