import 'package:flutter/material.dart';
import '../services/user_progress_service.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsOn = true;
  bool _soundFeedback = true;
  bool _autoSaveRecordings = false;
  String _selectedAccent = 'American English';
  String _proficiencyLevel = UserSession.instance.proficiencyLevel;

  late Future<UserProgressSummary> _summaryFuture;

  final List<String> _accents = [
    'American English',
    'British English',
    'Australian English',
  ];
  final List<String> _proficiencyLevels = ['Beginner', 'Intermediate', 'Advanced'];

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

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to sign out of PronounceMate?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await UserSession.instance.signOut();
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

  void _onProgressChanged() {
    if (!mounted) return;
    setState(() {
      _summaryFuture = UserProgressService.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UserSession.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Profile & Settings')),
          body: FutureBuilder<UserProgressSummary>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final summary = snapshot.data;
              if (summary == null) {
                return const Center(
                  child: Text(
                    'Could not load your profile data.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accentLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                            ),
                            child: Center(
                              child: Text(
                                UserSession.instance.initials,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  summary.displayName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Username account',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$_proficiencyLevel Level',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 22),
                            onPressed: _showEditProfileDialog,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        _miniStat('${summary.totalSessions}', 'Sessions'),
                        _divider(),
                        _miniStat('${summary.averageAccuracy.toStringAsFixed(0)}%', 'Avg Score'),
                        _divider(),
                        _miniStat('${summary.streakDays} days', 'Streak'),
                        _divider(),
                        _miniStat('${summary.wordsPracticed ?? 0}', 'Words'),
                      ],
                    ),
                    const SizedBox(height: 26),
                    _sectionLabel('Practice Settings'),
                    const SizedBox(height: 10),
                    _settingsTile(
                      icon: Icons.signal_cellular_alt_rounded,
                      title: 'Proficiency Level',
                      subtitle: 'Your current English skill level',
                      trailing: DropdownButton<String>(
                        value: _proficiencyLevel,
                        underline: const SizedBox(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        items: _proficiencyLevels
                            .map((level) => DropdownMenuItem(value: level, child: Text(level)))
                            .toList(),
                        onChanged: (val) async {
                          if (val == null) return;
                          setState(() => _proficiencyLevel = val);
                          await UserSession.instance.setProficiencyLevel(val);
                        },
                      ),
                    ),
                    _settingsTile(
                      icon: Icons.language_rounded,
                      title: 'Reference Accent',
                      subtitle: _selectedAccent,
                      trailing: DropdownButton<String>(
                        value: _selectedAccent,
                        underline: const SizedBox(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        items: _accents
                            .map((accent) => DropdownMenuItem(value: accent, child: Text(accent)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedAccent = val ?? _selectedAccent),
                      ),
                    ),
                    _switchTile(
                      icon: Icons.volume_up_rounded,
                      title: 'Voice Feedback',
                      subtitle: 'Play audio corrections after errors',
                      value: _soundFeedback,
                      onChanged: (value) => setState(() => _soundFeedback = value),
                    ),
                    _switchTile(
                      icon: Icons.save_alt_rounded,
                      title: 'Auto-Save Recordings',
                      subtitle: 'Store session audio for review',
                      value: _autoSaveRecordings,
                      onChanged: (value) => setState(() => _autoSaveRecordings = value),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('App Settings'),
                    const SizedBox(height: 10),
                    _switchTile(
                      icon: Icons.notifications_outlined,
                      title: 'Daily Reminders',
                      subtitle: 'Get reminded to practice every day',
                      value: _notificationsOn,
                      onChanged: (value) => setState(() => _notificationsOn = value),
                    ),
                    _actionTile(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      onTap: () {},
                    ),
                    _actionTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      onTap: () {},
                    ),
                    _actionTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About PronounceMate',
                      onTap: _showAboutDialog,
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Data Management'),
                    const SizedBox(height: 10),
                    _actionTile(
                      icon: Icons.download_rounded,
                      title: 'Export My Progress Report',
                      onTap: () {},
                    ),
                    _actionTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Clear Session History',
                      iconColor: AppColors.error,
                      textColor: AppColors.error,
                      onTap: () {},
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _confirmLogout,
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text('Sign Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'PronounceMate v1.0.0 — FYP 2025',
                        style: TextStyle(fontSize: 12, color: AppColors.textHint),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _miniStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const SizedBox(width: 8);

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2, left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = AppColors.primary,
    Color textColor = AppColors.textPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [
            BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textHint, size: 15),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: UserSession.instance.name);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Edit Profile',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Username',
              hint: 'Your username',
              prefixIcon: Icons.person_outline,
              controller: nameCtrl,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save Changes',
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                if (newName.isNotEmpty) {
                  await UserSession.instance.setUsername(newName);
                  _summaryFuture = UserProgressService.load();
                }
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                setState(() {});
              },
            ),
          ],
        ),
      ),
    ).whenComplete(nameCtrl.dispose);
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PronouncemateLogo(size: 52),
            SizedBox(height: 16),
            Text(
              'An AI-powered English pronunciation detection and improvement system. Built as a Final Year Project at Mehran University.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            SizedBox(height: 8),
            Text(
              'Batch 22SW • Group 04',
              style: TextStyle(fontSize: 12, color: AppColors.textHint, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
