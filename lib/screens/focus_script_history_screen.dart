// lib/screens/focus_script_history_screen.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class FocusScriptHistoryScreen extends StatefulWidget {
  const FocusScriptHistoryScreen({super.key});

  @override
  State<FocusScriptHistoryScreen> createState() => _FocusScriptHistoryScreenState();
}

class _FocusScriptHistoryScreenState extends State<FocusScriptHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _scripts = [];
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final results = await Future.wait([
      ApiService.getFocusScriptHistory(),
      ApiService.getFocusScriptStats(),
    ]);

    if (!mounted) return;

    final historyData = results[0];
    final statsData = results[1];

    if (historyData['error'] != null) {
      setState(() {
        _error = historyData['error'].toString();
        _loading = false;
      });
      return;
    }

    setState(() {
      _scripts = List<Map<String, dynamic>>.from(historyData['scripts'] ?? []);
      _stats = statsData['error'] == null ? statsData : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Focus Script History',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Could not load history',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_scripts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No Focus Scripts yet',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Keep practicing — a targeted script will appear once recurring errors add up.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_stats != null && (_stats!['total_completed'] as int? ?? 0) > 0) ...[
              _StatsSummaryCard(stats: _stats!),
              const SizedBox(height: 20),
            ],
            const Text('History',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ..._scripts.map((s) => _FocusScriptHistoryCard(script: s)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// STATS SUMMARY — the thesis evaluation headline
// ═══════════════════════════════════════════════════════

class _StatsSummaryCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsSummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats['total_completed'] as int? ?? 0;
    final avgPre = (stats['avg_pre_error_rate'] as num?)?.toDouble() ?? 0;
    final avgPost = (stats['avg_post_error_rate'] as num?)?.toDouble() ?? 0;
    final avgImprovement = (stats['avg_improvement_pct'] as num?)?.toDouble() ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Remediation Effectiveness',
              style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _statBlock('$total', 'Completed')),
              Expanded(child: _statBlock('${avgPre.toStringAsFixed(0)}%', 'Avg. Before')),
              Expanded(child: _statBlock('${avgPost.toStringAsFixed(0)}%', 'Avg. After')),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_down_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Targeted practice reduced repeat-error rate by ${avgImprovement.toStringAsFixed(1)} points on average.',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBlock(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// HISTORY CARD — one Focus Script, expandable
// ═══════════════════════════════════════════════════════

class _FocusScriptHistoryCard extends StatefulWidget {
  final Map<String, dynamic> script;
  const _FocusScriptHistoryCard({required this.script});

  @override
  State<_FocusScriptHistoryCard> createState() => _FocusScriptHistoryCardState();
}

class _FocusScriptHistoryCardState extends State<_FocusScriptHistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.script;
    final completed = s['completed'] == true;
    final sourceWords = List<String>.from(s['source_words'] ?? []);
    final regressionWords = List<String>.from(s['regression_words'] ?? []);
    final preRate = (s['pre_error_rate'] as num?)?.toDouble();
    final postRate = (s['post_error_rate'] as num?)?.toDouble();
    final generatedAt = DateTime.tryParse(s['generated_at']?.toString() ?? '');
    final scriptText = s['script_text']?.toString() ?? '';

    double? improvement;
    if (preRate != null && postRate != null) {
      improvement = preRate - postRate;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: completed ? const Color(0xFFDCFCE7) : const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      completed ? 'Completed' : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: completed ? const Color(0xFF16A34A) : const Color(0xFF856404),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (generatedAt != null)
                    Text(
                      _formatDate(generatedAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...sourceWords.map((w) => _wordChip(w, const Color(0xFFEF4444), const Color(0xFFFEF2F2))),
                  ...regressionWords.map((w) => _wordChip(w, const Color(0xFF7C3AED), const Color(0xFFF3E8FF), suffix: ' (retest)')),
                ],
              ),
              if (completed && preRate != null && postRate != null) ...[
                const SizedBox(height: 14),
                _improvementBar(preRate, postRate, improvement!),
              ],
              if (_expanded) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                const Text('Script',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text(
                  scriptText,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _wordChip(String word, Color textColor, Color bgColor, {String suffix = ''}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text('"$word"$suffix',
          style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w600)),
    );
  }

  Widget _improvementBar(double preRate, double postRate, double improvement) {
    final isPositive = improvement >= 0;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 8, color: const Color(0xFFF1F5F9)),
                FractionallySizedBox(
                  widthFactor: (postRate / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${preRate.toStringAsFixed(0)}% → ${postRate.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}