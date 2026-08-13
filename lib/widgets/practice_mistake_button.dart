import 'package:flutter/material.dart';
import '../models/practice_models.dart';
import '../theme/app_theme.dart';

/// Prompt shown on the session summary screen after mistakes are detected,
/// inviting the user into a focused Practice Mistakes session.
class PracticeMistakesButton extends StatelessWidget {
  final MistakeSummary mistakeSummary;
  final VoidCallback onPressed;

  const PracticeMistakesButton({
    Key? key,
    required this.mistakeSummary,
    required this.onPressed,
  }) : super(key: key);

  String _severityLabel() {
    final breakdown = mistakeSummary.severityBreakdown;
    final critical = breakdown['critical'] ?? 0;
    final major = breakdown['major'] ?? 0;

    if (critical > 0) return '$critical critical, $major major';
    if (major > 0) return '$major major issue${major == 1 ? '' : 's'}';
    return 'Minor issues to polish';
  }

  @override
  Widget build(BuildContext context) {
    if (!mistakeSummary.offerPractice) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD9A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE1B3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    color: Color(0xFFB45309), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${mistakeSummary.mistakeCount} word${mistakeSummary.mistakeCount == 1 ? '' : 's'} to practice',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C2D12),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _severityLabel(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9A5A2E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (mistakeSummary.words.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: mistakeSummary.words.take(5).map((w) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFD9A0)),
                  ),
                  child: Text(
                    w,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7C2D12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.mic_rounded, size: 18),
              label: const Text('Practice These Words',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandOlive,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}