// widgets/mistake_word_chip.dart
// Color-coded chip showing word and error type

import 'package:flutter/material.dart';

class MistakeWordChip extends StatelessWidget {
  final String word;
  final String errorType;
  final double score;
  final VoidCallback? onTap;

  const MistakeWordChip({
    Key? key,
    required this.word,
    required this.errorType,
    required this.score,
    this.onTap,
  }) : super(key: key);

  Color get _color {
    if (score >= 85) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData get _icon {
    switch (errorType) {
      case 'substitution':
        return Icons.swap_horiz;
      case 'omission':
        return Icons.remove_circle;
      case 'insertion':
        return Icons.add_circle;
      case 'skipped':
        return Icons.skip_next;
      case 'stress':
        return Icons.record_voice_over;
      case 'minor':
        // Close-but-not-exact acoustic read — distinct from a hard error
        // so it doesn't visually read the same as substitution/omission.
        return Icons.info_outline;
      default:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(_icon, size: 18, color: _color),
      label: Text(
        word,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: _color.withOpacity(0.1),
      side: BorderSide(color: _color.withOpacity(0.3)),
      onPressed: onTap,
    );
  }
}