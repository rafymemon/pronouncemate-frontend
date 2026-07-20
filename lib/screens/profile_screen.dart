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

  // ── Level config ─────────────────────────────────────────
  static const _levelOrder = [
    'beginner', 'intermediate', 'upper_intermediate', 'advanced', 'fluent'
  ];

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
  String get _computedLevel => _profile['computed_level']    ?? 'beginner';
  String get _levelReason   => _profile['level_reason']      ?? '';

  int    get _sessions  => _profile['total_sessions']  as int?  ?? 0;
  double get _avgScore  => (_profile['avg_accuracy']   as num?) ?.toDouble() ?? 0.0;
  double get _bestScore => (_profile['best_score']     as num?) ?.toDouble() ?? 0.0;
  int    get _words     => _profile['total_words']     as int?  ?? 0;
  int    get _streak    => _profile['streak_days']     as int?  ?? 0;
  String get _favMode   => _profile['favorite_mode']   ?? 'None yet';

  List   get _topErrors => _profile['top_errors']  as List? ?? [];

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
  Future<void> _updateLevel(String level) async {
    final prev = _storedLevel;
    setState(() => _profile['proficiency_level'] = level);

    final res = await ApiService.updateProfile({'proficiency_level': level});
    if (res['error'] != null) {
      setState(() => _profile['proficiency_level'] = prev);
      _showError('Could not update level');
    } else {
      _showSuccess('Level updated to ${_levelLabels[level]}');
    }
  }

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
                        _buildStatsRow(),
                        const SizedBox(height: 16),
                        _buildLevelSection(),
                        const SizedBox(height: 16),
                        if (_topErrors.isNotEmpty) ...[
                          _buildTopErrors(),
                          const SizedBox(height: 16),
                        ],
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
          Row(children: [
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
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text('@$_username',
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
            ),
          ]),

          const SizedBox(height: 14),

          // Member since + level badges
          Row(children: [
            _infoBadge(Icons.calendar_today_outlined,
                'Joined $_memberSince'),
            const SizedBox(width: 8),
            _infoBadge(
              _levelIcons[_storedLevel] ?? Icons.bar_chart_rounded,
              _levelLabel,
            ),
          ]),
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

  // ══ Stats Row ═══════════════════════════════════════════
  Widget _buildStatsRow() {
    final stats = [
      {'value': '$_sessions',                     'label': 'Sessions'},
      {'value': '${_avgScore.toStringAsFixed(0)}%','label': 'Avg Score'},
      {'value': '${_bestScore.toStringAsFixed(0)}%','label': 'Best'},
      {'value': '$_streak days',                  'label': 'Streak'},
      {'value': '$_words',                        'label': 'Words'},
    ];
    return Row(
      children: stats.map((s) {
        final isLast = s == stats.last;
        return Expanded(child: Row(children: [
          Expanded(child: _statBox(s['value']!, s['label']!)),
          if (!isLast) const SizedBox(width: 6),
        ]));
      }).toList(),
    );
  }

  Widget _statBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(
            color: AppColors.cardShadow, blurRadius: 6,
            offset: Offset(0, 2))],
      ),
      child: Column(children: [
        Text(value,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold,
                color: AppColors.primary)),
        const SizedBox(height: 2),
        Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
      ]),
    );
  }

  // ══ Level Section ════════════════════════════════════════
  Widget _buildLevelSection() {
    final bool levelsDiffer = _storedLevel != _computedLevel;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_levelIcons[_storedLevel] ?? Icons.bar_chart_rounded,
              color: _levelColor, size: 22),
          const SizedBox(width: 10),
          const Text('Proficiency Level',
              style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const Spacer(),
          TextButton(
            onPressed: _showLevelPicker,
            child: Text('Change',
                style: TextStyle(fontSize: 13, color: AppColors.primary)),
          ),
        ]),

        const SizedBox(height: 12),

        // Progress strip
        Row(children: _levelOrder.map((l) {
          final idx    = _levelOrder.indexOf(l);
          final curIdx = _levelOrder.indexOf(_storedLevel);
          final active = idx <= curIdx;
          return Expanded(child: Padding(
            padding: EdgeInsets.only(
                right: l == _levelOrder.last ? 0 : 3),
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                color: active ? _levelColor : AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ));
        }).toList()),

        const SizedBox(height: 10),

        // Current and computed
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Level: ${_levelLabels[_storedLevel]}',
                  style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700, color: _levelColor)),
              const SizedBox(height: 2),
              Text(_levelReason,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary,
                      height: 1.4)),
            ],
          )),
          if (levelsDiffer) ...[
            const SizedBox(width: 12),
            _smallBadge(
              'AI: ${_levelLabels[_computedLevel]}',
              _levelColors[_computedLevel] ?? AppColors.primary,
            ),
          ],
        ]),

        // Suggest level update
        if (levelsDiffer) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_levelColors[_computedLevel] ?? AppColors.primary)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (_levelColors[_computedLevel] ?? AppColors.primary)
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Row(children: [
              Icon(Icons.auto_awesome_rounded,
                  color: _levelColors[_computedLevel] ?? AppColors.primary,
                  size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Based on your performance, PronounceMate suggests updating your level to '
                  '${_levelLabels[_computedLevel]}.',
                  style: TextStyle(
                      fontSize: 12,
                      color: _levelColors[_computedLevel] ?? AppColors.primary,
                      height: 1.4),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _updateLevel(_computedLevel),
                child: const Text('Apply',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  // ══ Top Errors ═══════════════════════════════════════════
  Widget _buildTopErrors() {
    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.bar_chart_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          const Text('Most Mispronounced Words',
              style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 12),
        ..._topErrors.asMap().entries.map((e) {
          final rank  = e.key + 1;
          final entry = e.value as Map;
          final word  = entry['word']?.toString() ?? '';
          final count = entry['count'] as int? ?? 0;
          final pct   = _sessions > 0
              ? ((count / _sessions) * 100).clamp(0, 100).toStringAsFixed(0)
              : '0';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              // Rank
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: rank == 1
                      ? AppColors.error.withValues(alpha: 0.15)
                      : AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$rank',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: rank == 1
                              ? AppColors.error
                              : AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 10),
              // Word
              Expanded(
                child: Text(word,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              // Count + bar
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$count errors',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 3),
                Container(
                  width: 80,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (int.tryParse(pct) ?? 0) / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ]),
            ]),
          );
        }),
      ],
    ));
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

  Widget _smallBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25))),
    child: Text(text, style: TextStyle(
        fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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

  void _showLevelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Select Proficiency Level',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Your level filters the scripts shown to you',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // Computed level suggestion
          if (_storedLevel != _computedLevel)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'PronounceMate suggests: '
                  '${_levelLabels[_computedLevel]}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.primary),
                )),
              ]),
            ),

          ..._levelOrder.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _updateLevel(l);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _storedLevel == l
                      ? (_levelColors[l] ?? AppColors.primary)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(
                    _levelIcons[l] ?? Icons.bar_chart_rounded,
                    color: _storedLevel == l
                        ? Colors.white
                        : (_levelColors[l] ?? AppColors.primary),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_levelLabels[l] ?? l,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _storedLevel == l
                                ? Colors.white
                                : AppColors.textPrimary)),
                  ),
                  if (_computedLevel == l && _storedLevel != l)
                    _smallBadge('Suggested',
                        _levelColors[l] ?? AppColors.primary),
                  if (_storedLevel == l)
                    const Icon(Icons.check_circle,
                        color: Colors.white, size: 20),
                ]),
              ),
            ),
          )),
        ]),
      ),
    );
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