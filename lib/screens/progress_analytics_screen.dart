// lib/screens/progress_analytics_screen.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class _ResponsiveCardHeader extends StatelessWidget {
  final Widget title;
  final Widget trailing;
  final double breakpoint;
  const _ResponsiveCardHeader({required this.title, required this.trailing, this.breakpoint = 300});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              title,
              const SizedBox(height: 10),
              trailing,
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

class ProgressAnalyticsScreen extends StatefulWidget {
  const ProgressAnalyticsScreen({super.key});

  @override
  State<ProgressAnalyticsScreen> createState() => _ProgressAnalyticsScreenState();
}

class _ProgressAnalyticsScreenState extends State<ProgressAnalyticsScreen> {
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  final GlobalKey _shareBoundaryKey = GlobalKey();

  List<SessionData> _sessions = [];
  List<WordError> _topErrors = [];
  ErrorBreakdown _errorBreakdown = ErrorBreakdown.empty();
  ImprovementStats _improvement = ImprovementStats(firstAvg: 0, lastAvg: 0, percentageChange: 0);
  TotalStats _totalStats = TotalStats(sessions: 0, words: 0, errors: 0, minutes: 0);

  // FIX: replaces the Mode Score card (now shown only on Dashboard, to
  // avoid duplicating the same gauge on two screens).
  Map<String, dynamic>? _progression;

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
      ApiService.getProgressAnalytics(),
      ApiService.getProgressionStatus(),
    ]);

    if (!mounted) return;

    final data = results[0];
    final progressionData = results[1];

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
      _improvement = ImprovementStats.fromJson(data['improvement'] as Map<String, dynamic>? ?? {});
      _totalStats = TotalStats.fromJson(data['total_stats'] as Map<String, dynamic>? ?? {});
      _progression = progressionData['error'] == null ? progressionData : null;
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
            onPressed: (_loading || _error != null) ? null : _shareProgress,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 360 ? 12.0 : 16.0;
        return RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: RepaintBoundary(
                  key: _shareBoundaryKey,
                  child: Container(
                    color: AppColors.background,
                    padding: EdgeInsets.all(horizontalPadding),
                    // FIX: reordered — Stats now come right after the
                    // Performance Spectrum (item 5). Mode Score card
                    // removed (duplicate of Dashboard); replaced with a
                    // Level Progress card (item 3's "alternative").
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PerformanceSpectrumCard(sessions: _sessions),
                        const SizedBox(height: 16),
                        _StatsGridCard(stats: _totalStats),
                        const SizedBox(height: 16),
                        if (_sessions.length >= 2) _AccuracyTrendCard(sessions: _sessions),
                        if (_sessions.length >= 2) const SizedBox(height: 16),
                        if (_progression != null) ...[
                          _LevelProgressCard(progression: _progression!),
                          const SizedBox(height: 16),
                        ],
                        _ErrorBreakdownCard(breakdown: _errorBreakdown),
                        const SizedBox(height: 16),
                        _TopErrorsCard(errors: _topErrors),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Share ─────────────────────────────────────────────

  void _shareProgress() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
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
                subtitle: const Text('A snapshot of this screen'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareAsImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet, color: AppColors.primary),
                title: const Text('Share as Text'),
                subtitle: const Text('A quick summary you can paste anywhere'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareAsText();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareAsText() async {
    final buffer = StringBuffer()
      ..writeln('🎤 My PronounceMate Progress')
      ..writeln();

    if (_improvement.percentageChange != 0 && _sessions.length >= 2) {
      final sign = _improvement.percentageChange >= 0 ? '+' : '';
      buffer.writeln('📈 Accuracy change: $sign${_improvement.percentageChange.toStringAsFixed(0)}%');
    }
    if (_sessions.isNotEmpty) {
      final best = _sessions.map((s) => s.accuracy).reduce((a, b) => a > b ? a : b);
      final latest = _sessions.last.accuracy;
      buffer.writeln('🏆 Personal best: ${best.toStringAsFixed(1)}%');
      buffer.writeln('⚡ Latest session: ${latest.toStringAsFixed(1)}%');
      buffer.writeln();
    }

    buffer
      ..writeln('📊 Total sessions: ${_totalStats.sessions}')
      ..writeln('🗣️ Words practiced: ${_totalStats.words}')
      ..writeln('✅ Errors corrected: ${_totalStats.errors}')
      ..writeln('⏱️ Practice time: ${(_totalStats.minutes / 60).toStringAsFixed(1)}h');

    if (_topErrors.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Word I\'m working on: "${_topErrors.first.word}"');
    }

    buffer
      ..writeln()
      ..writeln('Practicing pronunciation with PronounceMate 🚀');

    try {
      await Share.share(buffer.toString());
    } catch (e) {
      _showExportError('Could not open the share sheet.');
    }
  }

  Future<void> _shareAsImage() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    _showGeneratingSnackBar();

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _shareBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _showExportError('Nothing to export yet — try again in a moment.');
        return;
      }

      final heightFactor = boundary.size.height > 0 ? 2400 / boundary.size.height : 1.0;
      final pixelRatio = heightFactor.clamp(1.0, 2.5);

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes == null) {
        _showExportError('Could not generate the image.');
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pronouncemate_progress_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My pronunciation progress on PronounceMate 🎤',
      );
    } catch (e) {
      _showExportError('Something went wrong exporting the image.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showGeneratingSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Generating image…'),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showExportError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade600),
    );
  }
}

