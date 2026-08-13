import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import 'progress_analytics_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
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

  // Animation controllers
  late AnimationController _headerAnim;
  late AnimationController _streakPulse;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _streakPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
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

    _headerAnim.forward();
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
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildQuickStatsCarousel(),
                const SizedBox(height: 24),
                _buildDailyGoalRing(),
                const SizedBox(height: 24),
                if (_sparkline.length >= 2) ...[
                  _buildWeeklyHeatmap(),
                  const SizedBox(height: 24),
                ],
                if ((_improvement['percentage_change'] as num?)?.toDouble() != 0) ...[
                  _buildImprovementBadge(),
                  const SizedBox(height: 24),
                ],
                _buildModeScoreReveal(),
                const SizedBox(height: 24),
                if (_focusWords.isNotEmpty) ...[
                  _buildFocusWordsDeck(),
                  const SizedBox(height: 24),
                ],
                _buildRecentSessionsTimeline(),
                const SizedBox(height: 24),
                _buildSkillLevelCard(),
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
          BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: FadeTransition(
        opacity: _headerAnim.drive(Tween(begin: 0.0, end: 1.0)),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero).animate(
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
                          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _userName,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                        ),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _streakPulse,
                    builder: (context, child) {
                      final val = _streakPulse.value.clamp(0.0, 1.0);
                      final opacity = Tween(begin: 0.7, end: 1.0).transform(val).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: opacity,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        boxShadow: [BoxShadow(color: Colors.orangeAccent.withValues(alpha: 0.3), blurRadius: 12)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            '$_streakDays',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _headerChip(Icons.emoji_events_rounded, 'Best ${_bestScore.toStringAsFixed(0)}%', Colors.amber),
                  const SizedBox(width: 10),
                  _headerChip(Icons.star_rounded, 'Lvl ${_levelFromSessions(_totalSessions)}', const Color(0xFFA78BFA)),
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
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
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
      _StatItem('$_totalSessions', 'Sessions', Icons.play_circle_filled_rounded, AppColors.primary),
      _StatItem('${_quickStats['words'] ?? 0}', 'Words', Icons.text_fields_rounded, const Color(0xFF16A34A)),
      _StatItem('${_quickStats['errors_corrected'] ?? 0}', 'Fixed', Icons.check_circle_rounded, const Color(0xFF7C3AED)),
      _StatItem(_formatMinutes(_quickStats['minutes'] ?? 0), 'Time', Icons.timer_rounded, const Color(0xFF2563EB)),
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
                  colors: [s.color.withValues(alpha: 0.08), s.color.withValues(alpha: 0.02)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: s.color.withValues(alpha: 0.15)),
                boxShadow: [BoxShadow(color: s.color.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(s.icon, color: s.color, size: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.value,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: s.color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.label,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
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
  // DAILY GOAL — Animated ring
  // ═══════════════════════════════════════════════════════

  Widget _buildDailyGoalRing() {
    final goalProgress = (_totalSessions % 5) / 5;
    final sessionsToGoal = 5 - (_totalSessions % 5);

    return _glassCard(
      child: Row(
        children: [
          Flexible(
            child: AspectRatio(
              aspectRatio: 1,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: goalProgress),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  final safeT = t.clamp(0.0, 1.0);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 10,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFF1F5F9)),
                      ),
                      CircularProgressIndicator(
                        value: safeT,
                        strokeWidth: 10,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(AppColors.accent),
                        strokeCap: StrokeCap.round,
                      ),
                      FittedBox(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(safeT * 100).toInt()}%',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                            const Text(
                              'Daily',
                              style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Daily Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(
                  sessionsToGoal == 0 ? 'Goal crushed! 🔥' : '$sessionsToGoal more sessions to hit your daily target',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: goalProgress,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // WEEKLY HEATMAP — Unique visual using sparkline data
  // ═══════════════════════════════════════════════════════

  Widget _buildWeeklyHeatmap() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final values = _sparkline.length >= 7 ? _sparkline.sublist(_sparkline.length - 7) : _sparkline;
    final displayValues = values.isEmpty ? List.filled(7, 0.0) : values;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Weekly Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                child: Text('${_sparkline.length} sessions', style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (idx) {
              final val = idx < displayValues.length ? displayValues[idx] : 0.0;
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
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color.lerp(const Color(0xFFF1F5F9), AppColors.accent, intensity * safeT),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: intensity > 0.6
                                ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), blurRadius: 8)]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${val.toInt()}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: intensity > 0.4 ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(days[idx], style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                },
              );
            }),
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
              color: (isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${isPositive ? '+' : ''}${pct.toStringAsFixed(0)}% vs Last Week', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    isPositive ? 'Your trajectory is climbing. Keep the rhythm!' : 'Consistency beats intensity. Show up today!',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
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
  // MODE SCORES — Dropdown reveal with animated skill ring
  // ═══════════════════════════════════════════════════════

  Widget _buildModeScoreReveal() {
    final modes = [
      _ModeDisplay('Public Speaking', 'public_speaking', Icons.campaign_rounded, AppColors.primary),
      _ModeDisplay('Daily Conversation', 'daily_conversation', Icons.chat_bubble_rounded, AppColors.accent),
      _ModeDisplay('Script-Based', 'script_based', Icons.description_rounded, AppColors.success),
    ];

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mode Performance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              _ModeDropdown(
                modes: modes,
                onSelected: (key) {},
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...modes.map((m) {
            final score = _modeScores[m.key] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: m.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(m.icon, color: m.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: score / 100),
                                duration: const Duration(milliseconds: 1200),
                                curve: Curves.easeOutCubic,
                                builder: (context, t, _) {
                                  final safeT = t.clamp(0.0, 1.0);
                                  return LinearProgressIndicator(
                                    value: safeT,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    valueColor: AlwaysStoppedAnimation<Color>(m.color),
                                    minHeight: 8,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${score.toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: m.color)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // FOCUS WORDS — Horizontal snap-scroll deck
  // ═══════════════════════════════════════════════════════

  Widget _buildFocusWordsDeck() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Focus Words', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            _FocusSortDropdown(
              onSortChanged: (sortType) {
                // In a real app, re-sort _focusWords here
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _focusWords.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final word = _focusWords[idx];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 500 + idx * 100),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) {
                  final safeT = t.clamp(0.0, 1.0);
                  return Opacity(
                    opacity: safeT,
                    child: Transform.translate(
                      offset: Offset((1 - safeT) * 30, 0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFEF2F2), Color(0xFFFFF5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFECACA)),
                    boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(8)),
                            child: Text('#${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                          Icon(Icons.volume_up_rounded, color: const Color(0xFFEF4444).withValues(alpha: 0.4), size: 18),
                        ],
                      ),
                      Text(
                        '"${word['word']}"',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        '${word['error_count']} errors',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // RECENT SESSIONS — Timeline style with filter
  // ═══════════════════════════════════════════════════════

  Widget _buildRecentSessionsTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Sessions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            _SessionFilterDropdown(
              onFilterChanged: (filter) {
                // Filter logic here
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_recentSessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.divider)),
            child: const Center(child: Text('No sessions yet. Start your first practice!', style: TextStyle(color: AppColors.textSecondary, fontSize: 14))),
          )
        else
          ..._recentSessions.asMap().entries.map((entry) {
            final idx = entry.key;
            final session = entry.value;
            final isLast = idx == _recentSessions.length - 1;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + idx * 100),
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
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _modeColor(session['mode']),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: _modeColor(session['mode']).withValues(alpha: 0.3), blurRadius: 6)],
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(width: 2, color: const Color(0xFFE2E8F0)),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    session['title'] ?? 'Practice Session',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    session['date_label'] ?? '',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _scoreColor(session['score']).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(session['score'] as num?)?.toStringAsFixed(0) ?? 0}%',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _scoreColor(session['score'])),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Color _scoreColor(dynamic score) {
    final s = (score as num?)?.toDouble() ?? 0;
    if (s >= 80) return const Color(0xFF16A34A);
    if (s >= 60) return const Color(0xFF2563EB);
    if (s >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  // ═══════════════════════════════════════════════════════
  // SKILL LEVEL — Gamified progress card
  // ═══════════════════════════════════════════════════════

  Widget _buildSkillLevelCard() {
    final level = _levelFromSessions(_totalSessions);
    final progressToNext = (_totalSessions % 5) / 5;
    final totalWords = _quickStats['words'] ?? 0;

    return _glassCard(
      child: Row(
        children: [
          Flexible(
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 8,
                    backgroundColor: Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation(Color(0xFFF1F5F9)),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: progressToNext),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) {
                      final safeT = t.clamp(0.0, 1.0);
                      return CircularProgressIndicator(
                        value: safeT,
                        strokeWidth: 8,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                        strokeCap: StrokeCap.round,
                      );
                    },
                  ),
                  FittedBox(
                    child: Text(
                      '$level',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF8B5CF6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Skill Level', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(
                  '$totalWords words spoken across $_totalSessions sessions',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progressToNext,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${(progressToNext * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ANALYTICS LINK — Restored navigation card
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
              colors: [AppColors.primary.withValues(alpha: 0.08), AppColors.primary.withValues(alpha: 0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Detailed Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Full breakdowns, charts, and deep insights', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 14),
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
        label: const Text('Practice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }

  String _formatMinutes(int mins) {
    if (mins < 60) return '${mins}m';
    return '${(mins / 60).toStringAsFixed(1)}h';
  }

  Color _modeColor(String? mode) {
    switch (mode) {
      case 'public_speaking': return AppColors.primary;
      case 'daily_conversation': return AppColors.accent;
      case 'script_based': return AppColors.success;
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
}

// ═══════════════════════════════════════════════════════
// DROPDOWN WIDGETS
// ═══════════════════════════════════════════════════════

class _ModeDropdown extends StatelessWidget {
  final List<_ModeDisplay> modes;
  final Function(String) onSelected;
  const _ModeDropdown({required this.modes, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: const Text('Filter', style: TextStyle(fontSize: 11)),
          icon: const Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFF64748B)),
          style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          isDense: true,
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All Modes')),
            ...modes.map((m) => DropdownMenuItem(value: m.key, child: Text(m.label))),
          ],
          onChanged: (v) {
            if (v != null) onSelected(v);
          },
        ),
      ),
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
      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFECACA))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sort,
          icon: const Icon(Icons.sort_rounded, size: 14, color: Color(0xFFEF4444)),
          style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
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
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filter,
          icon: const Icon(Icons.filter_alt_rounded, size: 14, color: Color(0xFF64748B)),
          style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'All', child: Text('All')),
            DropdownMenuItem(value: 'public_speaking', child: Text('Public')),
            DropdownMenuItem(value: 'daily_conversation', child: Text('Conversation')),
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