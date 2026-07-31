import 'dart:io';

class AppConfig {
  // ═══════════════════════════════════════════════════════════
  // TEAM CONFIGURATION
  // ═══════════════════════════════════════════════════════════
  
  static const String _sharedDevServer = '';
  
  // 👇 FIXED: Set to localhost for ADB USB Tunneling on your Samsung
  static const String _physicalDeviceIp = 'http://127.0.0.1:8000';
  
  static const String _ngrokUrl = '';

  // ═══════════════════════════════════════════════════════════
  // AUTO-DETECTION
  // ═══════════════════════════════════════════════════════════
  
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    
    if (_sharedDevServer.isNotEmpty) return _sharedDevServer;
    
    // This will now successfully force 127.0.0.1
    if (_physicalDeviceIp.isNotEmpty) return _physicalDeviceIp;
    
    if (_ngrokUrl.isNotEmpty) return _ngrokUrl;
    
    return _detectLocalUrl();
  }
  
  static String _detectLocalUrl() {
    if (Platform.isAndroid) return 'http://10.0.2.2:8000'; 
    if (Platform.isIOS) return 'http://127.0.0.1:8000';
    return 'http://127.0.0.1:8000';
  }
  
  static String? mediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final mediaPath = path.startsWith('/') ? path : '/$path';
    return '$base$mediaPath';
  }
}