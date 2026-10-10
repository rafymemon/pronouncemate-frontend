// lib/widgets/change_email_sheet.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'auth_widgets.dart';
import 'common_widgets.dart';

/// Two-step "change email" bottom sheet:
///   1. new email + current password  ->  a 6-digit code is emailed to the NEW address
///   2. enter the code                ->  the account email is updated
class ChangeEmailSheet {
  /// Resolves to the new email address when it was changed, otherwise null.
  static Future<String?> show(BuildContext context, {required String currentEmail}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangeEmailBody(currentEmail: currentEmail),
    );
  }
}

enum _Step { details, code }

class _ChangeEmailBody extends StatefulWidget {
  final String currentEmail;
  const _ChangeEmailBody({required this.currentEmail});

  @override
  State<_ChangeEmailBody> createState() => _ChangeEmailBodyState();
}

class _ChangeEmailBodyState extends State<_ChangeEmailBody> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  _Step _step = _Step.details;
  bool _busy = false;
  String? _error;
  String? _info;

  String get _newEmail => Validators.normalizeEmail(_emailCtrl.text);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// A rejected session closes the sheet; the app root shows the login screen.
  bool _handleSessionEnded(AuthException e) {
    if (e.statusCode == 401) {
      if (mounted) Navigator.of(context).pop();
      return true;
    }
    return false;
  }

  // ── Step 1: send the code ────────────────────────────────────
  Future<bool> _sendCode() async {
    try {
      await AuthService.instance.requestEmailChange(
        newEmail: _newEmail,
        password: _passwordCtrl.text,
      );
      return true;
    } on AuthException catch (e) {
      if (_handleSessionEnded(e)) return false;
      if (mounted) setState(() => _error = e.message);
      return false;
    }
  }

  Future<void> _submitDetails() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await _sendCode();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _step = _Step.code;
        _codeCtrl.clear();
        _info = 'We sent a 6-digit code to $_newEmail. It expires in 10 minutes.';
      }
    });
  }

  Future<bool> _resend() async {
    final ok = await _sendCode();
    if (ok && mounted) {
      setState(() {
        _error = null;
        _info = 'A new code was sent to $_newEmail.';
      });
    }
    return ok;
  }

  // ── Step 2: confirm the code ─────────────────────────────────
  Future<void> _submitCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await AuthService.instance.confirmEmailChange(
        newEmail: _newEmail,
        otp: _codeCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on AuthException catch (e) {
      if (_handleSessionEnded(e)) return;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _info = null;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  void _useDifferentEmail() {
    setState(() {
      _step = _Step.details;
      _error = null;
      _info = null;
      _codeCtrl.clear();
    });
  }

  // ── UI ───────────────────────────────────────────────────────
  List<Widget> _messages() => [
        if (_info != null) ...[
          AuthBanner(message: _info!, isError: false),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          AuthBanner(message: _error!),
          const SizedBox(height: 12),
        ],
      ];

  Widget _detailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.currentEmail.isNotEmpty) ...[
          Text(
            'Current email: ${widget.currentEmail}',
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
        ],
        const Text(
          "We'll send a 6-digit code to the new address to confirm it's yours.",
          style: TextStyle(
              fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: 'New Email Address',
          hint: 'you@example.com',
          prefixIcon: Icons.email_outlined,
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final base = Validators.email(v);
            if (base != null) return base;
            if (Validators.normalizeEmail(v!) ==
                widget.currentEmail.trim().toLowerCase()) {
              return 'This is already your email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Current Password',
          hint: 'Confirm it\'s you',
          prefixIcon: Icons.lock_outline,
          isPassword: true,
          controller: _passwordCtrl,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Enter your current password' : null,
        ),
        const SizedBox(height: 16),
        ..._messages(),
        PrimaryButton(
          label: 'Send Code',
          isLoading: _busy,
          onPressed: _submitDetails,
        ),
      ],
    );
  }

  Widget _codeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter the 6-digit code sent to\n$_newEmail',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        OtpCodeField(controller: _codeCtrl),
        const SizedBox(height: 12),
        ..._messages(),
        PrimaryButton(
          label: 'Verify & Update',
          isLoading: _busy,
          onPressed: _submitCode,
        ),
        const SizedBox(height: 8),
        Center(child: ResendCodeButton(onResend: _resend)),
        Center(
          child: TextButton(
            onPressed: _useDifferentEmail,
            child: const Text('Use a different email',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
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
                Text(
                  _step == _Step.details ? 'Change Email' : 'Verify New Email',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _step == _Step.details ? _detailsStep() : _codeStep(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}