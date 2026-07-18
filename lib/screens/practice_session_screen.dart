// screens/practice_session_screen.dart
// Full practice session flow for mistake words

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/practice_models.dart';
import '../services/practice_api_service.dart';
import '../widgets/mistake_word_chip.dart';
import '../services/recording_service.dart';

class PracticeSessionScreen extends StatefulWidget {
  final List<MistakeWord> mistakeWords;
  final String originalSessionId;
  final String mode;

  const PracticeSessionScreen({
    Key? key,
    required this.mistakeWords,
    required this.originalSessionId,
    this.mode = 'sentences',
  }) : super(key: key);

  @override
  _PracticeSessionScreenState createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  final RecordingService _rec = RecordingService();
  
  bool _isRecording = false;
  bool _isProcessing = false;
  PracticeResult? _result;
  String? _practiceScript;

  @override
  void initState() {
    super.initState();
    _loadPracticeScript();
  }

  @override
  void dispose() {
    _rec.dispose();
    super.dispose();
  }

  Future<void> _loadPracticeScript() async {
    final response = await PracticeApiService.getPracticeScript(
      widget.mistakeWords,
      mode: widget.mode,
    );
    if (response['success']) {
      setState(() {
        _practiceScript = response['practice_script'];
      });
    }
  }

  Future<void> _submitPractice(File audioFile) async {
    setState(() => _isProcessing = true);

    try {
      final result = await PracticeApiService.submitPractice(
        audioFile,
        widget.mistakeWords,
        widget.originalSessionId,
        mode: widget.mode,
      );

      setState(() {
        _result = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _stopAndSubmit() async {
    if (!_isRecording) return;
    
    setState(() => _isRecording = false);
    final file = await _rec.stop();
    
    if (file != null) {
      _submitPractice(file);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save recording')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Mistakes'),
        backgroundColor: Colors.deepOrange,
      ),
      body: _result != null ? _buildResultView() : _buildPracticeView(),
    );
  }

  // ── FIXED: Wrapped in SingleChildScrollView to prevent overflow ──
  Widget _buildPracticeView() {
    return SingleChildScrollView(  // ← ADDED
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_practiceScript != null) ...[
              const Text(
                'Practice Script:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _practiceScript!,
                  style: const TextStyle(fontSize: 20, height: 1.5),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Words to Practice:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.mistakeWords.map((mw) => 
                MistakeWordChip(
                  word: mw.word,
                  errorType: mw.errorType,
                  score: mw.perWordScore,
                ),
              ).toList(),
            ),
            const SizedBox(height: 32),  // ← CHANGED: was const Spacer()
            Center(
              child: GestureDetector(
                onTapDown: (_) async {
                  if (await _rec.hasPermission()) {
                    await _rec.start();
                    setState(() => _isRecording = true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Microphone permission required')),
                    );
                  }
                },
                onTapUp: (_) => _stopAndSubmit(),
                onTapCancel: () => _stopAndSubmit(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isRecording ? 100 : 80,
                  height: _isRecording ? 100 : 80,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : Colors.deepOrange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? Colors.red : Colors.deepOrange)
                            .withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 24),  // ← ADDED: bottom padding for scroll
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    final result = _result!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.celebration, color: Colors.green[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.message,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  result.score.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                Text(
                  '${result.grade} — ${result.gradeLabel}',
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildProgressSection('Cleared', result.clearedWords, Colors.green, Icons.check_circle),
          _buildProgressSection('Improved', result.improvedWords, Colors.orange, Icons.trending_up),
          _buildProgressSection('Still Struggling', result.stillStruggling, Colors.red, Icons.warning),
          const SizedBox(height: 24),
          if (result.stillStruggling.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                final remaining = result.stillStruggling
                    .map((w) => MistakeWord(
                          word: w['word'],
                          errorType: w['error_type'],
                          severity: w['severity'],
                          perWordScore: w['current_score'],
                          refPhonemes: [],
                          predPhonemes: [],
                          explanation: '',
                        ))
                    .toList();

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PracticeSessionScreen(
                      mistakeWords: remaining,
                      originalSessionId: widget.originalSessionId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Practice Remaining Words'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(String title, List<dynamic> items, Color color, IconData icon) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              '$title (${items.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Text(
                item['word'][0].toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(item['word']),
            subtitle: item['improvement'] != null
                ? Text('Improved by ${item['improvement']} points')
                : null,
            trailing: Text(
              '${item['current_score']?.toStringAsFixed(0) ?? 'N/A'}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        )).toList(),
        const SizedBox(height: 16),
      ],
    );
  }
}