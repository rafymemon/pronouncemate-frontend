import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'progress_analytics_screen.dart';
import 'script_selection_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;
  
  // Data
  String _userName = '';
  int _streakDays = 0;
  int _totalSessions = 0;
  double _bestScore = 0;
  List<Map<String, dynamic>> _recentSessions = [];
  Map<String, dynamic> _quickStats = {};
  List<double> _sparkline = [];
  Map<String, dynamic> _improvement = {};
  List<Map<String, dynamic>> _focusWords = [];
  Map<String, double> _modeScores = {};

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

    final data = await ApiService.getDashboardSummary();

    if (!mounted) return;

    if (data['error'] != null) {
      setState(() {
        _error = data['error'].toString();
        _loading = false;
      });
      return;
    }

    setState(() {
      _userName = data['user']?['name'] ?? 'Learner';
      _streakDays = data['streak_days'] ?? 0;
      _totalSessions = data['total_sessions'] ?? 0;
      _bestScore = (data['best_score'] as num?)?.toDouble() ?? 0;
      _recentSessions = List<Map<String, dynamic>>.from(data['recent_sessions'] ?? []);
      _quickStats = Map<String, dynamic>.from(data['quick_stats'] ?? {});
      _sparkline = List<double>.from((data['sparkline'] as List?)?.map((e) => (e as num).toDouble()) ?? []);
      _improvement = Map<String, dynamic>.from(data['improvement'] ?? {});
      _focusWords = List<Map<String, dynamic>>.from(data['focus_words'] ?? []);
      _modeScores = (data['mode_scores'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ) ?? {};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScriptSelectionScreen()),
        ),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.mic_rounded, color: Colors.white),
        label: const Text('Practice', style: TextStyle(color: Colors.white)),
      ),
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
            Text('Could not load dashboard', style: TextStyle(fontSize: 18, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
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
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _buildQuickStats(),
                const SizedBox(height: 20),
                if (_sparkline.length >= 2) ...[
                  _buildSparklineCard(),
                  const SizedBox(height: 20),
                ],
                if ((_improvement['percentage_change'] as num?)?.toDouble() != 0) ...[
                  _buildImprovementBadge(),
                  const SizedBox(height: 20),
                ],
                if (_focusWords.isNotEmpty) ...[
                  _buildFocusWords(),
                  const SizedBox(height: 20),
                ],
                _buildModeScores(),
                const SizedBox(height: 20),
                _buildRecentSessions(),
                const SizedBox(height: 20),
                _buildAnalyticsLink(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '$_streakDays day${_streakDays == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Best: ${_bestScore.toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick Stats ───────────────────────────────────────
  Widget _buildQuickStats() {
    final stats = [
      _StatItem('$_totalSessions', 'Sessions', Icons.play_circle_filled_rounded, AppColors.primary),
      _StatItem('${_quickStats['words'] ?? 0}', 'Words', Icons.text_fields_rounded, const Color(0xFF16A34A)),
      _StatItem('${_quickStats['errors_corrected'] ?? 0}', 'Fixed', Icons.check_circle_rounded, const Color(0xFF7C3AED)),
      _StatItem(_formatMinutes(_quickStats['minutes'] ?? 0), 'Time', Icons.timer_rounded, const Color(0xFF2563EB)),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.75, // Your aspect ratio change here was great!
      children: stats.map((s) => _statCard(s)).toList(),
    );
  }

  Widget _statCard(_StatItem stat) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      // Wrapped the ENTIRE Column in FittedBox. This guarantees no overflows!
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(stat.icon, color: stat.color, size: 22), 
            const SizedBox(height: 8),
            Text(
              stat.value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: stat.color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              stat.label,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int mins) {
    if (mins < 60) return '${mins}m';
    return '${(mins / 60).toStringAsFixed(1)}h';
  }

  // ── Sparkline ─────────────────────────────────────────
  Widget _buildSparklineCard() {
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
                child: Text('${_sparkline.last.toStringAsFixed(0)}% latest', style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (_sparkline.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: _sparkline.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF3B82F6)]),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [AppColors.accent.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1E293B),
                    getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                      return LineTooltipItem('${spot.y.toStringAsFixed(0)}%', const TextStyle(color: Colors.white, fontSize: 11));
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

  // ── Improvement Badge ─────────────────────────────────
  Widget _buildImprovementBadge() {
    final pct = (_improvement['percentage_change'] as num?)?.toDouble() ?? 0;
    final isPositive = pct >= 0;
    final trend = _improvement['trend'] ?? 'neutral';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive 
            ? [const Color(0xFF0F6E56), const Color(0xFF16A34A)]
            : [const Color(0xFF991B1B), const Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${isPositive ? '+' : ''}${pct.toStringAsFixed(0)}% Improvement', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  trend == 'up' ? 'Your last 5 sessions are better than your first 5!' : 'Keep practicing — improvement takes time.',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Focus Words ───────────────────────────────────────
  Widget _buildFocusWords() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('⚠️ Focus Words', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text('Top ${_focusWords.length}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          ..._focusWords.asMap().entries.map((entry) {
            final word = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    child: Center(child: Text('${entry.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('"${word['word']}"', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                  Text('${word['error_count']} errors', style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Mode Scores ───────────────────────────────────────
  Widget _buildModeScores() {
    final modes = [
      _ModeDisplay('Public Speaking', 'public_speaking', Icons.campaign_rounded, const Color(0xFF1A3A6B)),
      _ModeDisplay('Daily Conversation', 'daily_conversation', Icons.chat_bubble_rounded, const Color(0xFF0F6E56)),
      _ModeDisplay('Script-Based', 'script_based', Icons.description_rounded, const Color(0xFF7C3AED)),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯 Score by Mode', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ...modes.map((m) {
            final score = _modeScores[m.key] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(m.icon, color: m.color, size: 18),
                          const SizedBox(width: 8),
                          Text(m.label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Text('${score.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(m.color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Recent Sessions ─────────────────────────────────
  Widget _buildRecentSessions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Sessions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            if (_recentSessions.isNotEmpty)
              TextButton(onPressed: () {}, child: const Text('See All', style: TextStyle(fontSize: 13))),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentSessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
            child: const Center(child: Text('No sessions yet. Start your first practice!', style: TextStyle(color: AppColors.textSecondary, fontSize: 14))),
          )
        else
          ..._recentSessions.map((session) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
              boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _modeColor(session['mode']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(_modeIcon(session['mode']), color: _modeColor(session['mode']), size: 20),
              ),
              title: Text(session['title'] ?? 'Practice', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
              subtitle: Text(session['date_label'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${(session['score'] as num?)?.toStringAsFixed(0) ?? 0}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent)),
                  Text(session['grade'] ?? 'D', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          )),
      ],
    );
  }

  Color _modeColor(String? mode) {
    switch (mode) {
      case 'public_speaking': return const Color(0xFF1A3A6B);
      case 'daily_conversation': return const Color(0xFF0F6E56);
      case 'script_based': return const Color(0xFF7C3AED);
      default: return AppColors.primary;
    }
  }

  IconData _modeIcon(String? mode) {
    switch (mode) {
      case 'public_speaking': return Icons.campaign_rounded;
      case 'daily_conversation': return Icons.chat_bubble_rounded;
      case 'script_based': return Icons.description_rounded;
      default: return Icons.play_arrow_rounded;
    }
  }

  // ── Analytics Link ────────────────────────────────────
  Widget _buildAnalyticsLink() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProgressAnalyticsScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detailed Analytics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text('Full breakdowns, charts, and insights', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textHint, size: 16),
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
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

// ── Helper Classes ──────────────────────────────────────

class _StatItem {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  _StatItem(this.value, this.label, this.icon, this.color);
}

class _ModeDisplay {
  final String label;
  final String key;
  final IconData icon;
  final Color color;
  _ModeDisplay(this.label, this.key, this.icon, this.color);
}