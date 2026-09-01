import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import 'progress_analytics_screen.dart';
import 'active_session_screen.dart';
import 'focus_script_history_screen.dart';

// ═══════════════════════════════════════════════════════
// TOP-LEVEL HELPERS (shared across widgets in this file)
// ═══════════════════════════════════════════════════════

Color _modeColorFor(String? mode) {
  switch (mode) {
    case 'public_speaking':
      return AppColors.primary;
    case 'daily_conversation':
      return AppColors.accent;
    case 'script_based':
      return AppColors.success;
    default:
      return AppColors.primary;
  }
}

IconData _modeIconFor(String? mode) {
  switch (mode) {
    case 'public_speaking':
      return Icons.campaign_rounded;
    case 'daily_conversation':
      return Icons.chat_bubble_rounded;
    case 'script_based':
      return Icons.description_rounded;
    default:
      return Icons.play_arrow_rounded;
  }
}

Color _scoreColorFor(dynamic score) {
  final s = (score as num?)?.toDouble() ?? 0;
  if (s >= 80) return const Color(0xFF16A34A);
  if (s >= 60) return const Color(0xFF2563EB);
  if (s >= 40) return const Color(0xFFF59E0B);
  return const Color(0xFFEF4444);
}

/// Lays out a card title + trailing control(s) responsively.
/// Falls back to a stacked layout on narrow widths instead of overflowing.
class _ResponsiveCardHeader extends StatelessWidget {
  final Widget title;
  final Widget trailing;
  final double breakpoint;
  const _ResponsiveCardHeader(
      {required this.title, required this.trailing, this.breakpoint = 300});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: trailing),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            trailing,
          ],
        );
      },
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
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

  // ── Improvement Phase data ─────────────────────────
  Map<String, dynamic>? _progression;
  Map<String, dynamic>? _focusScript;
  // Animation controllers
  late AnimationController _headerAnim;
  late AnimationController _streakPulse;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _streakPulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _streakPulse.dispose();
    super.dispose();
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
      _recentSessions =
          List<Map<String, dynamic>>.from(data['recent_sessions'] ?? []);
      _quickStats = Map<String, dynamic>.from(data['quick_stats'] ?? {});
      _sparkline = List<double>.from(
          (data['sparkline'] as List?)?.map((e) => (e as num).toDouble()) ??
              []);
      _improvement = Map<String, dynamic>.from(data['improvement'] ?? {});
      _focusWords = List<Map<String, dynamic>>.from(data['focus_words'] ?? []);
      _modeScores = (data['mode_scores'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {};
      _loading = false;
    });

    _headerAnim.forward();
    _loadImprovementData();
  }

  // Fetched separately and non-blocking — a failure here shouldn't
  // prevent the core dashboard (which already loaded above) from showing.
  Future<void> _loadImprovementData() async {
    final results = await Future.wait([
      ApiService.getProgressionStatus(),
      ApiService.getLatestFocusScript(),
    ]);

    if (!mounted) return;

    final progressionData = results[0];
    final focusScriptData = results[1];

    setState(() {
      _progression = progressionData['error'] == null ? progressionData : null;
      _focusScript = focusScriptData['focus_script'] as Map<String, dynamic>?;
    });
  }

  void _startFocusScript() {
    if (_focusScript == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveSessionScreen(
          scriptText: _focusScript!['script_text'] as String,
          sessionTitle: 'Focus Script',
        ),
      ),
    ).then((_) => _loadData()); // refresh in case a new one was generated
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Could not load dashboard',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accent,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildQuickStatsCarousel(),
                const SizedBox(height: 24),
                if (_progression != null) ...[
                  _ProgressionPanel(progression: _progression!),
                  const SizedBox(height: 24),
                ],
                if (_focusScript != null) ...[
                  _FocusScriptCard(
                    focusScript: _focusScript!,
                    onStart: _startFocusScript,
                  ),
                  const SizedBox(height: 24),
                ],
                if (_sparkline.length >= 2) ...[
                  _buildWeeklyHeatmap(),
                  const SizedBox(height: 24),
                ],
                if ((_improvement['percentage_change'] as num?)?.toDouble() !=
                    0) ...[
                  _buildImprovementBadge(),
                  const SizedBox(height: 24),
                ],
                _ModePerformanceCard(modeScores: _modeScores),
                const SizedBox(height: 24),
                if (_focusWords.isNotEmpty) ...[
                  _FocusWordsSection(words: _focusWords),
                  const SizedBox(height: 24),
                ],
                _RecentSessionsSection(sessions: _recentSessions),
                const SizedBox(height: 24),
                _buildAnalyticsLink(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HEADER — Animated greeting with streak badge
  // ═══════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: FadeTransition(
        opacity: _headerAnim.drive(Tween(begin: 0.0, end: 1.0)),
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero)
                  .animate(
            CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _userName,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedBuilder(
                    animation: _streakPulse,
                    builder: (context, child) {
                      final val = _streakPulse.value.clamp(0.0, 1.0);
                      final opacity = Tween(begin: 0.7, end: 1.0)
                          .transform(val)
                          .clamp(0.0, 1.0);
                      return Opacity(
                        opacity: opacity,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.orangeAccent.withValues(alpha: 0.3),
                              blurRadius: 12)
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              color: Colors.orangeAccent, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            '$_streakDays',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _headerChip(Icons.emoji_events_rounded,
                      'Best ${_bestScore.toStringAsFixed(0)}%', Colors.amber),
                  _headerChip(
                      Icons.star_rounded,
                      'Lvl ${_levelFromSessions(_totalSessions)}',
                      const Color(0xFFA78BFA)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ],
      ),
    );
  }

  int _levelFromSessions(int sessions) => (sessions / 5).ceil().clamp(1, 99);

  // ═══════════════════════════════════════════════════════
  // QUICK STATS — Horizontal glassmorphic carousel
  // ═══════════════════════════════════════════════════════

  Widget _buildQuickStatsCarousel() {
    final stats = [
      _StatItem('$_totalSessions', 'Sessions', Icons.play_circle_filled_rounded,
          AppColors.primary),
      _StatItem('${_quickStats['words'] ?? 0}', 'Words',
          Icons.text_fields_rounded, const Color(0xFF16A34A)),
      _StatItem('${_quickStats['errors_corrected'] ?? 0}', 'Fixed',
          Icons.check_circle_rounded, const Color(0xFF7C3AED)),
      _StatItem(_formatMinutes(_quickStats['minutes'] ?? 0), 'Time',
          Icons.timer_rounded, const Color(0xFF2563EB)),
    ];

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, idx) {
          final s = stats[idx];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 600 + idx * 100),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              final safeT = t.clamp(0.0, 1.0);
              return Opacity(
                opacity: safeT,
                child: Transform.translate(
                  offset: Offset(0, (1 - safeT) * 20),
                  child: child,
                ),
              );
            },
            child: Container(
              width: 120,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    s.color.withValues(alpha: 0.08),
                    s.color.withValues(alpha: 0.02)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: s.color.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                      color: s.color.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: s.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: Icon(s.icon, color: s.color, size: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: s.color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // WEEKLY HEATMAP — Unique visual using sparkline data
  // ═══════════════════════════════════════════════════════

  Widget _buildWeeklyHeatmap() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final values = _sparkline.length >= 7
        ? _sparkline.sublist(_sparkline.length - 7)
        : _sparkline;
    final displayValues = values.isEmpty ? List.filled(7, 0.0) : values;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResponsiveCardHeader(
            title: const Text('Weekly Activity',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${_sparkline.length} sessions',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellSize =
                  ((constraints.maxWidth - 6 * 8) / 7).clamp(24.0, 36.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (idx) {
                  final val =
                      idx < displayValues.length ? displayValues[idx] : 0.0;
                  final intensity = (val / 100).clamp(0.05, 1.0);
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 400 + idx * 80),
                    curve: Curves.easeOutBack,
                    builder: (context, t, child) {
                      final safeT = t.clamp(0.0, 1.0);
                      return Opacity(
                        opacity: safeT,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: cellSize,
                              height: cellSize,
                              decoration: BoxDecoration(
                                color: Color.lerp(const Color(0xFFF1F5F9),
                                    AppColors.accent, intensity * safeT),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: intensity > 0.6
                                    ? [
                                        BoxShadow(
                                            color: AppColors.accent
                                                .withValues(alpha: 0.25),
                                            blurRadius: 8)
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${val.toInt()}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: intensity > 0.4
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(days[idx],
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      );
                    },
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // IMPROVEMENT — Slide-in banner
  // ═══════════════════════════════════════════════════════

  Widget _buildImprovementBadge() {
    final pct = (_improvement['percentage_change'] as num?)?.toDouble() ?? 0;
    final isPositive = pct >= 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final safeT = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: safeT,
          child: Transform.translate(
            offset: Offset((1 - safeT) * -40, 0),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPositive
                ? [const Color(0xFF059669), const Color(0xFF10B981)]
                : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isPositive
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444))
                  .withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(
                  isPositive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: Colors.white,
                  size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isPositive ? '+' : ''}${pct.toStringAsFixed(0)}% vs Last Week',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPositive
                        ? 'Your trajectory is climbing. Keep the rhythm!'
                        : 'Consistency beats intensity. Show up today!',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ANALYTICS LINK
  // ═══════════════════════════════════════════════════════

  Widget _buildAnalyticsLink() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProgressAnalyticsScreen()),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          final safeT = t.clamp(0.0, 1.0);
          return Opacity(
            opacity: safeT,
            child: Transform.translate(
              offset: Offset(0, (1 - safeT) * 20),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.08),
                AppColors.primary.withValues(alpha: 0.02)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.analytics_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Detailed Analytics',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Full breakdowns, charts, and deep insights',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.primary, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // FAB — Glassmorphic practice button
  // ═══════════════════════════════════════════════════════

  Widget _buildFAB() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        final safeT = t.clamp(0.0, 1.0);
        return Transform.scale(scale: safeT, child: child);
      },
      child: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 1)),
        ),
        backgroundColor: AppColors.accent,
        elevation: 8,
        highlightElevation: 12,
        icon: const Icon(Icons.mic_rounded, color: Colors.white),
        label: const Text('Practice',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════

  Widget _glassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }

  String _formatMinutes(int mins) {
    if (mins < 60) return '${mins}m';
    return '${(mins / 60).toStringAsFixed(1)}h';
  }
}

// ═══════════════════════════════════════════════════════
// MODE PERFORMANCE — Dropdown-driven animated gauge
// ═══════════════════════════════════════════════════════

class _ModePerformanceCard extends StatefulWidget {
  final Map<String, double> modeScores;
  const _ModePerformanceCard({required this.modeScores});

  @override
  State<_ModePerformanceCard> createState() => _ModePerformanceCardState();
}

class _ModePerformanceCardState extends State<_ModePerformanceCard> {
  static final List<_ModeDisplay> _modes = [
    _ModeDisplay('Public Speaking', 'public_speaking', Icons.campaign_rounded,
        AppColors.primary),
    _ModeDisplay('Daily Conversation', 'daily_conversation',
        Icons.chat_bubble_rounded, AppColors.accent),
    _ModeDisplay('Script-Based', 'script_based', Icons.description_rounded,
        AppColors.success),
  ];

  String _selectedKey = _modes.first.key;

  _ModeDisplay get _selected => _modes.firstWhere((m) => m.key == _selectedKey);

  String _rankLabel(double score) {
    if (score >= 85) return 'Excellent performance';
    if (score >= 70) return 'Good, keep practicing';
    if (score >= 50) return 'Needs more practice';
    return 'Just getting started';
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.modeScores[_selectedKey] ?? 0;
    final meta = _selected;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResponsiveCardHeader(
            title: const Text('Mode Performance',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: meta.color.withValues(alpha: 0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedKey,
                  isDense: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: meta.color),
                  style: TextStyle(
                      fontSize: 13,
                      color: meta.color,
                      fontWeight: FontWeight.w700),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  items: _modes
                      .map((m) => DropdownMenuItem(
                            value: m.key,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(m.icon, size: 16, color: m.color),
                                const SizedBox(width: 8),
                                Text(m.label),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedKey = v);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0.05, 0), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            ),
            child: LayoutBuilder(
              key: ValueKey(_selectedKey),
              builder: (context, constraints) {
                final gauge = _DashboardGauge(value: score, color: meta.color);
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: meta.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(meta.label,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: meta.color)),
                    ),
                    const SizedBox(height: 10),
                    Text(_rankLabel(score),
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Text(
                      score >= 70
                          ? 'You are performing well in this mode.'
                          : 'Focus on this area to boost your overall score.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                );

                if (constraints.maxWidth < 320) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: gauge),
                      const SizedBox(height: 16),
                      details,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    gauge,
                    const SizedBox(width: 20),
                    Expanded(child: details),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardGauge extends StatelessWidget {
  final double value;
  final Color color;
  const _DashboardGauge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: (value / 100).clamp(0, 1)),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 10,
                  backgroundColor: Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation(Color(0xFFF1F5F9)),
                ),
              ),
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: t,
                  strokeWidth: 10,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${(t * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const Text('Score',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// FOCUS WORDS — Sortable, responsive deck
// ═══════════════════════════════════════════════════════

class _FocusWordsSection extends StatefulWidget {
  final List<Map<String, dynamic>> words;
  final Map<String, Map<String, dynamic>> masteryByWord;
  const _FocusWordsSection({required this.words, this.masteryByWord = const {}});

  @override
  State<_FocusWordsSection> createState() => _FocusWordsSectionState();
}

class _FocusWordsSectionState extends State<_FocusWordsSection> {
  String _sort = 'Frequency';

  List<Map<String, dynamic>> get _sortedWords {
    final list = List<Map<String, dynamic>>.from(widget.words);
    switch (_sort) {
      case 'A-Z':
        list.sort((a, b) => (a['word'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['word'] ?? '').toString().toLowerCase()));
        break;
      case 'Recent':
        // API returns focus words newest-first by default; leave order untouched.
        break;
      case 'Frequency':
      default:
        list.sort((a, b) => ((b['error_count'] as num?)?.toInt() ?? 0)
            .compareTo((a['error_count'] as num?)?.toInt() ?? 0));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final words = _sortedWords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResponsiveCardHeader(
          title: const Text('Focus Words',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          trailing: _FocusSortDropdown(
            onSortChanged: (sortType) => setState(() => _sort = sortType),
          ),
          breakpoint: 260,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth < 200
                ? constraints.maxWidth * 0.85
                : 160.0;
            return SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: words.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, idx) {
                  final word = words[idx];
                  return TweenAnimationBuilder<double>(
                    key: ValueKey('${word['word']}_$_sort'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 400 + idx * 80),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) {
                      final safeT = t.clamp(0.0, 1.0);
                      return Opacity(
                        opacity: safeT,
                        child: Transform.translate(
                          offset: Offset((1 - safeT) * 20, 0),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: cardWidth,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFEF2F2), Color(0xFFFFF5F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFECACA)),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text('#${idx + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                              Icon(Icons.volume_up_rounded,
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.4),
                                  size: 18),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '"${word['word']}"',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${word['error_count']} errors',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Builder(builder: (context) {
                            final mastery = widget.masteryByWord[
                                (word['word'] ?? '').toString().toLowerCase()];
                            if (mastery == null) return const SizedBox.shrink();
                            final streak =
                                (mastery['consecutive_correct'] as num?)
                                        ?.toInt() ??
                                    0;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.trending_up_rounded,
                                      size: 12, color: const Color(0xFF16A34A)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$streak/3 to mastery',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF16A34A),
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FocusSortDropdown extends StatefulWidget {
  final Function(String) onSortChanged;
  const _FocusSortDropdown({required this.onSortChanged});

  @override
  State<_FocusSortDropdown> createState() => _FocusSortDropdownState();
}

class _FocusSortDropdownState extends State<_FocusSortDropdown> {
  String _sort = 'Frequency';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECACA))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sort,
          icon: const Icon(Icons.sort_rounded,
              size: 14, color: Color(0xFFEF4444)),
          style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w600),
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'Frequency', child: Text('By Frequency')),
            DropdownMenuItem(value: 'Recent', child: Text('Most Recent')),
            DropdownMenuItem(value: 'A-Z', child: Text('A-Z')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _sort = v);
              widget.onSortChanged(v);
            }
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// RECENT SESSIONS — Compact filterable card list
// ═══════════════════════════════════════════════════════

class _RecentSessionsSection extends StatefulWidget {
  final List<Map<String, dynamic>> sessions;
  const _RecentSessionsSection({required this.sessions});

  @override
  State<_RecentSessionsSection> createState() => _RecentSessionsSectionState();
}

class _RecentSessionsSectionState extends State<_RecentSessionsSection> {
  String _filter = 'All';

  List<Map<String, dynamic>> get _filteredSessions {
    if (_filter == 'All') return widget.sessions;
    return widget.sessions.where((s) => s['mode'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _filteredSessions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResponsiveCardHeader(
          title: const Text('Recent Sessions',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          trailing: _SessionFilterDropdown(
            onFilterChanged: (filter) => setState(() => _filter = filter),
          ),
          breakpoint: 260,
        ),
        const SizedBox(height: 16),
        if (sessions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider)),
            child: Center(
              child: Text(
                widget.sessions.isEmpty
                    ? 'No sessions yet. Start your first practice!'
                    : 'No sessions for this filter yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          )
        else
          ...sessions.asMap().entries.map((entry) {
            final idx = entry.key;
            final session = entry.value;
            final color = _modeColorFor(session['mode']);

            return TweenAnimationBuilder<double>(
              key: ValueKey(session['id'] ?? idx),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 350 + idx * 80),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                final safeT = t.clamp(0.0, 1.0);
                return Opacity(
                  opacity: safeT,
                  child: Transform.translate(
                    offset: Offset((1 - safeT) * 16, 0),
                    child: child,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                // FIX: wrapped in IntrinsicHeight so the stretched Row below
                // (colored side-bar + content) gets a bounded height instead
                // of an infinite one from its unconstrained sliver ancestor.
                // This was the root cause of the
                // "BoxConstraints forces an infinite height" crash.
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 5, color: color),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    shape: BoxShape.circle),
                                child: Icon(_modeIconFor(session['mode']),
                                    color: color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      session['title'] ?? 'Practice Session',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      session['date_label'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _scoreColorFor(session['score'])
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${(session['score'] as num?)?.toStringAsFixed(0) ?? 0}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: _scoreColorFor(session['score'])),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _SessionFilterDropdown extends StatefulWidget {
  final Function(String) onFilterChanged;
  const _SessionFilterDropdown({required this.onFilterChanged});

  @override
  State<_SessionFilterDropdown> createState() => _SessionFilterDropdownState();
}

class _SessionFilterDropdownState extends State<_SessionFilterDropdown> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filter,
          icon: const Icon(Icons.filter_alt_rounded,
              size: 14, color: Color(0xFF64748B)),
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600),
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'All', child: Text('All')),
            DropdownMenuItem(value: 'public_speaking', child: Text('Public')),
            DropdownMenuItem(
                value: 'daily_conversation', child: Text('Conversation')),
            DropdownMenuItem(value: 'script_based', child: Text('Script')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _filter = v);
              widget.onFilterChanged(v);
            }
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════
// PROGRESSION PANEL — "X / 5 criteria met" transparency card
// ═══════════════════════════════════════════════════════

class _ProgressionPanel extends StatelessWidget {
  final Map<String, dynamic> progression;
  const _ProgressionPanel({required this.progression});

  static const _gateLabels = {
    'sessions': 'Sessions at level',
    'score': 'Average score',
    'error_rate': 'Error rate',
    'mastery': 'Word mastery',
    'phoneme': 'Accent accuracy',
  };

  static const _levelLabels = {
    'beginner': 'Beginner',
    'intermediate': 'Intermediate',
    'expert': 'Expert',
  };

  @override
  Widget build(BuildContext context) {
    final level = progression['current_level']?.toString() ?? 'beginner';
    final eligible = progression['eligible_for_promotion'] == true;
    final gates = (progression['gates'] as Map<String, dynamic>?) ?? {};

    final passedCount =
        gates.values.where((g) => g is Map && g['passed'] == true).length;
    final totalGates = gates.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: eligible ? const Color(0xFF16A34A) : AppColors.divider,
          width: eligible ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _levelLabels[level] ?? level,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ),
              const Spacer(),
              if (eligible)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up_rounded,
                          size: 13, color: Color(0xFF16A34A)),
                      SizedBox(width: 4),
                      Text('Ready to level up!',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              else
                Text(
                  '$passedCount / $totalGates criteria met',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...gates.entries.map((entry) {
            final key = entry.key;
            final g = entry.value as Map<String, dynamic>;
            final passed = g['passed'] == true;
            final current = g['current'];
            final required = g['required'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    passed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color:
                        passed ? const Color(0xFF16A34A) : AppColors.textHint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _gateLabels[key] ?? key,
                      style: TextStyle(
                        fontSize: 13,
                        color: passed
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: passed ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '$current / $required',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          passed ? const Color(0xFF16A34A) : AppColors.textHint,
                      fontWeight: FontWeight.w600,
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
}

// ═══════════════════════════════════════════════════════
// FOCUS SCRIPT CARD — Suggested remediation practice
// ═══════════════════════════════════════════════════════

class _FocusScriptCard extends StatelessWidget {
  final Map<String, dynamic> focusScript;
  final VoidCallback onStart;
  const _FocusScriptCard({required this.focusScript, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final words = List<String>.from(focusScript['source_words'] ?? []);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Focus Script Ready',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FocusScriptHistoryScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('History', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'We noticed ${words.length} recurring errors — practice a script built around them.',
            style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.4),
          ),
          if (words.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: words
                  .take(6)
                  .map((w) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('"$w"',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.mic_rounded, size: 18),
              label: const Text('Start Focus Practice',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
