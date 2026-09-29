import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'active_session_screen.dart';
import 'dashboard_screen.dart';
import 'focus_script_history_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<AppNotification> _notifications = [];

  // Guards against double-taps while a tap is still fetching its target.
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final data = await ApiService.getNotifications();
    if (!mounted) return;

    if (data['error'] != null) {
      setState(() {
        _loading = false;
        _error = data['error'].toString();
      });
      return;
    }

    setState(() {
      _loading = false;
      _notifications = List<Map<String, dynamic>>.from(data['notifications'] ?? [])
          .map((e) => AppNotification.fromJson(e))
          .toList();
    });

    // Mark read once the list has actually loaded and displayed, so
    // opening this screen is what clears the Home bell's badge.
    if (_notifications.any((n) => !n.isRead)) {
      ApiService.markNotificationsRead();
    }
  }

  // ── Swipe to dismiss ─────────────────────────────────────
  // Dismissible needs the item gone from the list in the same frame, so
  // it is removed optimistically; if the server call fails it is put
  // back in its old position with an error message.
  Future<void> _dismiss(AppNotification n) async {
    final index = _notifications.indexWhere((x) => x.id == n.id);
    if (index == -1) return;

    setState(() => _notifications.removeAt(index));

    final res = await ApiService.deleteNotification(n.id);
    if (res['error'] != null && mounted) {
      setState(() {
        final at = index > _notifications.length ? _notifications.length : index;
        _notifications.insert(at, n);
      });
      _showSnack('Could not delete notification');
    }
  }

  // ── Tap → open what the notification is about ────────────
  void _onTap(AppNotification n) {
    switch (n.type) {
      case 'focus_script':
        _openFocusScript(n);
        break;
      case 'level_up':
      case 'streak_milestone':
      case 'longest_streak':
        // The Dashboard shows the level-progression panel and the streak.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _openFocusScript(AppNotification n) async {
    if (_opening) return;
    _opening = true;

    try {
      Map<String, dynamic>? script;

      if (n.relatedId != null) {
        // Notification carries the exact Focus Script it was created for.
        final res = await ApiService.getFocusScriptHistory();
        if (!mounted) return;
        if (res['error'] != null) {
          _showSnack('Could not load the Focus Script');
          return;
        }
        final scripts = List<Map<String, dynamic>>.from(res['scripts'] ?? []);
        for (final s in scripts) {
          if ((s['id'] as num?)?.toInt() == n.relatedId) {
            script = s;
            break;
          }
        }
      } else {
        // Older notifications have no target id — fall back to the
        // current pending Focus Script.
        final res = await ApiService.getLatestFocusScript();
        if (!mounted) return;
        if (res['error'] != null) {
          _showSnack('Could not load the Focus Script');
          return;
        }
        script = res['focus_script'] as Map<String, dynamic>?;
      }

      if (script == null) {
        _showSnack('This Focus Script is no longer available');
        return;
      }

      // Already practiced → there is nothing to start; show the history.
      if (script['completed'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FocusScriptHistoryScreen()),
        );
        return;
      }

      final id = (script['id'] as num?)?.toInt();
      final words = List<String>.from(script['source_words'] ?? []);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveSessionScreen(
            scriptText: script!['script_text']?.toString() ?? '',
            sessionTitle: 'Focus Script',
            focusScriptId: id,
            focusScriptWords: words,
          ),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      duration: const Duration(seconds: 3),
    ));
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'level_up':
        return Icons.trending_up_rounded;
      case 'streak_milestone':
        return Icons.local_fire_department_rounded;
      case 'longest_streak':
        return Icons.emoji_events_rounded;
      case 'focus_script':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'level_up':
        return AppColors.success;
      case 'streak_milestone':
        return AppColors.warning;
      case 'longest_streak':
        return const Color(0xFF7C3AED);
      case 'focus_script':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.background,
        elevation: 0,
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
            Text('Could not load notifications',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Try Again')),
          ],
        ),
      );
    }
    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No notifications yet',
                      style: TextStyle(
                          fontSize: 16, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                    'Level-ups, streaks, and Focus Scripts will show up here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final n = _notifications[i];
          return Dismissible(
            key: ValueKey('notif_${n.id}'),
            direction: DismissDirection.horizontal,
            background: _swipeBackground(Alignment.centerLeft),
            secondaryBackground: _swipeBackground(Alignment.centerRight),
            onDismissed: (_) => _dismiss(n),
            child: _buildCard(n),
          );
        },
      ),
    );
  }

  Widget _swipeBackground(Alignment alignment) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.delete_outline_rounded,
          color: Colors.white, size: 24),
    );
  }

  Widget _buildCard(AppNotification n) {
    final color = _colorFor(n.type);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: n.isRead ? AppColors.divider : color.withValues(alpha: 0.4),
            width: n.isRead ? 1 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: () => _onTap(n),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconFor(n.type), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Text(n.message,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4)),
                      const SizedBox(height: 6),
                      Text(_timeAgo(n.createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                ),
                if (!n.isRead)
                  Container(
                    margin: const EdgeInsets.only(top: 4, left: 6),
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 2, left: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}