// ── Shared Card Shell ───────────────────────────────────

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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

// ── Animated Counter ────────────────────────────────────

class _AnimatedCounter extends StatelessWidget {
  final num value;
  final bool isDouble;
  final String suffix;
  final TextStyle? style;
  const _AnimatedCounter({required this.value, this.isDouble = false, this.suffix = '', this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        final display = isDouble ? val.toStringAsFixed(1) : val.toInt().toString();
        return Text('$display$suffix', style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// 1. PERFORMANCE SPECTRUM — theme colors, trend badge/text removed
// ═══════════════════════════════════════════════════════

class _PerformanceSpectrumCard extends StatelessWidget {
  final List<SessionData> sessions;
  const _PerformanceSpectrumCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final best = sessions.isEmpty ? 0.0 : sessions.map((s) => s.accuracy).reduce((a, b) => a > b ? a : b);
    final avg = sessions.isEmpty ? 0.0 : sessions.map((s) => s.accuracy).reduce((a, b) => a + b) / sessions.length;
    final latest = sessions.isEmpty ? 0.0 : sessions.last.accuracy;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // FIX: theme gradient instead of an unrelated blue/orange one,
        // and no longer flips color based on trend since the trend
        // badge/text is removed.
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Performance Spectrum',
              style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
          const SizedBox(height: 24),
          _spectrumBar('Personal Best', best, best, Icons.emoji_events_rounded, const Color(0xFFFCD34D)),
          const SizedBox(height: 18),
          _spectrumBar('Your Average', avg, best, Icons.analytics_rounded, Colors.white),
          const SizedBox(height: 18),
          _spectrumBar('Latest Session', latest, best, Icons.flash_on_rounded, const Color(0xFFA5F3FC)),
        ],
      ),
    );
  }

