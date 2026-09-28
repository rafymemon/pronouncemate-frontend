// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../services/user_session.dart';
import '../services/user_progress_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'active_session_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'progress_analytics_screen.dart';
import 'script_selection_screen.dart' show ProficiencyLevel, ScriptMode;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late UserProgressSummary _summary;
  bool _isLoadingSummary = true;

  // ── Smart Rotation: Today's Picks state ────────────────
  List<Map<String, dynamic>> _todaysPicks = [];
  bool _loadingPicks = true;
  String? _picksError;

  // ── Notifications badge ────────────────────────────────
  int _unreadNotifications = 0;

  static const List<String> _hookLines = [
    "Every sentence you practice today is a step closer to sounding confident.",
    "Small daily reps build big pronunciation wins — let's go.",
    "Your voice, sharper every session. Pick a script and start.",
  ];

  String get _hookLine =>
      _hookLines[DateTime.now().day % _hookLines.length];

  @override
  void initState() {
    super.initState();
    _summary = UserProgressService.cachedSummary ?? _emptySummary();
    _isLoadingSummary = UserProgressService.cachedSummary == null;
    UserProgressService.instance.addListener(_onProgressChanged);
    _loadSummary();
    _loadTodaysPicks();
    _loadNotificationsBadge();
  }

  @override
  void dispose() {
    UserProgressService.instance.removeListener(_onProgressChanged);
    super.dispose();
  }

  UserProgressSummary _emptySummary() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return UserProgressSummary(
      displayName: UserSession.instance.name,
      totalSessions: 0,
      bestScore: 0,
      averageAccuracy: 0,
      streakDays: 0,
      wordsPracticed: 0,
      todaySessions: 0,
      goalTarget: 2,
      recentSessions: const [],
      weeklyAccuracy: List.generate(
        7,
        (i) => DayAccuracy(
          date: today.subtract(Duration(days: 6 - i)),
          averageAccuracy: 0,
          sessionCount: 0,
        ),
      ),
    );
  }

  Future<void> _loadSummary() async {
    if (mounted) {
      setState(() {
        _isLoadingSummary = true;
      });
    }

    final summary = await UserProgressService.load();
    if (!mounted) return;

    setState(() {
      _summary = summary;
      _isLoadingSummary = false;
    });

    UserProgressService.cache(summary);
  }

  Future<void> _loadTodaysPicks() async {
    if (mounted) {
      setState(() {
        _loadingPicks = true;
        _picksError = null;
      });
    }

    final result = await ApiService.getRotatedScripts(count: 3);
    if (!mounted) return;

    if (result['error'] != null) {
      setState(() {
        _loadingPicks = false;
        _picksError = result['error'].toString();
      });
      return;
    }

    setState(() {
      _loadingPicks = false;
      _picksError = null;
      _todaysPicks = List<Map<String, dynamic>>.from(result['scripts'] ?? []);
    });
  }

  Future<void> _loadNotificationsBadge() async {
    final result = await ApiService.getNotifications();
    if (!mounted) return;
    setState(() {
      _unreadNotifications = (result['unread_count'] as num?)?.toInt() ?? 0;
    });
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    // The notifications screen marks everything read as soon as it loads
    // its list, so once we're back the badge should clear.
    if (mounted) setState(() => _unreadNotifications = 0);
  }

  void _openScript(Map<String, dynamic> script) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveSessionScreen(
          scriptText: script['content']?.toString() ?? '',
          scriptId: script['id']?.toString(),
          sessionTitle: script['title']?.toString() ?? 'Practice',
        ),
      ),
    ).then((_) {
      _loadTodaysPicks();
    });
  }

  void _openDetailedAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProgressAnalyticsScreen()),
    );
  }

  Future<void> reload() async {
    await _loadSummary();
  }

  Future<void> _refresh() async {
    await reload();
    await _loadTodaysPicks();
    await _loadNotificationsBadge();
  }

  void _onProgressChanged() {
    if (!mounted) return;
    reload();
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sign Out',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: const Text(
            'Are you sure you want to sign out of PronounceMate?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await UserSession.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return AnimatedBuilder(
      animation: UserSession.instance,
      builder: (context, _) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          drawer: _AppDrawer(
            onLogout: _confirmLogout,
            onOpenAnalytics: _openDetailedAnalytics,
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Greeting Header ──────────────────────────────
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _scaffoldKey.currentState?.openDrawer(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: const [
                                BoxShadow(
                                    color: AppColors.cardShadow,
                                    blurRadius: 8,
                                    offset: Offset(0, 2)),
                              ],
                            ),
                            child: const Icon(Icons.menu_rounded,
                                color: AppColors.textPrimary, size: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                () {
                                  final h = DateTime.now().hour;
                                  return h < 12
                                      ? 'Good morning,'
                                      : h < 17
                                          ? 'Good afternoon,'
                                          : 'Good evening,';
                                }(),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                              ),
                              Text('${summary.displayName} 👋',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  )),
                            ],
                          ),
                        ),
                        // FIX: bell icon now navigates to a real
                        // notification feed and shows an unread badge,
                        // instead of being a static decoration.
                        GestureDetector(
                          onTap: _openNotifications,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: const [
                                BoxShadow(
                                    color: AppColors.cardShadow,
                                    blurRadius: 8,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Center(
                                  child: Icon(Icons.notifications_outlined,
                                      color: AppColors.textPrimary, size: 22),
                                ),
                                if (_unreadNotifications > 0)
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColors.surface, width: 1.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (_isLoadingSummary)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),

                    // ── Today's Goal Banner ──────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Today's Goal",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    )),
                                const SizedBox(height: 4),
                                Text(
                                  'Complete ${summary.goalTarget} Practice Sessions',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: summary.goalProgress.clamp(0.0, 1.0),
                                    backgroundColor: Colors.white24,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                    minHeight: 7,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${summary.todaySessions} of ${summary.goalTarget} completed',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.flag_rounded,
                              color: Colors.white54, size: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // FIX: pronunciation banner removed. A short hook line
                    // sits directly above Today's Picks instead.
                    Text(
                      _hookLine,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Today's Picks (Smart Rotation) ────────────────
                    _TodaysPicksSection(
                      picks: _todaysPicks,
                      loading: _loadingPicks,
                      error: _picksError,
                      onRetry: _loadTodaysPicks,
                      onTapScript: _openScript,
                    ),
                    const SizedBox(height: 28),

                    // ── Weekly Activity Heatmap ───────────────────────
                    _WeeklyActivityCard(data: summary.weeklyAccuracy),
                    const SizedBox(height: 28),

                    // ── Quick Stats ──────────────────────────────────
                    Row(
                      children: [
                        const Expanded(
                          child: SectionHeader(
                            title: 'Your Progress',
                            subtitle: 'Last 7 days',
                          ),
                        ),
                        TextButton(
                          onPressed: _openDetailedAnalytics,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('View Details',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded,
                                  color: AppColors.primary, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.1,
                      children: [
                        StatCard(
                          label: 'Sessions (7d)',
                          value: summary.totalSessions.toString(),
                          icon: Icons.mic_rounded,
                          color: AppColors.primary,
                        ),
                        StatCard(
                          label: 'Avg. Accuracy (7d)',
                          value:
                              '${summary.averageAccuracy.toStringAsFixed(0)}%',
                          icon: Icons.track_changes_rounded,
                          color: AppColors.success,
                        ),
                        StatCard(
                          label: 'Words Practiced',
                          value: summary.wordsPracticed == null
                              ? '—'
                              : summary.wordsPracticed.toString(),
                          icon: Icons.spellcheck_rounded,
                          color: AppColors.warning,
                        ),
                        StatCard(
                          label: 'Streak',
                          value: '${summary.streakDays} days',
                          icon: Icons.local_fire_department_rounded,
                          color: AppColors.error,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Recent Sessions (now expandable, 5 → all) ─────
                    _RecentSessionsCard(recentSessions: summary.recentSessions),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Recent Sessions — shows 5, "View All" fetches the full history ──
class _RecentSessionsCard extends StatefulWidget {
  final List<SessionSnapshot> recentSessions;
  const _RecentSessionsCard({required this.recentSessions});

  @override
  State<_RecentSessionsCard> createState() => _RecentSessionsCardState();
}

class _RecentSessionsCardState extends State<_RecentSessionsCard> {
  bool _expanded = false;
  bool _loadingAll = false;
  List<Map<String, dynamic>>? _allSessions;

  Future<void> _toggleExpand() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }

    setState(() {
      _expanded = true;
      _loadingAll = true;
    });

    final raw = await ApiService.getSessions();
    if (!mounted) return;
    setState(() {
      _loadingAll = false;
      _allSessions = raw.whereType<Map>().map((e) =>
          e.map((k, v) => MapEntry(k.toString(), v))).toList();
    });
  }

  String _dateLabel(DateTime? dt) {
    if (dt == null) return 'Recently';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    }
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Recent Sessions',
                  subtitle: 'From the last 7 days',
                ),
              ),
              TextButton(
                onPressed: _toggleExpand,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_expanded ? 'Show Less' : 'View All',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_expanded) ..._buildRecentFive(),
          if (_expanded) ..._buildExpanded(),
        ],
      ),
    );
  }

  List<Widget> _buildRecentFive() {
    final list = widget.recentSessions.take(5).toList();
    if (list.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No sessions in the last 7 days. Start a practice run to see your history here.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ];
    }
    return list
        .map((session) => _RecentSession(
              title: session.title,
              date: session.dateLabel,
              score: session.score.round(),
              duration: session.durationLabel ?? '—',
              grade: session.grade,
            ))
        .toList();
  }

  List<Widget> _buildExpanded() {
    if (_loadingAll) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ];
    }
    final all = _allSessions ?? [];
    if (all.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('No session history yet.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ];
    }
    return all.map((s) {
      final score = (s['accuracy'] as num?)?.toDouble() ?? 0.0;
      final grade = s['grade']?.toString() ?? '—';
      final dt = DateTime.tryParse(s['created_at']?.toString() ?? '');
      return _RecentSession(
        title: 'Session',
        date: _dateLabel(dt),
        score: score.round(),
        duration: '—',
        grade: grade,
      );
    }).toList();
  }
}

