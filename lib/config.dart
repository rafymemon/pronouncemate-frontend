// lib/config.dart
import 'dart:io';

class AppConfig {
  // ═══════════════════════════════════════════════════════════
  // TEAM CONFIGURATION — Uncomment and set ONE of these
  // ═══════════════════════════════════════════════════════════
  
  // OPTION 1: Shared dev server (BEST for teams)
  // static const String _sharedDevServer = 'https://your-app.onrender.com';
  static const String _sharedDevServer = '';
  
  // OPTION 2: Team lead's local IP
  // static const String _teamLeadIp = 'http://192.168.100.10:8000';
  static const String _teamLeadIp = '';
  
  // OPTION 3: ngrok tunnel
  static const String _ngrokUrl = '';

  // ═══════════════════════════════════════════════════════════
  // AUTO-DETECTION
  // ═══════════════════════════════════════════════════════════
  
  static String get baseUrl {
    // Priority 1: Environment variable
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    
    // Priority 2: Shared dev server
    if (_sharedDevServer.isNotEmpty) return _sharedDevServer;
    
    // Priority 3: Team lead IP
    if (_teamLeadIp.isNotEmpty) return _teamLeadIp;
    
    // Priority 4: ngrok
    if (_ngrokUrl.isNotEmpty) return _ngrokUrl;
    
    // Priority 5: Auto-detect
    return _detectLocalUrl();
  }
  
  static String _detectLocalUrl() {
    if (Platform.isAndroid) {
      return _isEmulator() 
          ? 'http://10.0.2.2:8000'
          : 'http://192.168.100.10:8000';  // ← FIXED: Your actual IP
    }
    if (Platform.isIOS) {
      return 'http://localhost:8000';
    }
    return 'http://localhost:8000';
  }
  
  static bool _isEmulator() {
    try {
      final result = Process.runSync('getprop', ['ro.hardware']);
      final hw = result.stdout.toString().trim().toLowerCase();
      return hw.contains('goldfish') || 
             hw.contains('ranchu') || 
             hw.contains('generic');
    } catch (_) {
      return false;
    }
  }
  
  /// Build full media URL from a path
  static String? mediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }
}