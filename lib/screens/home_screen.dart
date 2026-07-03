import 'package:flutter/material.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to sign out of PronounceMate?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _AppDrawer(onLogout: _confirmLogout),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
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
                          BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2))
                        ],
                      ),
                      child: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 22),
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
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        Text('${UserSession.instance.firstName} 👋',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            )),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: const [
                        BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2))
                      ],
                    ),
                    child: const Icon(Icons.notifications_outlined,
                        color: AppColors.textPrimary, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── AI Speaker Hero ───────────────────────────────
              const _SpeakerHero(),
              const SizedBox(height: 24),

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
                          const Text('Complete 2 Practice Sessions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              )),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: const LinearProgressIndicator(
                              value: 0.5,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                              minHeight: 7,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text('1 of 2 completed',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.flag_rounded,
                        color: Colors.white54, size: 48),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Quick Stats ──────────────────────────────────
              const SectionHeader(
                title: 'Your Progress',
                subtitle: 'Last 7 days',
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.1,
                children: const [
                  StatCard(
                    label: 'Sessions Done',
                    value: '12',
                    icon: Icons.mic_rounded,
                    color: AppColors.primary,
                  ),
                  StatCard(
                    label: 'Avg. Accuracy',
                    value: '78%',
                    icon: Icons.track_changes_rounded,
                    color: AppColors.success,
                  ),
                  StatCard(
                    label: 'Words Practiced',
                    value: '340',
                    icon: Icons.spellcheck_rounded,
                    color: AppColors.warning,
                  ),
                  StatCard(
                    label: 'Streak',
                    value: '5 days',
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.error,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Recent Sessions ──────────────────────────────
              const SectionHeader(title: 'Recent Sessions'),
              const SizedBox(height: 14),
              ...[
                const _RecentSession(
                  title: 'Daily Conversation',
                  date: 'Today, 10:30 AM',
                  score: 82,
                  duration: '8 min',
                ),
                const _RecentSession(
                  title: 'Public Speaking',
                  date: 'Yesterday, 3:15 PM',
                  score: 74,
                  duration: '12 min',
                ),
                const _RecentSession(
                  title: 'Script-Based',
                  date: 'Mon, 9:00 AM',
                  score: 91,
                  duration: '6 min',
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── App Drawer ───────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  const _AppDrawer({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer header with gradient
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
                      color: Colors.white.withOpacity(0.25),
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
                  Text('Username account',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Navigation items
            _DrawerItem(
              icon: Icons.bar_chart_rounded,
              label: 'Dashboard',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const DashboardScreen()));
              },
            ),
            _DrawerItem(
              icon: Icons.person_outline_rounded,
              label: 'Edit Profile',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
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
            // Logout button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  onLogout();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
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

  const _DrawerItem({required this.icon, required this.label, required this.onTap});

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

// ── AI Speaker Hero ───────────────────────────────────────────────
class _SpeakerHero extends StatelessWidget {
  const _SpeakerHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 195,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A6B7A), Color(0xFF2E9BAB), Color(0xFF5BBDCC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: -35,
                top: -35,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 2),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 125,
                  height: 125,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
                  ),
                ),
              ),
              Positioned(
                right: 38,
                top: 38,
                child: Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -25,
                bottom: -25,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.07), width: 2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: const [
                    _SpeakerIllustration(),
                    SizedBox(width: 20),
                    Expanded(child: _SpeakerCopy()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SpeakerIllustration extends StatelessWidget {
  const _SpeakerIllustration();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
            const Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 34),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [8.0, 18.0, 30.0, 22.0, 12.0, 26.0, 14.0]
              .map((h) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      width: 5,
                      height: h,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _SpeakerCopy extends StatelessWidget {
  const _SpeakerCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Pronunciation\nCoach',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Real-time feedback on your English pronunciation, powered by advanced AI models.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _HeroPill('Real-time'),
            _HeroPill('Accurate'),
          ],
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  const _HeroPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

// ── Recent Session Row ───────────────────────────────────────────
class _RecentSession extends StatelessWidget {
  final String title;
  final String date;
  final int score;
  final String duration;

  const _RecentSession({
    required this.title,
    required this.date,
    required this.score,
    required this.duration,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _scoreColor.withOpacity(0.12),
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
