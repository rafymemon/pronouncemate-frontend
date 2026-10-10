// lib/widgets/auth_widgets.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'common_widgets.dart';

// ─── Error / info banner ───────────────────────────────────────
class AuthBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const AuthBanner({super.key, required this.message, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final base = isError ? Colors.red : Colors.green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: base.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: base.shade200),
      ),
      child: Row(children: [
        Icon(
          isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          size: 18,
          color: base.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 13, color: base.shade700),
          ),
        ),
      ]),
    );
  }
}

// ─── 6-digit code input ────────────────────────────────────────
class OtpCodeField extends StatelessWidget {
  final TextEditingController controller;
  const OtpCodeField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      validator: Validators.otp,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 26,
        fontWeight: FontWeight.bold,
        letterSpacing: 12,
      ),
      decoration: const InputDecoration(
        hintText: '000000',
        counterText: '',
      ),
    );
  }
}

// ─── "Resend code" with countdown ──────────────────────────────
class ResendCodeButton extends StatefulWidget {
  /// Returns true when a new code was requested successfully (restarts the
  /// countdown). The caller shows its own success / error messages.
  final Future<bool> Function() onResend;
  final int cooldownSeconds;
  const ResendCodeButton({
    super.key,
    required this.onResend,
    this.cooldownSeconds = 60,
  });

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  late int _seconds;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _seconds = widget.cooldownSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _seconds--;
        if (_seconds <= 0) t.cancel();
      });
    });
  }

  Future<void> _tap() async {
    setState(() => _busy = true);
    try {
      final ok = await widget.onResend();
      if (ok && mounted) {
        setState(() => _seconds = widget.cooldownSeconds);
        _startTimer();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_seconds > 0) {
      return Text(
        'Resend code in ${_seconds}s',
        style: const TextStyle(fontSize: 13, color: AppColors.textHint),
      );
    }
    return TextButton(
      onPressed: _busy ? null : _tap,
      child: Text(
        _busy ? 'Sending...' : 'Resend code',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ─── Shared page layout for the verify / forgot-password screens ──
class AuthScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? footer;
  final bool showBack;
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentLight.withValues(alpha: 0.35),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentLight.withValues(alpha: 0.3),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Row(children: [
                    if (showBack)
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: AppColors.cardShadow, blurRadius: 8),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                    const Spacer(),
                    const PronouncemateLogo(size: 36, showTagline: false),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ]),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Expanded(
                            child: Divider(color: AppColors.divider, thickness: 1.2),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: AppColors.divider, thickness: 1.2),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        child,
                      ],
                    ),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: 24),
                    footer!,
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}