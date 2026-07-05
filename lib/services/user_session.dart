import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class UserSession extends ChangeNotifier {
  static final UserSession instance = UserSession._internal();
  UserSession._internal();

  String proficiencyLevel = 'Beginner';
  String _username = '';

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('auth_username') ?? '';
    proficiencyLevel = prefs.getString('proficiency_level') ?? proficiencyLevel;
    notifyListeners();
  }

  Future<void> setUsername(String username) async {
    _username = username.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_username', _username);
    notifyListeners();
  }

  Future<void> setProficiencyLevel(String value) async {
    proficiencyLevel = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('proficiency_level', value);
    notifyListeners();
  }

  /// The saved username, with a sensible fallback.
  String get name => _username.isNotEmpty ? _username : 'User';

  /// No email is stored because the backend authenticates by username.
  String get email => '';

  /// Returns uppercase initials (up to 2 characters) derived from the name.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isNotEmpty) return name[0].toUpperCase();
    return 'U';
  }

  /// Returns only the first word of the name, or 'there' as a fallback.
  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return (parts.isNotEmpty && parts[0].isNotEmpty) ? parts[0] : 'there';
  }

  /// Signs the user out and clears local state.
  Future<void> signOut() async {
    _username = '';
    await AuthService.instance.signOut();
    notifyListeners();
  }

  // ── Private helpers ──────────────────────────────────────────────────────

}
