import 'package:flutter/material.dart';

/// The timer / word-count / score row shown during and after recording.
/// Both screens pass their own labels in — the visual container is shared
/// so the two screens always look and behave consistently.
class SessionStatsBar extends StatelessWidget {
  final String timerLabel;
  final String wordsLabel;
  final String scoreLabel;
  final Color accentColor;
  final Color cardColor;

  const SessionStatsBar({
    Key? key,
    required this.timerLabel,
    required this.wordsLabel,
    required this.scoreLabel,
    required this.accentColor,
    this.cardColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statItem(Icons.timer_outlined, timerLabel, const Color(0xFF2196F3)),
          _divider(),
          _statItem(Icons.text_fields_rounded, wordsLabel, accentColor),
          _divider(),
          _statItem(Icons.analytics_outlined, scoreLabel, accentColor),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    ]);
  }

  Widget _divider() {
    return Container(width: 1, height: 20, color: Colors.grey.shade200);
  }
}