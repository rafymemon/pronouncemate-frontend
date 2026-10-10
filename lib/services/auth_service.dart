// lib/services/auth_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// Every failed auth call throws this. `toString()` returns the message, so
/// `e.toString()` still works anywhere it was used before.
class AuthException implements Exception {
  final String message;
  final String? code;     // e.g. 'email_not_verified'
  final String? email;    // set with 'email_not_verified'
  final int? statusCode;
  final Map<String, dynamic> fieldErrors;

  const AuthException(
    this.message, {
    this.code,
    this.email,
    this.statusCode,
    this.fieldErrors = const {},
  });

  bool get isNotVerified => code == 'email_not_verified';

  @override
  String toString() => message;
}

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  static const Duration _timeout = Duration(seconds: 20);

  static const AuthException _sessionEnded = AuthException(
    'Your session has expired. Please sign in again.',
    statusCode: 401,
  );

  /// Flips to true when the server rejects our token (HTTP 401) so the app
  /// root can send the user back to the login screen.
  final ValueNotifier<bool> sessionExpired = ValueNotifier<bool>(false);

  String get baseUrl => '${AppConfig.baseUrl}/api';

  // ── Session storage ──────────────────────────────────────────────────────
  Future<void> _saveSession({
    required String token,
    required String username,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_username', username);
    await prefs.setString('auth_email', email);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_email', email);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_username');
    await prefs.remove('auth_email');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return (token != null && token.isNotEmpty) ? token : null;
  }

  Future<bool> hasActiveSession() async => (await getToken()) != null;

  /// Headers for authenticated API calls.
  Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  /// Call this whenever any API answers 401: clears the stored session and
  /// notifies listeners so the UI can return to the login screen.
  Future<void> handleUnauthorized() async {
    await _clearSession();
    sessionExpired.value = true;
  }

  // ── Shared POST helpers ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$baseUrl/$path'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Token $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AuthException(
          'The server took too long to respond. Please try again.');
    } catch (_) {
      throw const AuthException(
          'Cannot connect to server. Check your internet connection.');
    }

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // Non-JSON body (e.g. an HTML error page) — handled below.
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    if (res.statusCode == 429) {
      throw const AuthException(
        'Too many attempts. Please wait a minute and try again.',
        statusCode: 429,
      );
    }

    final message = (data['error'] ??
            data['detail'] ??
            'Something went wrong (error ${res.statusCode}). Please try again.')
        .toString();
    final errs = data['errors'] is Map
        ? Map<String, dynamic>.from(data['errors'] as Map)
        : <String, dynamic>{};

    throw AuthException(
      message,
      code: data['code']?.toString(),
      email: data['email']?.toString(),
      statusCode: res.statusCode,
      fieldErrors: errs,
    );
  }

  /// POST for signed-in endpoints: attaches the token and, if the server
  /// rejects it (401), ends the session and throws a "session expired" error.
  Future<Map<String, dynamic>> _authedPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await getToken();
    if (token == null) {
      await handleUnauthorized();
      throw _sessionEnded;
    }
    try {
      return await _post(path, body, token: token);
    } on AuthException catch (e) {
      if (e.statusCode == 401) {
        await handleUnauthorized();
        throw _sessionEnded;
      }
      rethrow;
    }
  }

  // ── Sign in ──────────────────────────────────────────────────────────────
  /// `username` may also be the account's email address.
  Future<Map<String, dynamic>> signIn({
    required String username,
    required String password,
  }) async {
    final data = await _post('login/', {
      'username': username.trim(),
      'password': password,
    });

    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const AuthException('Login failed. Please try again.');
    }

    await _saveSession(
      token: token,
      username: (data['username'] ?? username).toString().trim(),
      email: (data['email'] ?? '').toString(),
    );
    sessionExpired.value = false;
    return data;
  }

  // ── Sign up (account stays inactive until the email code is verified) ────
  Future<Map<String, dynamic>> signUp({
    required String username,
    required String email,
    required String password,
  }) {
    return _post('register/', {
      'username': username.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }

  Future<void> verifyEmail({required String email, required String otp}) async {
    await _post('verify-email/', {
      'email': email.trim().toLowerCase(),
      'otp': otp.trim(),
    });
  }

  Future<void> resendVerification(String email) async {
    await _post('resend-verification/', {
      'email': email.trim().toLowerCase(),
    });
  }

  // ── Forgot / reset password ──────────────────────────────────────────────
  /// Always succeeds for a well-formed email (the server never reveals
  /// whether the account exists).
  Future<void> forgotPassword(String email) async {
    await _post('forgot-password/', {
      'email': email.trim().toLowerCase(),
    });
  }

  /// Kept so older callers still compile.
  Future<void> sendPasswordReset(String email) => forgotPassword(email);

  /// Returns the short-lived reset token needed by [resetPassword].
  Future<String> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    final data = await _post('verify-reset-otp/', {
      'email': email.trim().toLowerCase(),
      'otp': otp.trim(),
    });
    final token = data['reset_token']?.toString();
    if (token == null || token.isEmpty) {
      throw const AuthException('Could not verify the code. Please try again.');
    }
    return token;
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    await _post('reset-password/', {
      'email': email.trim().toLowerCase(),
      'reset_token': resetToken,
      'new_password': newPassword,
    });
  }

  // ── Change password (signed-in user) ─────────────────────────────────────
  /// A wrong current password arrives as a normal 400 error; only a rejected
  /// token (401) ends the session. On success the server revokes every other
  /// device's token and returns a fresh one for this device, stored here.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final data = await _authedPost('change-password/', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    final fresh = data['token']?.toString();
    if (fresh != null && fresh.isNotEmpty) await _saveToken(fresh);
  }

  // ── Change email (signed-in user, verified with a code) ──────────────────
  /// Sends a 6-digit code to [newEmail]. The email is NOT changed yet.
  Future<Map<String, dynamic>> requestEmailChange({
    required String newEmail,
    required String password,
  }) {
    return _authedPost('email-change/request/', {
      'new_email': newEmail.trim().toLowerCase(),
      'password': password,
    });
  }

  /// Confirms the code; returns the account's new email address.
  Future<String> confirmEmailChange({
    required String newEmail,
    required String otp,
  }) async {
    final data = await _authedPost('email-change/confirm/', {
      'new_email': newEmail.trim().toLowerCase(),
      'otp': otp.trim(),
    });
    final email = (data['email'] ?? newEmail).toString();
    await _saveEmail(email);
    return email;
  }

  // ── Sign out ─────────────────────────────────────────────────────────────
  /// Invalidates the token on the server (best effort), then clears local data.
  Future<void> signOut() async {
    final token = await getToken();
    if (token != null) {
      try {
        await http
            .post(
              Uri.parse('$baseUrl/logout/'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Token $token',
              },
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Offline or server down: still sign out locally.
      }
    }
    await _clearSession();
  }
}