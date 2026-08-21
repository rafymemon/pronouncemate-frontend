import 'package:flutter/material.dart';
import '../models/word_status.dart';

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
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: words.map((w) {
          final tappable = onWordTap != null &&
              (w.status == WordStatus.error || w.status == WordStatus.skipped) &&
              w.tip != null;
          return WidgetSpan(
            child: GestureDetector(
              onTap: tappable ? () => onWordTap!(w) : null,
              child: Container(
                margin: const EdgeInsets.only(right: 6, bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _bg(w.status),
                  borderRadius: BorderRadius.circular(6),
                  border: w.status == WordStatus.error || w.status == WordStatus.skipped
                      ? Border(bottom: BorderSide(color: _underline(w.status), width: 2))
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