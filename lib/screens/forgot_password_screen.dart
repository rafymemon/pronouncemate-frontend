import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';

enum _Step { email, code, password }

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.email;
  bool _isLoading = false;
  String? _error;
  String? _info;
  String _resetToken = '';

  String get _email => Validators.normalizeEmail(_emailController.text);

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startOver() {
    setState(() {
      _step = _Step.email;
      _error = null;
      _info = null;
      _resetToken = '';
      _codeController.clear();
      _newPasswordController.clear();
      _confirmController.clear();
    });
  }

  // ── Step 1: request a code ──────────────────────────────────────
  Future<bool> _requestCode() async {
    try {
      await AuthService.instance.forgotPassword(_email);
      return true;
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return false;
    }
  }

  void _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final ok = await _requestCode();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _step = _Step.code;
        _codeController.clear();
        _info = 'If an account exists for $_email, we sent a 6-digit code. '
            'It expires in 10 minutes.';
      }
    });
  }

  Future<bool> _resendCode() async {
    final ok = await _requestCode();
    if (ok && mounted) {
      setState(() {
        _error = null;
        _info = 'A new code was sent if an account exists for $_email.';
      });
    }
    return ok;
  }

  // ── Step 2: verify the code ─────────────────────────────────────
  void _submitCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await AuthService.instance.verifyResetOtp(
        email: _email,
        otp: _codeController.text,
      );
      if (!mounted) return;
      setState(() {
        _resetToken = token;
        _step = _Step.password;
        _info = 'Code verified. Choose a new password.';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _info = null;
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Step 3: set the new password ────────────────────────────────
  void _submitPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.instance.resetPassword(
        email: _email,
        resetToken: _resetToken,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(
            infoMessage: 'Password updated. Sign in with your new password.',
          ),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _info = null;
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────
  String get _title {
    switch (_step) {
      case _Step.email:
        return 'FORGOT PASSWORD';
      case _Step.code:
        return 'ENTER CODE';
      case _Step.password:
        return 'NEW PASSWORD';
    }
  }

  Widget _stepBody() {
    switch (_step) {
      case _Step.email:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter the email you registered with and we'll send you a 6-digit code.",
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),
            AppTextField(
              label: 'Email Address',
              hint: 'you@example.com',
              prefixIcon: Icons.email_outlined,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            ..._messages(),
            PrimaryButton(
              label: 'SEND CODE',
              onPressed: _submitEmail,
              isLoading: _isLoading,
            ),
          ],
        );

      case _Step.code:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the 6-digit code sent to\n$_email',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),
            OtpCodeField(controller: _codeController),
            const SizedBox(height: 12),
            ..._messages(),
            PrimaryButton(
              label: 'VERIFY CODE',
              onPressed: _submitCode,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 8),
            Center(child: ResendCodeButton(onResend: _resendCode)),
            Center(
              child: TextButton(
                onPressed: _startOver,
                child: const Text('Use a different email',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
            ),
          ],
        );

      case _Step.password:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'New Password',
              hint: 'Min. 8 characters',
              prefixIcon: Icons.lock_outline,
              isPassword: true,
              controller: _newPasswordController,
              validator: Validators.newPassword,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Confirm New Password',
              hint: 'Re-enter your password',
              prefixIcon: Icons.lock_outline,
              isPassword: true,
              controller: _confirmController,
              validator: (v) =>
                  Validators.confirm(v, _newPasswordController.text),
            ),
            const SizedBox(height: 16),
            ..._messages(),
            PrimaryButton(
              label: 'UPDATE PASSWORD',
              onPressed: _submitPassword,
              isLoading: _isLoading,
            ),
            Center(
              child: TextButton(
                onPressed: _startOver,
                child: const Text('Start over',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
            ),
          ],
        );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _title,
      footer: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Remembered it? ',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        GestureDetector(
          onTap: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          ),
          child: const Text('Sign In',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ),
      ]),
      child: Form(key: _formKey, child: _stepBody()),
    );
  }
}