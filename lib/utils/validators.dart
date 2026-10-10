// lib/utils/validators.dart

class Validators {
  Validators._();

  // Letters, digits and the usual special characters before the @; a real
  // domain with at least one dot; a TLD of 2+ letters at the end.
  static final RegExp _emailRe = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.[A-Za-z]{2,}$",
  );

  static final RegExp _usernameRe = RegExp(r'^[A-Za-z0-9_.]{3,30}$');

  /// Normalizes an email the same way the backend does.
  static String normalizeEmail(String v) => v.trim().toLowerCase();

  static String? required(String? v, String message) =>
      (v == null || v.trim().isEmpty) ? message : null;

  static String? email(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Please enter your email address';
    if (value.length > 254) return 'Email address is too long';
    if (value.contains('..')) return 'Enter a valid email address';
    final local = value.split('@').first;
    if (local.startsWith('.') || local.endsWith('.')) {
      return 'Enter a valid email address';
    }
    if (!_emailRe.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  static String? username(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Please enter a username';
    if (!_usernameRe.hasMatch(value)) {
      return '3-30 characters: letters, numbers, _ or .';
    }
    return null;
  }

  /// Mirrors the backend rules that can be checked offline. The server still
  /// has the last word (common-password list etc.) and its message is shown.
  static String? newPassword(String? v, {String? username}) {
    final value = v ?? '';
    if (value.isEmpty) return 'Please enter a password';
    if (value.length < 8) return 'At least 8 characters required';
    if (RegExp(r'^\d+$').hasMatch(value)) {
      return 'Password cannot be only numbers';
    }
    final u = (username ?? '').trim().toLowerCase();
    if (u.length >= 3 && value.toLowerCase().contains(u)) {
      return 'Password is too similar to your username';
    }
    return null;
  }

  static String? confirm(String? v, String original) =>
      v != original ? 'Passwords do not match' : null;

  static String? otp(String? v) {
    final value = (v ?? '').trim();
    return value.length == 6 ? null : 'Enter the 6-digit code';
  }
}