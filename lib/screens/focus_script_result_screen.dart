// lib/screens/focus_script_result_screen.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FocusScriptResultScreen extends StatelessWidget {
  /// The `result` map returned by the backend when the Focus Script
  /// was completed.
  final Map<String, dynamic> result;
  final String sessionTitle;

  /// Builds the normal Session Summary screen for this practice run.
  final WidgetBuilder summaryBuilder;

  const FocusScriptResultScreen({
    super.key,
    required this.result,
    required this.summaryBuilder,
    this.sessionTitle = 'Focus Script',
  });

  int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
  double _dbl(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  static const _amber = Color(0xFFB35900);
  static const _darkRed = Color(0xFF991B1B);

  Color get _verdictColor {
    switch (result['verdict']) {
      case 'excellent':
      case 'good':
        return AppColors.success;
      case 'some':
        return _amber;
      default:
        return AppColors.error;
    }
  }

  IconData get _verdictIcon {
    switch (result['verdict']) {
      case 'excellent':
        return Icons.emoji_events_rounded;
      case 'good':
        return Icons.trending_up_rounded;
      case 'some':
        return Icons.show_chart_rounded;
      default:
        return Icons.replay_rounded;
    }
  }

  String _typeLabel(String? t) {
    switch (t) {
      case 'substitution':
        return 'Wrong sound';
      case 'omission':
        return 'Missing sound';
      case 'insertion':
        return 'Extra sound';
      case 'skipped':
        return 'Skipped';
      case 'minor':
        return 'Small slip';
      case 'correct':
        return 'Correct';
      case 'accent':
        return 'Accent variant (accepted)';
      case null:
      case 'unknown':
        return 'Error';
      default:
        return t[0].toUpperCase() + t.substring(1);
    }
  }

  ({String label, Color color, IconData icon}) _statusMeta(String s) {
    switch (s) {
      case 'corrected':
        return (
          label: 'Corrected',
          color: AppColors.success,
          icon: Icons.check_circle_rounded
        );
      case 'improved':
        return (
          label: 'Improved',
          color: _amber,
          icon: Icons.trending_up_rounded
        );
      case 'worse':
        return (
          label: 'Got worse',
          color: _darkRed,
          icon: Icons.trending_down_rounded
        );
      case 'not_practiced':
        return (
          label: 'Not detected',
          color: Colors.grey,
          icon: Icons.help_outline_rounded
        );
      default:
        return (
          label: 'Needs work',
          color: AppColors.error,
          icon: Icons.cancel_rounded
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = ((result['words'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final retention = ((result['retention'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final total = _int(result['total_words']);
    final corrected = _int(result['corrected']);
    final improved = _int(result['improved']);
    final unchanged = _int(result['unchanged']);
    final worse = _int(result['worse']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Focus Script Results',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _verdictCard(total, corrected + improved),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _statTile('$corrected', 'Corrected',
                      AppColors.success)),
              const SizedBox(width: 8),
              Expanded(child: _statTile('$improved', 'Improved', _amber)),
              const SizedBox(width: 8),
              Expanded(
                  child: _statTile(
                      '$unchanged', 'Needs work', AppColors.error)),
              const SizedBox(width: 8),
              Expanded(child: _statTile('$worse', 'Worse', _darkRed)),
            ]),
            const SizedBox(height: 16),
            _errorRateCard(),
            const SizedBox(height: 20),
            const Text('Word by word',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('What each word was before, and what it is now.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ...words.map(_wordRow),
            if (retention.isNotEmpty) ...[
              const SizedBox(height: 12),
              _retentionCard(retention),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: summaryBuilder)),
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('View full session summary'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (_) => false),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Back to Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Verdict ───────────────────────────────────────────────
  Widget _verdictCard(int total, int progressed) {
    final color = _verdictColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(_verdictIcon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$progressed / $total',
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  Text('error words improved',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ),
            Column(
              children: [
                Text('${_dbl(result['session_score']).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text('session score',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ]),
          const SizedBox(height: 14),
          Text(result['headline']?.toString() ?? '',
              style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Error rate before vs after ─────────────────────────────
  Widget _errorRateCard() {
    final pre = _dbl(result['pre_error_rate']);
    final postRaw = result['post_error_rate'];
    final post = postRaw == null ? null : _dbl(postRaw);
    final points = result['improvement_points'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Error rate on these words',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          _rateBar('Before', pre, AppColors.error),
          const SizedBox(height: 10),
          if (post != null)
            _rateBar('After', post,
                post <= pre ? AppColors.success : AppColors.error)
          else
            const Text('After: not measured',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          if (points != null) ...[
            const SizedBox(height: 12),
            Text(
              _dbl(points) >= 0
                  ? 'Down by ${_dbl(points).toStringAsFixed(0)} points'
                  : 'Up by ${(-_dbl(points)).toStringAsFixed(0)} points',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _dbl(points) >= 0
                      ? AppColors.success
                      : AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rateBar(String label, double value, Color color) {
    return Row(children: [
      SizedBox(
        width: 48,
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(children: [
            Container(height: 10, color: const Color(0xFFF1F5F9)),
            FractionallySizedBox(
              widthFactor: (value / 100).clamp(0.0, 1.0),
              child: Container(height: 10, color: color),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 40,
        child: Text('${value.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }

  // ── One word ──────────────────────────────────────────────
  Widget _wordRow(Map<String, dynamic> w) {
    final status = w['status']?.toString() ?? 'unchanged';
    final meta = _statusMeta(status);
    final beforeCount = _int(w['before_count']);
    final afterScore = w['after_score'];
    final tip = w['tip']?.toString();
    final mastered = w['mastered'] == true;
    final streak = _int(w['mastery_streak']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: meta.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(w['word']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(meta.icon, size: 14, color: meta.color),
                const SizedBox(width: 4),
                Text(meta.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: meta.color)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _beforeAfter(
                'Before',
                _typeLabel(w['before_type']?.toString()) +
                    (beforeCount > 0 ? ' · missed ${beforeCount}×' : ''),
                AppColors.error,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 16, color: AppColors.textHint),
            ),
            Expanded(
              child: _beforeAfter(
                'After',
                status == 'not_practiced'
                    ? 'Not detected'
                    : _typeLabel(w['after_type']?.toString()) +
                        (afterScore != null
                            ? ' · ${_dbl(afterScore).toStringAsFixed(0)}%'
                            : ''),
                meta.color,
              ),
            ),
          ]),
          if (mastered || streak > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(
                  mastered
                      ? Icons.verified_rounded
                      : Icons.trending_up_rounded,
                  size: 13,
                  color: AppColors.success),
              const SizedBox(width: 4),
              Text(mastered ? 'Mastered' : '$streak/3 to mastery',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success)),
            ]),
          ],
          if (status != 'corrected' && tip != null && tip.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(tip,
                style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _beforeAfter(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textHint,
                letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  // ── Retention check ───────────────────────────────────────
  Widget _retentionCard(List<Map<String, dynamic>> retention) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Retention check',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7C3AED))),
          const SizedBox(height: 4),
          const Text('Words you had mastered earlier, tested again.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: retention.map((r) {
              final ok = r['retained'] == true;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 14,
                      color: ok ? AppColors.success : AppColors.error),
                  const SizedBox(width: 4),
                  Text(r['word']?.toString() ?? '',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ok ? AppColors.success : AppColors.error)),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}