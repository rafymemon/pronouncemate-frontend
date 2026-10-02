import 'package:flutter/material.dart';
import '../models/word_status.dart';

class PronunciationWordDisplay extends StatelessWidget {
  final List<DisplayWord> words;
  final void Function(DisplayWord word)? onWordTap;
  final Color pendingTextColor;

  /// When true, pending Focus Script target words are drawn as highlighted
  /// error words (idle state). When false (recording), they keep only a
  /// faint underline so live coloring stays readable.
  final bool highlightTargets;

  const PronunciationWordDisplay({
    Key? key,
    required this.words,
    this.onWordTap,
    this.pendingTextColor = const Color(0xFF2D2A26),
    this.highlightTargets = false,
  }) : super(key: key);

  Color _bg(WordStatus s) {
    switch (s) {
      case WordStatus.correct:
        return const Color(0xFFD4EDDA);
      case WordStatus.accent:
        return const Color(0xFFDCF3F1);
      case WordStatus.minor:
        return const Color(0xFFFFE9D6);
      case WordStatus.error:
        return const Color(0xFFFFE0E0);
      case WordStatus.skipped:
        return const Color(0xFFFFF3CD);
      case WordStatus.pending:
        return Colors.transparent;
    }
  }

  Color _text(WordStatus s) {
    switch (s) {
      case WordStatus.correct:
        return const Color(0xFF2E7D32);
      case WordStatus.accent:
        return const Color(0xFF1B7A72);
      case WordStatus.minor:
        return const Color(0xFFB35900);
      case WordStatus.error:
        return const Color(0xFFC62828);
      case WordStatus.skipped:
        return const Color(0xFF856404);
      case WordStatus.pending:
        return pendingTextColor;
    }
  }

  Color _underline(WordStatus s) {
    switch (s) {
      case WordStatus.error:
        return Colors.red.shade400;
      case WordStatus.skipped:
        return const Color(0xFFCC9A06);
      default:
        // accent and minor deliberately get NO underline — the underline
        // is reserved for statuses that need visual weight (hard errors,
        // deletions). Giving accent/minor the same treatment would make
        // them read as just as alarming as a real error, defeating the
        // point of having a middle tier at all.
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: words.map((w) {
          final isPendingTarget = w.isTarget && w.status == WordStatus.pending;
          final showTargetFill = isPendingTarget && highlightTargets;

          final tappable = onWordTap != null &&
              w.tip != null &&
              (w.status == WordStatus.error ||
                  w.status == WordStatus.skipped ||
                  w.status == WordStatus.minor ||
                  w.status == WordStatus.accent ||
                  showTargetFill);

          final Color bg =
              showTargetFill ? const Color(0xFFFFE0E0) : _bg(w.status);
          final Color textColor =
              showTargetFill ? const Color(0xFFC62828) : _text(w.status);

          Border? border;
          if (w.status == WordStatus.error || w.status == WordStatus.skipped) {
            border = Border(
                bottom: BorderSide(color: _underline(w.status), width: 2));
          } else if (isPendingTarget) {
            border = Border(
              bottom: BorderSide(
                color: highlightTargets
                    ? Colors.red.shade400
                    : Colors.red.shade200,
                width: highlightTargets ? 2 : 1.5,
              ),
            );
          }

          return WidgetSpan(
            child: GestureDetector(
              onTap: tappable ? () => onWordTap!(w) : null,
              child: Container(
                margin: const EdgeInsets.only(right: 6, bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                  border: border,
                ),
                child: Text(
                  w.text,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                    fontFamily: 'serif',
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}