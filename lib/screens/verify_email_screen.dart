import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  /// false when arriving from the login screen (no fresh code is known to
  /// exist), in which case a new code is requested automatically.
  final bool codeJustSent;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.codeJustSent = true,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    if (widget.codeJustSent) {
      _info = 'We sent a 6-digit code to ${widget.email}. It expires in 10 minutes.';
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resend());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<bool> _resend() async {
    try {
      await AuthService.instance.resendVerification(widget.email);
      if (!mounted) return false;
      setState(() {
        _error = null;
        _info = 'A new code has been sent to ${widget.email}.';
      });
      return true;
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _info = null;
          _error = e.message;
        });
      }
      return false;
    }
  }

  void _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.instance.verifyEmail(
        email: widget.email,
        otp: _codeController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(
            infoMessage: 'Email verified! Sign in to continue.',
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'VERIFY EMAIL',
      footer: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Already verified? ',
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    size: 32, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Enter the 6-digit code sent to\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            OtpCodeField(controller: _codeController),
            const SizedBox(height: 12),
            if (_info != null) ...[
              AuthBanner(message: _info!, isError: false),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              AuthBanner(message: _error!),
              const SizedBox(height: 12),
            ],
            PrimaryButton(
              label: 'VERIFY',
              onPressed: _verify,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 8),
            Center(child: ResendCodeButton(onResend: _resend)),
          ],
        ),
      ),
    );
  }
}