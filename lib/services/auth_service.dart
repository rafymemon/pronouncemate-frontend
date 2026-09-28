// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart'; // ← ADDED: Import the AppConfig for dynamic base URL

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  // ── Dynamic Base URL ─────────────────────────────────────────────────────
  // Automatically pulls from our centralized AppConfig tunnel
  String get baseUrl {
    return '${AppConfig.baseUrl}/api';
  }
  
  // ── Session Management ───────────────────────────────────────────────────
  Future<void> _saveSession({required String token, required String username}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_username', username);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_username');
  }

  Future<bool> hasActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  }

  // ── Django Login ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> signIn({required String username, required String password}) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/login/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data.containsKey('token')) {
        await _saveSession(token: data['token'].toString(), username: username.trim());
        return data; 
      } else {
        return {'error': data['error'] ?? 'Invalid username or password'};
      }
    } catch (e) {
      throw 'Cannot connect to server. Is Django running?';
    }
  }

  // ── Django Sign Up ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/register/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'email': email.trim(),
          'password': password,
        }),
      );

      final dynamic data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final token = data is Map<String, dynamic> ? data['token'] : null;
        if (token != null) {
          await _saveSession(token: token.toString(), username: username.trim());
        }
        return data is Map<String, dynamic> ? data : {'message': 'Registration successful'};
      } else {
        final error = data is Map<String, dynamic>
            ? data['error'] ?? data['detail'] ?? 'Registration failed. Username or email may already be in use.'
            : 'Registration failed. Username or email may already be in use.';
        return {'error': error.toString()};
      }
    } catch (e) {
      throw 'Cannot connect to server.';
    }
  }

  // ── Placeholders ─────────────────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    // Will link up to Django's user password management views down the line.
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> signOut() async {
    await _clearSession();
  }

} // ← ADDED: Proper closing bracket for the AuthService class