import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';

// --- Services ---
import 'services/auth_service.dart';
import 'services/user_session.dart';

// --- Theme ---
import 'theme/app_theme.dart';

// --- Screens ---
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
// Note: Make sure these files exist in your screens folder
import 'screens/home_screen.dart'; 
import 'screens/script_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await UserSession.instance.loadFromStorage();
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, 
    DeviceOrientation.portraitDown
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  
  runApp(const PronounceMateApp());
}

class PronounceMateApp extends StatelessWidget {
  const PronounceMateApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PronounceMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // The entry point handles auth state routing
      home: const _AppEntry(),
      // Registered named routes
      routes: {
        '/home':     (ctx) => const HomeScreen(),
        '/scripts':  (ctx) => const ScriptSelectionScreen(),
        '/practice': (ctx) => const ScriptSelectionScreen(),
      },
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _showWelcome = true;
  bool _isCheckingSession = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkStartupSession();
  }

  Future<void> _checkStartupSession() async {
    final hasSession = await AuthService.instance.hasActiveSession();
    if (!mounted) return;
    
    setState(() {
      _isAuthenticated = hasSession;
      _isCheckingSession = false;
      if (hasSession) {
        _showWelcome = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isAuthenticated) {
      return const MainShell();
    }

    if (_showWelcome) {
      return WelcomeScreen(
        onContinue: () => setState(() => _showWelcome = false),
      );
    }
    
    return const LoginScreen();
  }
}