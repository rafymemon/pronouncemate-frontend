import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common_widgets.dart';
import 'verify_email_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final email = Validators.normalizeEmail(_emailController.text);
      final result = await AuthService.instance.signUp(
        username: _usernameController.text.trim(),
        email: email,
        password: _passwordController.text,
      );
      if (!mounted) return;

      // The account is created but inactive: the user must enter the
      // 6-digit code we just emailed before they can sign in.
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => VerifyEmailScreen(
          email: email,
          codeJustSent: result['email_sent'] == true,
        ),
      ));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(top: -40, right: -40,
            child: Container(width: 180, height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentLight.withValues(alpha: 0.35)))),
          Positioned(bottom: -60, left: -40,
            child: Container(width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentLight.withValues(alpha: 0.3)))),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Back + Logo
                      Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12),
                              boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 8)]),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary))),
                        const Spacer(),
                        const PronouncemateLogo(size: 36, showTagline: false),
                        const Spacer(), const SizedBox(width: 40),
                      ]),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 24, offset: Offset(0, 8))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Expanded(child: Divider(color: AppColors.divider, thickness: 1.2)),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('CREATE ACCOUNT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary, letterSpacing: 1.5))),
                              Expanded(child: Divider(color: AppColors.divider, thickness: 1.2)),
                            ]),
                            const SizedBox(height: 24),
                            AppTextField(label: 'Username', hint: 'e.g. ahmed_khan',
                              prefixIcon: Icons.person_outline, controller: _usernameController,
                              validator: Validators.username),
                            const SizedBox(height: 14),
                            AppTextField(label: 'Email Address', hint: 'you@example.com',
                              prefixIcon: Icons.email_outlined, controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email),
                            const SizedBox(height: 14),
                            AppTextField(label: 'Password', hint: 'Min. 8 characters',
                              prefixIcon: Icons.lock_outline, isPassword: true, controller: _passwordController,
                              validator: (v) => Validators.newPassword(v, username: _usernameController.text)),
                            const SizedBox(height: 14),
                            AppTextField(label: 'Confirm Password', hint: 'Re-enter your password',
                              prefixIcon: Icons.lock_outline, isPassword: true, controller: _confirmController,
                              validator: (v) => Validators.confirm(v, _passwordController.text)),

                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.accent),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "We'll email you a 6-digit code to verify your address. You can set your proficiency level anytime from your Profile.",
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_errorMessage != null) ...[
                              AuthBanner(message: _errorMessage!),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(width: double.infinity, height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signup,
                                child: _isLoading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : const Text('GET STARTED'))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text("Already have an account? ", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Text('Sign In', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14))),
                      ]),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}