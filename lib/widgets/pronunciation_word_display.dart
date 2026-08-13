import 'package:flutter/material.dart';
import '../models/word_status.dart';

/// Renders a script as colored words: green = correct, red = mispronounced,
/// neutral = not yet judged. This is the ONE place word-coloring logic
/// lives — both the full-script evaluation screen and the live practice
/// screen render through this widget, so "why is this word red" always
/// has a single answer.
class PronunciationWordDisplay extends StatelessWidget {
  final List<DisplayWord> words;
  final void Function(DisplayWord word)? onWordTap;
  final Color pendingTextColor;

  const PronunciationWordDisplay({
    Key? key,
    required this.words,
    this.onWordTap,
    this.pendingTextColor = const Color(0xFF2D2A26),
  }) : super(key: key);

  Color _bg(WordStatus s) {
    switch (s) {
      case WordStatus.correct:
        return const Color(0xFFD4EDDA);
      case WordStatus.error:
        return const Color(0xFFFFE0E0);
      case WordStatus.pending:
        return Colors.transparent;
    }
  }

  Color _text(WordStatus s) {
    switch (s) {
      case WordStatus.correct:
        return const Color(0xFF2E7D32);
      case WordStatus.error:
        return const Color(0xFFC62828);
      case WordStatus.pending:
        return pendingTextColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: words.map((w) {
          final tappable =
              onWordTap != null && w.status == WordStatus.error && w.tip != null;
          return WidgetSpan(
            child: GestureDetector(
              onTap: tappable ? () => onWordTap!(w) : null,
              child: Container(
                margin: const EdgeInsets.only(right: 6, bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _bg(w.status),
                  borderRadius: BorderRadius.circular(6),
                  border: w.status == WordStatus.error
                      ? Border(
                          bottom: BorderSide(color: Colors.red.shade400, width: 2))
                      : null,
                ),
                child: Text(
                  w.text,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    color: _text(w.status),
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