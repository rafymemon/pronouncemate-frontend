// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  // ── State ───────────────────────────────────────────────
  bool _loading = true;
  Map<String, dynamic> _profile = {};
  String? _errorMsg;

  // Settings toggles (local only — extend to backend if needed)
  bool _voiceFeedback      = true;
  bool _dailyReminders     = true;
  bool _autoSaveRecordings = false;

  // ── Level config (still used for the header badge/gradient) ──
  static const _levelLabels = {
    'beginner':           'Beginner',
    'intermediate':       'Intermediate',
    'upper_intermediate': 'Upper Intermediate',
    'advanced':           'Advanced',
    'fluent':             'Fluent',
  };

  static const _levelColors = {
    'beginner':           Color(0xFF16A34A),
    'intermediate':       Color(0xFF0284C7),
    'upper_intermediate': Color(0xFF7C3AED),
    'advanced':           Color(0xFFD97706),
    'fluent':             Color(0xFFDC2626),
  };

  static const _levelIcons = {
    'beginner':           Icons.looks_one_rounded,
    'intermediate':       Icons.looks_two_rounded,
    'upper_intermediate': Icons.looks_3_rounded,
    'advanced':           Icons.looks_4_rounded,
    'fluent':             Icons.looks_5_rounded,
  };

  // ── Lifecycle ────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() { _loading = true; _errorMsg = null; });
    final data = await ApiService.getProfile();
    if (!mounted) return;
    if (data['error'] != null) {
      setState(() { _loading = false; _errorMsg = data['error'].toString(); });
      return;
    }
    setState(() { _loading = false; _profile = data; });
  }

  // ── Getters ──────────────────────────────────────────────
  String get _displayName {
    final fn = _profile['first_name']?.toString().trim() ?? '';
    return fn.isNotEmpty ? fn : _profile['username'] ?? 'User';
  }

  String get _email      => _profile['email']       ?? '';
  String get _username   => _profile['username']    ?? '';
  String get _memberSince => _profile['member_since'] ?? '';

  String get _storedLevel   => _profile['proficiency_level'] ?? 'beginner';

  String get _favMode   => _profile['favorite_mode']   ?? 'None yet';

  Color  get _levelColor => _levelColors[_storedLevel] ?? AppColors.primary;
  String get _levelLabel => _levelLabels[_storedLevel] ?? 'Beginner';

  String _initials() {
    final parts = _displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _displayName.isNotEmpty
        ? _displayName[0].toUpperCase() : 'U';
  }

  // ── API calls ────────────────────────────────────────────
  Future<void> _updateName(String name) async {
    final prev = _profile['first_name'];
    setState(() => _profile['first_name'] = name);
    final res = await ApiService.updateProfile({'first_name': name});
    if (res['error'] != null) {
      setState(() => _profile['first_name'] = prev);
      _showError('Could not update name');
    } else {
      _showSuccess('Name updated');
    }
  }

  Future<void> _clearHistory() async {
    final res = await ApiService.clearSessionHistory();
    if (res['error'] != null) {
      _showError('Could not clear history');
    } else {
      _showSuccess('Session history cleared');
      await _loadProfile();
    }
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadProfile,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMsg != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 16),
                        _sectionLabel('Practice Settings'),
                        const SizedBox(height: 10),
                        _buildPracticeSettings(),
                        const SizedBox(height: 16),
                        _sectionLabel('App Settings'),
                        const SizedBox(height: 10),
                        _buildAppSettings(),
                        const SizedBox(height: 16),
                        _sectionLabel('Data'),
                        const SizedBox(height: 10),
                        _buildDataSection(),
                        const SizedBox(height: 24),
                        _buildLogoutButton(),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'PronounceMate v1.0.0 — FYP 2025\n'
                            'MUET Jamshoro · Batch 22SW · Group 04',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textHint,
                                height: 1.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ══ Profile Header Card ═════════════════════════════════
  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, _levelColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5), width: 2),
              ),
              child: Center(
                child: Text(_initials(),
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(width: 16),

            // Name + username + email
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text('@$_username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
                if (_email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.mail_outline,
                        color: Colors.white60, size: 13),
                    const SizedBox(width: 4),
                    Flexible(child: Text(_email,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12))),
                  ]),
                ],
              ],
            )),

            // Edit button
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.white70, size: 22),
              onPressed: _showEditDialog,
              tooltip: 'Edit Profile',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ]),

          const SizedBox(height: 14),

          // Member since + level badges — wraps on narrow screens
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoBadge(Icons.calendar_today_outlined,
                  'Joined $_memberSince'),
              _infoBadge(
                _levelIcons[_storedLevel] ?? Icons.bar_chart_rounded,
                _levelLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white70, size: 13),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ══ Practice Settings ════════════════════════════════════
  Widget _buildPracticeSettings() {
    return Column(children: [
      _tileSwitch(
        icon: Icons.volume_up_rounded,
        title: 'Voice Feedback',
        subtitle: 'Play audio corrections for mispronounced words',
        value: _voiceFeedback,
        onChanged: (v) => setState(() => _voiceFeedback = v),
      ),
      _tileSwitch(
        icon: Icons.save_alt_rounded,
        title: 'Auto-Save Recordings',
        subtitle: 'Store session audio for personal review',
        value: _autoSaveRecordings,
        onChanged: (v) => setState(() => _autoSaveRecordings = v),
      ),
      _tileAction(
        icon: Icons.translate_rounded,
        title: 'Reference Accent',
        subtitle: 'American English',
        onTap: _showAccentPicker,
      ),
    ]);
  }

  // ══ App Settings ═════════════════════════════════════════
  Widget _buildAppSettings() {
    return Column(children: [
      _tileSwitch(
        icon: Icons.notifications_outlined,
        title: 'Daily Practice Reminders',
        subtitle: 'Get notified to practice every day',
        value: _dailyReminders,
        onChanged: (v) => setState(() => _dailyReminders = v),
      ),
      _tileAction(
        icon: Icons.lock_outline_rounded,
        title: 'Change Password',
        subtitle: 'Update your account password',
        onTap: _showChangePassword,
      ),
      _tileAction(
        icon: Icons.info_outline_rounded,
        title: 'About PronounceMate',
        subtitle: 'FYP 2025 · MUET Jamshoro',
        onTap: _showAbout,
      ),
    ]);
  }

  // ══ Data Section ═════════════════════════════════════════
  Widget _buildDataSection() {
    return Column(children: [
      _tileAction(
        icon: Icons.download_rounded,
        title: 'Export Progress Report',
        subtitle: 'Download your session history as a report',
        onTap: () => _showSnack(
            'Export feature coming soon', isInfo: true),
      ),
      _tileAction(
        icon: Icons.favorite_border_rounded,
        title: 'Favorite Mode',
        subtitle: _favMode,
        onTap: () {},
        showArrow: false,
      ),
      _tileAction(
        icon: Icons.delete_outline_rounded,
        title: 'Clear Session History',
        subtitle: 'Remove all practice sessions permanently',
        iconColor: AppColors.error,
        textColor: AppColors.error,
        onTap: _confirmClearHistory,
      ),
    ]);
  }

  // ══ Logout ═══════════════════════════════════════════════
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Sign Out',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  // ══ Tile Widgets ══════════════════════════════════════════
  Widget _tileSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        _iconBox(icon, AppColors.primary),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14,
                color: AppColors.textPrimary)),
            Text(subtitle, style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
          ],
        )),
        Switch(
          value: value, onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ]),
    );
  }

  Widget _tileAction({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color iconColor = AppColors.primary,
    Color textColor = AppColors.textPrimary,
    bool showArrow = true,
  }) {
    return _card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Row(children: [
          _iconBox(icon, iconColor),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14,
                  color: textColor)),
              if (subtitle != null)
                Text(subtitle, style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            ],
          )),
          if (showArrow)
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textHint, size: 14),
        ]),
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _card({required Widget child, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(
            color: AppColors.cardShadow, blurRadius: 6,
            offset: Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 2, left: 2),
    child: Text(label, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.bold,
        color: AppColors.textPrimary)),
  );

  // ══ Dialogs ═══════════════════════════════════════════════
  void _showEditDialog() {
    final nameCtrl = TextEditingController(text: _displayName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Edit Profile',
                style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Display Name',
              hint: 'Your name',
              prefixIcon: Icons.person_outline,
              controller: nameCtrl,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save Changes',
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) await _updateName(name);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    ).whenComplete(nameCtrl.dispose);
  }

  void _showAccentPicker() {
    const accents = [
      'American English',
      'British English',
      'Australian English',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Reference Accent',
              style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
              'Note: PronounceMate currently uses American English phoneme standards.',
              style: TextStyle(fontSize: 12,
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ...accents.map((a) => ListTile(
            title: Text(a),
            trailing: const Icon(Icons.lock_outline_rounded,
                size: 16, color: AppColors.textHint),
            subtitle: const Text('Coming in a future update',
                style: TextStyle(fontSize: 11)),
          )),
        ]),
      ),
    );
  }

  void _showChangePassword() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Change Password',
                style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Current Password',
              hint: '••••••••',
              prefixIcon: Icons.lock_outline,
              controller: oldCtrl,
              isPassword: true,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'New Password',
              hint: '••••••••',
              prefixIcon: Icons.lock_reset_rounded,
              controller: newCtrl,
              isPassword: true,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Update Password',
              onPressed: () {
                Navigator.pop(ctx);
                _showSnack('Password change coming soon', isInfo: true);
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    ).whenComplete(() {
      oldCtrl.dispose();
      newCtrl.dispose();
    });
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const PronouncemateLogo(size: 52),
          const SizedBox(height: 16),
          const Text('PronounceMate v1.0.0',
              style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'An AI-powered real-time English pronunciation '
            'detection and improvement system. '
            'Built as a Final Year Project at Mehran University '
            'of Engineering, Science & Technology, Jamshoro.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13,
                color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text('Batch 22SW · Group 04',
              style: TextStyle(fontSize: 12,
                  color: AppColors.textHint,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
          const Text('Supervisor: Prof. Areej Meghji',
              style: TextStyle(fontSize: 12,
                  color: AppColors.textHint)),
        ]),
        actions: [TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        )],
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const Text('Clear Session History',
            style: TextStyle(fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        content: const Text(
          'This will permanently delete all your practice sessions, '
          'scores, and word results. Your account will not be deleted. '
          'This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _clearHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to sign out of PronounceMate?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await UserSession.instance.signOut();
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

  // ══ Error view ════════════════════════════════════════════
  Widget _buildError() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wifi_off, size: 52, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(_errorMsg!,
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _loadProfile,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white),
        ),
      ],
    ));
  }

  // ── Snack helpers ─────────────────────────────────────────
  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: Colors.green.shade700,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSnack(String msg, {bool isInfo = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isInfo ? AppColors.primary : AppColors.error,
    ));
  }
}