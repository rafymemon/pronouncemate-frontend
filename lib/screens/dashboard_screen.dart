import 'package:flutter/material.dart';
import '../services/user_progress_service.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<UserProgressSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = UserProgressService.load();
    UserProgressService.instance.addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    UserProgressService.instance.removeListener(_onProgressChanged);
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _summaryFuture = UserProgressService.load();
    });
    await _summaryFuture;
  }

  void _onProgressChanged() {
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UserSession.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Dashboard'),
            actions: [
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: FutureBuilder<UserProgressSummary>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.accent));
              }
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Could not load dashboard data right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              final summary = snapshot.data;
              if (summary == null) return const SizedBox.shrink();

              return RefreshIndicator(
                onRefresh: _reload,
                color: AppColors.accent,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 44),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    const Text('Total Sessions', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 8),
                                    Text('${summary.totalSessions}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Container(height: 50, width: 1, color: Colors.white.withValues(alpha: 0.3)),
                                Column(
                                  children: [
                                    const Text('Best Score', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 8),
                                    Text('${summary.bestScore.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text('Recent Sessions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 16),
                      if (summary.recentSessions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: const Text('No sessions recorded yet. Start practicing!', style: TextStyle(color: AppColors.textSecondary)),
                        )
                      else
                        ...summary.recentSessions.map((session) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.divider),
                                boxShadow: const [
                                  BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 2)),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.history_rounded, color: AppColors.primary),
                                ),
                                title: Text(session.title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                subtitle: Text(session.dateLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${session.score.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent)),
                                    Text(session.grade, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            )),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}