  Widget _spectrumBar(String label, double value, double max, IconData icon, Color accent) {
    final pct = max > 0 ? (value / max).clamp(0.05, 1.0) : 0.05;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: accent.withValues(alpha: 0.9), fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            Text('${value.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              return Stack(
                children: [
                  Container(height: 10, color: Colors.white.withValues(alpha: 0.12)),
                  FractionallySizedBox(
                    widthFactor: t,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [accent.withValues(alpha: 0.7), accent]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// 2. ACCURACY TREND — "tap to expand" hint is now actually tappable
// ═══════════════════════════════════════════════════════

class _AccuracyTrendCard extends StatelessWidget {
  final List<SessionData> sessions;
  const _AccuracyTrendCard({required this.sessions});

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: _FullScreenAccuracyChart(sessions: sessions),
          ),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResponsiveCardHeader(
            title: const Text('Accuracy Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            trailing: GestureDetector(
              onTap: () => _openFullScreen(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(20)),
                child: Text('↗ Improving', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _openFullScreen(context),
            child: Hero(
              tag: 'accuracyChartMini',
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  height: 200,
                  child: _AnimatedAccuracyLineChart(sessions: sessions, isFullScreen: false),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // FIX: this hint row previously had no tap handler at all —
          // only the chart above it responded to taps. Now it opens the
          // same full-screen view.
          GestureDetector(
            onTap: () => _openFullScreen(context),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('Tap to expand full screen', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedAccuracyLineChart extends StatelessWidget {
  final List<SessionData> sessions;
  final bool isFullScreen;
  const _AnimatedAccuracyLineChart({required this.sessions, this.isFullScreen = false});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final visibleCount = (sessions.length * t).ceil().clamp(1, sessions.length);
        final visibleSessions = sessions.sublist(0, visibleCount);

        return LineChart(
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
                  interval: (sessions.length / 4).ceil().toDouble(),
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx >= 0 && idx < sessions.length) {
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
            maxX: (sessions.length - 1).toDouble(),
            minY: 0,
            maxY: 100,
            lineBarsData: [
              LineChartBarData(
                spots: visibleSessions.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.accuracy)).toList(),
                isCurved: true,
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                barWidth: isFullScreen ? 4 : 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) {
                    final isLast = index == visibleSessions.length - 1;
                    return FlDotCirclePainter(
                      radius: isLast ? (isFullScreen ? 6 : 5) : (isFullScreen ? 5 : 4),
                      color: isLast ? AppColors.success : AppColors.primary,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withValues(alpha: 0.25), AppColors.primary.withValues(alpha: 0)],
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
          duration: Duration.zero,
        );
      },
    );
  }
}

class _FullScreenAccuracyChart extends StatelessWidget {
  final List<SessionData> sessions;
  const _FullScreenAccuracyChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text('Accuracy Trend', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text('${sessions.length} sessions tracked', style: const TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 32),
              Expanded(
                child: sessions.length >= 2
                    ? Hero(
                        tag: 'accuracyChartMini',
                        child: Material(
                          color: Colors.transparent,
                          child: _AnimatedAccuracyLineChart(sessions: sessions, isFullScreen: true),
                        ),
                      )
                    : const Center(child: Text('Not enough sessions yet', style: TextStyle(color: Colors.white54))),
              ),
              const SizedBox(height: 20),
              _sessionTimeline(sessions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sessionTimeline(List<SessionData> sessions) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, idx) {
          final s = sessions[idx];
          return Container(
            width: 80,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('S${idx + 1}', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                Text('${s.accuracy.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 3. LEVEL PROGRESS — replaces the Mode Score card that duplicated
// Dashboard's Mode Performance card
// ═══════════════════════════════════════════════════════

class _LevelProgressCard extends StatelessWidget {
  final Map<String, dynamic> progression;
  const _LevelProgressCard({required this.progression});

  static const _levelLabels = {
    'beginner': 'Beginner',
    'intermediate': 'Intermediate',
    'expert': 'Expert',
  };

  @override
  Widget build(BuildContext context) {
    final level = progression['current_level']?.toString() ?? 'beginner';
    final avgScore = (progression['rolling_avg_score'] as num?)?.toDouble() ?? 0;
    final errorRate = (progression['rolling_error_rate'] as num?)?.toDouble() ?? 0;
    final masteryRatio = (progression['mastery_ratio'] as num?)?.toDouble() ?? 0;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Level Progress',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_levelLabels[level] ?? level,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat('${avgScore.toStringAsFixed(0)}%', 'Avg. Score', AppColors.success),
              _stat('${errorRate.toStringAsFixed(0)}%', 'Error Rate', AppColors.warning),
              _stat('${masteryRatio.toStringAsFixed(0)}%', 'Mastery', AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// 4. ERROR BREAKDOWN — content centered
// ═══════════════════════════════════════════════════════

class _ErrorEntry {
  final String label;
  final int count;
  final Color color;
  const _ErrorEntry(this.label, this.count, this.color);
}

class _ErrorBreakdownCard extends StatelessWidget {
  final ErrorBreakdown breakdown;
  const _ErrorBreakdownCard({required this.breakdown});

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _FullScreenErrorBreakdown(breakdown: breakdown),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final total = breakdown.total;

    if (total == 0) {
      return _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Error Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 40),
            Column(
              children: [
                Icon(Icons.check_circle, size: 48, color: Colors.green.shade300),
                const SizedBox(height: 12),
                const Text('No errors recorded yet!', style: TextStyle(fontSize: 15, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    final entries = [
      _ErrorEntry('Substitution', breakdown.substitution, const Color(0xFFEF4444)),
      _ErrorEntry('Omission', breakdown.omission, AppColors.warning),
      _ErrorEntry('Insertion', breakdown.insertion, AppColors.accent),
    ];

    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ResponsiveCardHeader(
              title: const Text('Error Breakdown',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_full_rounded, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('Tap to expand', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final pieSize = constraints.maxWidth < 320 ? 100.0 : 130.0;
                return Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: pieSize,
                        height: pieSize,
                        child: PieChart(
                          PieChartData(
                            sections: entries.map((e) => _pieSection(e, total)).toList(),
                            centerSpaceRadius: pieSize * 0.26,
                            sectionsSpace: 2,
                          ),
                          swapAnimationDuration: const Duration(milliseconds: 600),
                          swapAnimationCurve: Curves.easeOutCubic,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: entries.map((e) => _pieLegend(e, total)).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _pieSection(_ErrorEntry e, int total) {
    final pct = total > 0 ? (e.count / total * 100) : 0;
    return PieChartSectionData(
      value: e.count.toDouble(),
      title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
      radius: 42,
      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      color: e.color,
    );
  }

  Widget _pieLegend(_ErrorEntry e, int total) {
    final pct = total > 0 ? (e.count / total * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: e.color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
              Text('${e.count} errors ($pct%)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }
}

class _FullScreenErrorBreakdown extends StatelessWidget {
  final ErrorBreakdown breakdown;
  const _FullScreenErrorBreakdown({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final total = breakdown.total;
    final entries = [
      _ErrorEntry('Substitution', breakdown.substitution, const Color(0xFFEF4444)),
      _ErrorEntry('Omission', breakdown.omission, AppColors.warning),
      _ErrorEntry('Insertion', breakdown.insertion, AppColors.accent),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text('Error Breakdown', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text('$total total errors analyzed', style: const TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: entries.map((e) => _detailBar(e, total)).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: entries.map((e) => _pieSection(e, total)).toList(),
                    centerSpaceRadius: 50,
                    sectionsSpace: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailBar(_ErrorEntry e, int total) {
    final pct = total > 0 ? (e.count / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('${e.count}', style: TextStyle(color: e.color, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                return LinearProgressIndicator(
                  value: t,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(e.color),
                  minHeight: 12,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(_ErrorEntry e, int total) {
    final pct = total > 0 ? (e.count / total * 100) : 0;
    return PieChartSectionData(
      value: e.count.toDouble(),
      title: '${pct.toStringAsFixed(0)}%',
      radius: 60,
      titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      color: e.color,
    );
  }
}

// ═══════════════════════════════════════════════════════
// 5. TOP MISPRONOUNCED WORDS
// ═══════════════════════════════════════════════════════

class _TopErrorsCard extends StatefulWidget {
  final List<WordError> errors;
  const _TopErrorsCard({required this.errors});

  @override
  State<_TopErrorsCard> createState() => _TopErrorsCardState();
}

class _TopErrorsCardState extends State<_TopErrorsCard> {
  int _limit = 5;
  String _sortBy = 'Frequency';

  static const Color _accent = Color(0xFFEF4444);
  static const Color _bg = Color(0xFFFEF2F2);
  static const Color _border = Color(0xFFFECACA);

  List<WordError> get _sortedErrors {
    final list = List<WordError>.from(widget.errors);
    switch (_sortBy) {
      case 'Rate':
        list.sort((a, b) => b.errorRate.compareTo(a.errorRate));
        break;
      case 'A-Z':
        list.sort((a, b) => a.word.compareTo(b.word));
        break;
      case 'Frequency':
      default:
        list.sort((a, b) => b.errorCount.compareTo(a.errorCount));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.errors.isEmpty) {
      return _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Top Mispronounced Words', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 40),
            Column(
              children: [
                Icon(Icons.emoji_events, size: 48, color: Colors.amber.shade300),
                const SizedBox(height: 12),
                const Text('Perfect pronunciation so far!', style: TextStyle(fontSize: 15, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    final sorted = _sortedErrors;
    final maxAvailable = sorted.length;
    final optionSet = <int>{3, 5, 10, maxAvailable}..removeWhere((o) => o > maxAvailable);
    final options = optionSet.toList()..sort();
    final dropdownValue = options.contains(_limit) ? _limit : options.last;
    final visible = sorted.take(dropdownValue).toList();

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResponsiveCardHeader(
            title: const Text('Top Mispronounced Words', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            trailing: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.divider)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      isDense: true,
                      icon: const Icon(Icons.sort_rounded, size: 14, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'Frequency', child: Text('By Frequency')),
                        DropdownMenuItem(value: 'Rate', child: Text('By Error Rate')),
                        DropdownMenuItem(value: 'A-Z', child: Text('A-Z')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _sortBy = v);
                      },
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: dropdownValue,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _accent),
                      style: const TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w600),
                      items: options.map((o) => DropdownMenuItem(value: o, child: Text('Top $o'))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _limit = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            breakpoint: 340,
          ),
          const SizedBox(height: 16),
          ...visible.asMap().entries.map((entry) {
            final idx = entry.key;
            final word = entry.value;
            return TweenAnimationBuilder<double>(
              key: ValueKey('${word.word}_$_sortBy'),
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + idx * 80),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                return Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
                );
              },
              child: _wordErrorCard(word, idx + 1),
            );
          }),
        ],
      ),
    );
  }

  Widget _wordErrorCard(WordError word, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
            child: Center(child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"${word.word}"', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Wrong ${word.errorCount}/${word.totalCount} times', style: const TextStyle(fontSize: 11, color: _accent), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${word.errorRate.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _accent)),
              const Text('error rate', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 6. STATS
// ═══════════════════════════════════════════════════════

class _GridStat {
  final num rawValue;
  final bool isDouble;
  final String suffix;
  final String label;
  final Color color;
  final IconData icon;
  _GridStat({
    required this.rawValue,
    this.isDouble = false,
    this.suffix = '',
    required this.label,
    required this.color,
    required this.icon,
  });
}

class _StatsGridCard extends StatefulWidget {
  final TotalStats stats;
  const _StatsGridCard({required this.stats});

  @override
  State<_StatsGridCard> createState() => _StatsGridCardState();
}

class _StatsGridCardState extends State<_StatsGridCard> {
  String _view = 'Grid';

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final items = [
      _GridStat(rawValue: s.sessions, label: 'Total Sessions', color: AppColors.primary, icon: Icons.event_available_rounded),
      _GridStat(rawValue: s.words, label: 'Words Practiced', color: AppColors.accent, icon: Icons.record_voice_over_rounded),
      _GridStat(rawValue: s.errors, label: 'Errors Corrected', color: AppColors.success, icon: Icons.check_circle_outline_rounded),
      _GridStat(rawValue: s.minutes / 60, isDouble: true, suffix: 'h', label: 'Practice Time', color: AppColors.brandBlue, icon: Icons.timer_outlined),
    ];

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ResponsiveCardHeader(
            title: const Text('Your Stats',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: ['Grid', 'List', 'Carousel'].map((v) {
                  final isActive = _view == v;
                  return GestureDetector(
                    onTap: () => setState(() => _view = v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))] : null,
                      ),
                      child: Text(
                        v,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? AppColors.textPrimary : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            breakpoint: 300,
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: _buildView(items),
          ),
        ],
      ),
    );
  }

  Widget _buildView(List<_GridStat> items) {
    switch (_view) {
      case 'List':
        return _listLayout(items);
      case 'Carousel':
        return _carouselLayout(items);
      case 'Grid':
      default:
        return _gridLayout(items);
    }
  }

  Widget _gridLayout(List<_GridStat> items) {
    return LayoutBuilder(
      key: const ValueKey('grid'),
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 260 ? 1 : 2;
        final aspectRatio = crossAxisCount == 1
            ? 3.2
            : (constraints.maxWidth < 340 ? 1.05 : 1.3);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: items.map((s) => _gridItem(s)).toList(),
        );
      },
    );
  }

  Widget _listLayout(List<_GridStat> items) {
    return Column(
      key: const ValueKey('list'),
      children: items.map((s) => _listItem(s)).toList(),
    );
  }

  Widget _carouselLayout(List<_GridStat> items) {
    return SizedBox(
      key: const ValueKey('carousel'),
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, idx) {
          final stat = items[idx];
          return Container(
            width: 140,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: stat.color.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: stat.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(stat.icon, size: 22, color: stat.color),
                ),
                const SizedBox(height: 12),
                _AnimatedCounter(
                  value: stat.rawValue,
                  isDouble: stat.isDouble,
                  suffix: stat.suffix,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: stat.color),
                ),
                const SizedBox(height: 4),
                Text(stat.label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _gridItem(_GridStat stat) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 105 || constraints.maxWidth < 130;
        final isVeryCompact = constraints.maxHeight < 85;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          padding: EdgeInsets.all(isVeryCompact ? 8 : (isCompact ? 10 : 14)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(isVeryCompact ? 5 : (isCompact ? 6 : 8)),
                decoration: BoxDecoration(color: stat.color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(stat.icon, size: isVeryCompact ? 12 : (isCompact ? 14 : 16), color: stat.color),
              ),
              SizedBox(height: isVeryCompact ? 3 : (isCompact ? 4 : 8)),
              _AnimatedCounter(
                value: stat.rawValue,
                isDouble: stat.isDouble,
                suffix: stat.suffix,
                style: TextStyle(
                  fontSize: isVeryCompact ? 14 : (isCompact ? 16 : 20),
                  fontWeight: FontWeight.w700,
                  color: stat.color,
                ),
              ),
              SizedBox(height: isVeryCompact ? 1 : (isCompact ? 2 : 4)),
              Text(
                stat.label,
                style: TextStyle(
                  fontSize: isVeryCompact ? 9 : (isCompact ? 10 : 11),
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: isCompact ? 1 : 2,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _listItem(_GridStat stat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: stat.color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(stat.icon, size: 18, color: stat.color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(stat.label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          _AnimatedCounter(
            value: stat.rawValue,
            isDouble: stat.isDouble,
            suffix: stat.suffix,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: stat.color),
          ),
        ],
      ),
    );
  }
}

// ── Data Models (match backend contract) ────

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
  final int omission;
  final int insertion;

  ErrorBreakdown({required this.substitution, required this.omission, required this.insertion});

  int get total => substitution + omission + insertion;

  factory ErrorBreakdown.empty() => ErrorBreakdown(substitution: 0, omission: 0, insertion: 0);

  factory ErrorBreakdown.fromJson(Map<String, dynamic> json) => ErrorBreakdown(
        substitution: (json['substitution'] as num?)?.toInt() ?? 0,
        omission: (json['omission'] as num?)?.toInt() ?? 0,
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