// ── Weekly Activity Heatmap ─────────────────────────────────────────
class _WeeklyActivityCard extends StatelessWidget {
  final List<DayAccuracy> data;
  const _WeeklyActivityCard({required this.data});

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekdayLetter(int weekday) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return letters[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final sessionsThisWeek =
        data.fold<int>(0, (sum, d) => sum + d.sessionCount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Weekly Activity',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$sessionsThisWeek sessions',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellSize =
                  ((constraints.maxWidth - 6 * 8) / 7).clamp(24.0, 36.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(data.length, (idx) {
                  final day = data[idx];
                  final intensity = (day.averageAccuracy / 100).clamp(0.05, 1.0);
                  final isToday = _isSameDay(day.date, DateTime.now());

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
                                border: isToday
                                    ? Border.all(
                                        color: AppColors.primary, width: 1.5)
                                    : null,
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
                                  day.sessionCount == 0
                                      ? '—'
                                      : '${day.averageAccuracy.toInt()}',
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
                            Text(_weekdayLetter(day.date.weekday),
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
}

// ── Today's Picks (Smart Rotation) ──────────────────────────────────
class _TodaysPicksSection extends StatelessWidget {
  final List<Map<String, dynamic>> picks;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<Map<String, dynamic>> onTapScript;

  const _TodaysPicksSection({
    required this.picks,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onTapScript,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: "Today's Picks",
          subtitle: 'Fresh scripts chosen just for you',
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 168,
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.4,
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.textMuted, size: 26),
            const SizedBox(height: 8),
            const Text(
              "Couldn't load today's picks",
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry',
                  style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (picks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "You've cleared every script in the library — amazing work! "
            "Upload your own to keep practicing.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: picks.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (ctx, i) => _PickCard(
        script: picks[i],
        onTap: () => onTapScript(picks[i]),
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  final Map<String, dynamic> script;
  final VoidCallback onTap;

  const _PickCard({required this.script, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final level = ProficiencyLevel.fromValue(
        script['level']?.toString() ?? 'beginner');
    final mode = ScriptMode.fromValue(
        script['mode']?.toString() ?? 'daily_conversation');
    final wordCount = script['word_count'] as int? ?? 0;
    final preview = script['preview']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(mode.icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    mode.label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              script['title']?.toString() ?? 'Untitled',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.35),
              ),
            ),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: level.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(level.label,
                      style: TextStyle(
                          fontSize: 10,
                          color: level.color,
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Text('$wordCount w',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── App Drawer ───────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onOpenAnalytics;
  const _AppDrawer({required this.onLogout, required this.onOpenAnalytics});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.accentLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        UserSession.instance.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(UserSession.instance.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      )),
                  const SizedBox(height: 2),
                  const Text('Username account',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _DrawerItem(
              icon: Icons.bar_chart_rounded,
              label: 'Dashboard',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DashboardScreen()));
              },
            ),
            _DrawerItem(
              icon: Icons.insights_rounded,
              label: 'Detailed Analytics',
              onTap: () {
                Navigator.of(context).pop();
                onOpenAnalytics();
              },
            ),
            _DrawerItem(
              icon: Icons.person_outline_rounded,
              label: 'Edit Profile',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
            ),
            _DrawerItem(
              icon: Icons.info_outline_rounded,
              label: 'About',
              onTap: () {
                Navigator.of(context).pop();
                showAboutDialog(
                  context: context,
                  applicationName: 'PronounceMate',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2026 PronounceMate',
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  onLogout();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.logout_rounded,
                          color: AppColors.error, size: 20),
                      SizedBox(width: 14),
                      Text('Sign Out',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent, size: 22),
      title: Text(label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          )),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }
}

// ── Recent Session Row ───────────────────────────────────────────
class _RecentSession extends StatelessWidget {
  final String title;
  final String date;
  final int score;
  final String duration;
  final String grade;

  const _RecentSession({
    required this.title,
    required this.date,
    required this.score,
    required this.duration,
    required this.grade,
  });

  Color get _scoreColor {
    if (score >= 85) return AppColors.success;
    if (score >= 65) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _scoreColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('$score%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _scoreColor,
                  )),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    )),
                Text(date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    )),
                const SizedBox(height: 2),
                Text('Grade $grade',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          Text(duration,
              style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
        ],
      ),
    );
  }
}