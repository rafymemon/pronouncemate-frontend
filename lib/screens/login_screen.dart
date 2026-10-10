import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common_widgets.dart';
import 'forgot_password_screen.dart';
import 'main_shell.dart';
import 'signup_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  /// Optional green banner, e.g. "Email verified! Sign in to continue."
  final String? infoMessage;
  const LoginScreen({super.key, this.infoMessage});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _infoMessage = widget.infoMessage;
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openForgotPassword() {
    final typed = _usernameController.text.trim();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ForgotPasswordScreen(
        initialEmail: typed.contains('@') ? typed : null,
      ),
    ));
  }

  // ── Real API Integration ────────────────────────────────────────
  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final result = await AuthService.instance.signIn(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // The server returns the real username even if the user typed an email.
      final username = (result['username'] ?? _usernameController.text).toString().trim();
      await UserSession.instance.setUsername(username);
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.isNotVerified) {
        // Correct password, but the email was never verified: send a fresh
        // code and open the verification screen.
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            email: e.email ?? '',
            codeJustSent: false,
          ),
        ));
      } else {
        setState(() => _errorMessage = e.message);
      }
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
          Positioned(top: -60, right: -60,
            child: Container(width: 220, height: 220,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentLight.withValues(alpha: 0.4)))),
          Positioned(bottom: -80, left: -60,
            child: Container(width: 260, height: 260,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentLight.withValues(alpha: 0.3)))),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 60),
                        const PronouncemateLogo(size: 68, showTagline: false),
                        const SizedBox(height: 50),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 28, offset: Offset(0, 8))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Row(children: [
                                Expanded(child: Divider(color: AppColors.divider, thickness: 1.2)),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('SIGN IN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary, letterSpacing: 2))),
                                Expanded(child: Divider(color: AppColors.divider, thickness: 1.2)),
                              ]),
                              const SizedBox(height: 28),
                              if (_infoMessage != null) ...[
                                AuthBanner(message: _infoMessage!, isError: false),
                                const SizedBox(height: 16),
                              ],
                              TextFormField(
                                controller: _usernameController,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                validator: (v) => Validators.required(v, 'Enter your username or email'),
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                                decoration: const InputDecoration(hintText: 'Username or email',
                                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.accent)),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                // No length rule on login: existing accounts may have older passwords.
                                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                                decoration: InputDecoration(hintText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.accent),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: AppColors.textHint, size: 20),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword))),
                              ),
                              Align(alignment: Alignment.centerRight,
                                child: TextButton(onPressed: _openForgotPassword,
                                  child: const Text('Forgot Password', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)))),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 8),
                                AuthBanner(message: _errorMessage!),
                              ],
                              const SizedBox(height: 8),
                              SizedBox(width: double.infinity, height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  child: _isLoading
                                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                      : const Text('LOG IN'))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text("Don't have an account? ", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                            child: const Text('Sign Up', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14))),
                        ]),
                        const SizedBox(height: 40),
                      ],
                    ),
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