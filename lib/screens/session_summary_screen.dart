import 'package:flutter/material.dart';
import 'active_session_screens.dart';

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Receive data from ActiveSessionScreen
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;

    final words = (args['words'] as List?)
        ?.whereType<WordResult>()
        .toList() ??
      <WordResult>[];
    final sessionScore = args['sessionScore'] as double;
    final script       = args['script']       as String;

    final correct  = words.where((w) => w.status == WordStatus.correct).length;
    final errors   = words.where((w) => w.status == WordStatus.error).toList();
    final grade    = _getGrade(sessionScore);
    final gradeColor = _gradeColor(sessionScore);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Session Summary"),
        backgroundColor: const Color(0xFF1A3A6B),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Score card ────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A6B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                Text(grade,
                    style: TextStyle(
                        fontSize: 52, fontWeight: FontWeight.bold,
                        color: gradeColor)),
                const SizedBox(height: 4),
                Text("${sessionScore.toStringAsFixed(1)}%",
                    style: const TextStyle(
                        fontSize: 28, color: Colors.white,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _scoreItem("✓  $correct", "Correct", Colors.greenAccent),
                    _scoreItem("✗  ${errors.length}", "Errors", Colors.redAccent),
                    _scoreItem("${words.length}", "Total", Colors.white70),
                  ],
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Errors list ───────────────────────────────
            if (errors.isNotEmpty) ...[
              const Text("Errors Detected",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                      color: Color(0xFF1A3A6B))),
              const SizedBox(height: 12),
              ...errors.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(e.word,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold,
                              color: Colors.red.shade700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.type.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1)),
                          Text("Score: ${e.score.toStringAsFixed(0)}%",
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF475569))),
                          if (e.explanation != null)
                            Text(e.explanation!,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],

            if (errors.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
                  const SizedBox(width: 12),
                  const Text("Perfect pronunciation! No errors detected.",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ]),
              ),

            const SizedBox(height: 32),

            // ── Action buttons ────────────────────────────
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActiveSessionScreen(
                          scriptText: script, sessionTitle: "Retry Session"),
                    ),
                  ),
                  icon: const Icon(Icons.replay),
                  label: const Text("Retry"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF1A3A6B)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/home', (_) => false),
                  icon: const Icon(Icons.home),
                  label: const Text("Home"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A3A6B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _scoreItem(String value, String label, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 20,
          fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
    ]);
  }

  String _getGrade(double score) {
    if (score >= 90) return "A+";
    if (score >= 80) return "A";
    if (score >= 70) return "B";
    if (score >= 60) return "C";
    return "D";
  }

  Color _gradeColor(double score) {
    if (score >= 80) return Colors.greenAccent;
    if (score >= 60) return Colors.yellowAccent;
    return Colors.redAccent;
  }
}