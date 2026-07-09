// lib/screens/progress_analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ProgressAnalyticsScreen extends StatefulWidget {
  const ProgressAnalyticsScreen({super.key});

  @override
  State<ProgressAnalyticsScreen> createState() => _ProgressAnalyticsScreenState();
}

class _ProgressAnalyticsScreenState extends State<ProgressAnalyticsScreen> {
  bool _loading = true;
  String? _error;

  // Data
  List<SessionData> _sessions = [];
  List<WordError> _topErrors = [];
  ErrorBreakdown _errorBreakdown = ErrorBreakdown.empty();
  Map<String, double> _modeScores = {};
  ImprovementStats _improvement = ImprovementStats(firstAvg: 0, lastAvg: 0, percentageChange: 0);
  TotalStats _totalStats = TotalStats(sessions: 0, words: 0, errors: 0, minutes: 0);

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

    final data = await ApiService.getProgressAnalytics();

    if (!mounted) return;

    if (data['error'] != null) {
      setState(() {
        _error = data['error'].toString();
        _loading = false;
      });
      return;
    }

    setState(() {
      _sessions = (data['sessions'] as List? ?? [])
          .map((e) => SessionData.fromJson(e as Map<String, dynamic>))
          .toList();
      _topErrors = (data['top_errors'] as List? ?? [])
          .map((e) => WordError.fromJson(e as Map<String, dynamic>))
          .toList();
      _errorBreakdown = ErrorBreakdown.fromJson(data['error_breakdown'] as Map<String, dynamic>? ?? {});
      _modeScores = (data['mode_scores'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ) ?? {};
      _improvement = ImprovementStats.fromJson(data['improvement'] as Map<String, dynamic>? ?? {});
      _totalStats = TotalStats.fromJson(data['total_stats'] as Map<String, dynamic>? ?? {});
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detailed Analytics', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareProgress,
          ),
        ],
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
            Text('Could not load analytics', style: TextStyle(fontSize: 18, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
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

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImprovementCard(),
            const SizedBox(height: 16),
            if (_sessions.length >= 2) _buildAccuracyTrendChart(),
            if (_sessions.length >= 2) const SizedBox(height: 16),
            _buildScoreByMode(),
            const SizedBox(height: 16),
            _buildErrorPieChart(),
            const SizedBox(height: 16),
            _buildTopMispronouncedWords(),
            const SizedBox(height: 16),
            _buildStatsGrid(),
            const SizedBox(height: 16),
            _buildSDGBadge(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Improvement Card ──────────────────────────────────
  Widget _buildImprovementCard() {
    final isPositive = _improvement.percentageChange >= 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Overall Improvement', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(
                    '${isPositive ? '+' : ''}${_improvement.percentageChange.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _improvementStat('First 5 sessions', _improvement.firstAvg),
                  const SizedBox(height: 8),
                  _improvementStat('Last 5 sessions', _improvement.lastAvg),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: isPositive ? Colors.greenAccent : Colors.redAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPositive
                      ? "You're improving! Keep practicing consistently."
                      : "Keep going! Consistent practice leads to improvement.",
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _improvementStat(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 2),
        Text('${value.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }

  // ── Accuracy Trend Chart ──────────────────────────────
  Widget _buildAccuracyTrendChart() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Accuracy Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                child: const Text('↗ Improving', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (_sessions.length / 4).ceil().toDouble(),
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < _sessions.length) {
                          return Text('S${idx + 1}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (_sessions.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: _sessions.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.accuracy)).toList(),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        final isLast = index == _sessions.length - 1;
                        return FlDotCirclePainter(
                          radius: isLast ? 5 : 4,
                          color: isLast ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [const Color(0xFF2563EB).withValues(alpha: 0.2), const Color(0xFF2563EB).withValues(alpha: 0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => const Color(0xFF1E293B),
                    getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                      return LineTooltipItem('${spot.y.toStringAsFixed(1)}%', const TextStyle(color: Colors.white, fontSize: 12));
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Score by Mode ─────────────────────────────────────
  Widget _buildScoreByMode() {
    final modes = [
      _ModeScore('Public Speaking', _modeScores['public_speaking'] ?? 0, const Color(0xFF1A3A6B)),
      _ModeScore('Daily Conversation', _modeScores['daily_conversation'] ?? 0, const Color(0xFF0F6E56)),
      _ModeScore('Script-Based', _modeScores['script_based'] ?? 0, const Color(0xFF7C3AED)),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Score by Mode', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ...modes.map((m) => _modeBar(m)),
        ],
      ),
    );
  }

  Widget _modeBar(_ModeScore mode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(mode.label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
              Text('${mode.score.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: mode.score / 100,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(mode.color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // ── Error Pie Chart ───────────────────────────────────
  Widget _buildErrorPieChart() {
    final total = _errorBreakdown.total;
    if (total == 0) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Error Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle, size: 48, color: Colors.green.shade300),
                  const SizedBox(height: 12),
                  const Text('No errors recorded yet!', style: TextStyle(fontSize: 15, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    final sections = [
      _pieSection('Substitution', _errorBreakdown.substitution, total, const Color(0xFFEF4444)),
      _pieSection('Omission', _errorBreakdown.deletion, total, const Color(0xFFF59E0B)),
      _pieSection('Stress', _errorBreakdown.stress, total, const Color(0xFF8B5CF6)),
      _pieSection('Insertion', _errorBreakdown.insertion, total, const Color(0xFF06B6D4)),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Error Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 35,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _pieLegend('Substitution', _errorBreakdown.substitution, total, const Color(0xFFEF4444)),
                    _pieLegend('Omission', _errorBreakdown.deletion, total, const Color(0xFFF59E0B)),
                    _pieLegend('Stress', _errorBreakdown.stress, total, const Color(0xFF8B5CF6)),
                    _pieLegend('Insertion', _errorBreakdown.insertion, total, const Color(0xFF06B6D4)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100) : 0;
    return PieChartSectionData(
      value: count.toDouble(),
      title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
      radius: 40,
      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      color: color,
    );
  }

  Widget _pieLegend(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                Text('$count errors ($pct%)', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Mispronounced Words (Top 10) ──────────────────
  Widget _buildTopMispronouncedWords() {
    if (_topErrors.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top Mispronounced Words', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(Icons.emoji_events, size: 48, color: Colors.amber.shade300),
                  const SizedBox(height: 12),
                  const Text('Perfect pronunciation so far!', style: TextStyle(fontSize: 15, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    final colors = [
      const _WordColor(Color(0xFFEF4444), Color(0xFFFEF2F2), Color(0xFFFECACA)),
      const _WordColor(Color(0xFFF97316), Color(0xFFFFF7ED), Color(0xFFFED7AA)),
      const _WordColor(Color(0xFFEAB308), Color(0xFFFFFBEB), Color(0xFFFDE68A)),
      const _WordColor(Color(0xFF22C55E), Color(0xFFF0FDF4), Color(0xFFBBF7D0)),
      const _WordColor(Color(0xFF3B82F6), Color(0xFFEFF6FF), Color(0xFFBFDBFE)),
      const _WordColor(Color(0xFF8B5CF6), Color(0xFFF5F3FF), Color(0xFFDDD6FE)),
      const _WordColor(Color(0xFFEC4899), Color(0xFFFDF2F8), Color(0xFFFBCFE8)),
      const _WordColor(Color(0xFF14B8A6), Color(0xFFF0FDFA), Color(0xFF99F6E4)),
      const _WordColor(Color(0xFF6366F1), Color(0xFFEEF2FF), Color(0xFFC7D2FE)),
      const _WordColor(Color(0xFF84CC16), Color(0xFFF7FEE7), Color(0xFFD9F99D)),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Top Mispronounced Words', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20)),
                child: const Text('Focus here', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._topErrors.asMap().entries.map((entry) {
            final idx = entry.key;
            final word = entry.value;
            final c = colors[idx.clamp(0, colors.length - 1)];
            return _wordErrorCard(word, idx + 1, c);
          }),
        ],
      ),
    );
  }

  Widget _wordErrorCard(WordError word, int rank, _WordColor colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.border)),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
            child: Center(child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"${word.word}"', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Wrong ${word.errorCount}/${word.totalCount} times', style: TextStyle(fontSize: 11, color: colors.accent)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${word.errorRate.toStringAsFixed(0)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.accent)),
              const Text('error rate', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stats Grid ────────────────────────────────────────
  Widget _buildStatsGrid() {
    final stats = [
      _GridStat('${_totalStats.sessions}', 'Total Sessions', const Color(0xFF1A3A6B)),
      _GridStat('${_totalStats.words}', 'Words Practiced', const Color(0xFF16A34A)),
      _GridStat('${_totalStats.errors}', 'Errors Corrected', const Color(0xFF7C3AED)),
      _GridStat('${(_totalStats.minutes / 60).toStringAsFixed(1)}h', 'Practice Time', const Color(0xFF2563EB)),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: stats.map((s) => _gridItem(s)).toList(),
    );
  }

  Widget _gridItem(_GridStat stat) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(stat.value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: stat.color)),
          const SizedBox(height: 4),
          Text(stat.label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  // ── SDG 4 Badge ───────────────────────────────────────
  Widget _buildSDGBadge() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F6E56), Color(0xFF16A34A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: const Column(
        children: [
          Text('🌍 Supporting SDG 4: Quality Education', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          SizedBox(height: 4),
          Text('Your progress data helps improve learning outcomes worldwide', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }

  // ── Share ─────────────────────────────────────────────
  void _shareProgress() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Share Your Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.image, color: AppColors.primary),
              title: const Text('Share as Image'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet, color: AppColors.primary),
              title: const Text('Share as Text'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

// ── Data Models ─────────────────────────────────────────

class SessionData {
  final int id;
  final double accuracy;
  final int wordCount;
  final int durationMinutes;
  final String mode;
  final DateTime date;

  SessionData({required this.id, required this.accuracy, required this.wordCount, required this.durationMinutes, required this.mode, required this.date});

  factory SessionData.fromJson(Map<String, dynamic> json) => SessionData(
        id: json['id'] ?? 0,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
        wordCount: json['word_count'] ?? 0,
        durationMinutes: json['duration_minutes'] ?? 0,
        mode: json['mode'] ?? 'unknown',
        date: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}

class WordError {
  final String word;
  final int errorCount;
  final int totalCount;

  WordError({required this.word, required this.errorCount, required this.totalCount});

  double get errorRate => totalCount > 0 ? (errorCount / totalCount) * 100 : 0;

  factory WordError.fromJson(Map<String, dynamic> json) => WordError(
        word: json['word'] ?? '',
        errorCount: json['error_count'] ?? 0,
        totalCount: (json['total_count'] as num?)?.toInt() ?? 1,
      );
}

class ErrorBreakdown {
  final int substitution;
  final int deletion;
  final int stress;
  final int insertion;

  ErrorBreakdown({required this.substitution, required this.deletion, required this.stress, required this.insertion});

  int get total => substitution + deletion + stress + insertion;

  factory ErrorBreakdown.empty() => ErrorBreakdown(substitution: 0, deletion: 0, stress: 0, insertion: 0);

  factory ErrorBreakdown.fromJson(Map<String, dynamic> json) => ErrorBreakdown(
        substitution: (json['substitution'] as num?)?.toInt() ?? 0,
        deletion: (json['deletion'] as num?)?.toInt() ?? 0,
        stress: (json['stress'] as num?)?.toInt() ?? 0,
        insertion: (json['insertion'] as num?)?.toInt() ?? 0,
      );
}

class ImprovementStats {
  final double firstAvg;
  final double lastAvg;
  final double percentageChange;

  ImprovementStats({required this.firstAvg, required this.lastAvg, required this.percentageChange});

  factory ImprovementStats.fromJson(Map<String, dynamic> json) => ImprovementStats(
        firstAvg: (json['first_avg'] as num?)?.toDouble() ?? 0.0,
        lastAvg: (json['last_avg'] as num?)?.toDouble() ?? 0.0,
        percentageChange: (json['percentage_change'] as num?)?.toDouble() ?? 0.0,
      );
}

class TotalStats {
  final int sessions;
  final int words;
  final int errors;
  final int minutes;

  TotalStats({required this.sessions, required this.words, required this.errors, required this.minutes});

  factory TotalStats.fromJson(Map<String, dynamic> json) => TotalStats(
        sessions: (json['sessions'] as num?)?.toInt() ?? 0,
        words: (json['words'] as num?)?.toInt() ?? 0,
        errors: (json['errors'] as num?)?.toInt() ?? 0,
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      );
}

class _ModeScore {
  final String label;
  final double score;
  final Color color;
  _ModeScore(this.label, this.score, this.color);
}

class _WordColor {
  final Color accent;
  final Color bg;
  final Color border;
  const _WordColor(this.accent, this.bg, this.border);
}

class _GridStat {
  final String value;
  final String label;
  final Color color;
  _GridStat(this.value, this.label, this.color);
}