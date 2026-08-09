import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/biometric_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure Transparent Dark System Status Bar & Navigation Bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Render App UI instantly (0.1s startup)
  runApp(const ExpenseOSApp());

  // Initialize Supabase Client asynchronously in background
  SupabaseService.initialize().catchError((e) {
    debugPrint('Supabase background initialization error: $e');
  });
}

class ExpenseOSApp extends StatefulWidget {
  const ExpenseOSApp({super.key});

  @override
  State<ExpenseOSApp> createState() => _ExpenseOSAppState();
}

class _ExpenseOSAppState extends State<ExpenseOSApp> {
  final SupabaseService _supabaseService = SupabaseService();
  final BiometricService _biometricService = BiometricService();
  
  bool _isGuestOrLoggedIn = false;
  bool _isAppLocked = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAppLockAndAuth();
    if (_supabaseService.safeClient != null) {
      _authSubscription = _supabaseService.safeClient!.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        if (event == AuthChangeEvent.signedIn) {
          setState(() {
            _isGuestOrLoggedIn = true;
          });
        } else if (event == AuthChangeEvent.signedOut) {
          setState(() {
            _isGuestOrLoggedIn = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAppLockAndAuth() async {
    final lockEnabled = await _biometricService.isAppLockEnabled();
    final authed = _supabaseService.isAuthenticated;
    if (mounted) {
      setState(() {
        _isGuestOrLoggedIn = authed;
        _isAppLocked = lockEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget initialScreen;
    if (_isAppLocked) {
      initialScreen = BiometricLockScreen(
        onUnlocked: () {
          setState(() {
            _isAppLocked = false;
          });
        },
      );
    } else if (_isGuestOrLoggedIn) {
      initialScreen = MainNavigationScreen(
        onSignOut: () {
          setState(() {
            _isGuestOrLoggedIn = false;
          });
        },
      );
    } else {
      initialScreen = AuthScreen(
        onAuthSuccess: () async {
          final lockEnabled = await _biometricService.isAppLockEnabled();
          setState(() {
            _isGuestOrLoggedIn = true;
            _isAppLocked = lockEnabled;
          });
        },
      );
    }

    return MaterialApp(
      title: 'Expense OS Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: initialScreen,
    );
  }
}

class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const BiometricLockScreen({super.key, required this.onUnlocked});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() => _isAuthenticating = true);
    final authenticated = await _biometricService.authenticate(
      reason: 'Authenticate to unlock Expense OS Command Center',
    );
    if (mounted) {
      setState(() => _isAuthenticating = false);
    }

    if (authenticated) {
      widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.fingerprint, size: 72, color: AppTheme.accentCyan),
              ),
              const SizedBox(height: 24),
              Text(
                'Expense OS Locked',
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Biometric App Lock is active. Scan fingerprint or Face ID to continue.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: _isAuthenticating ? null : _authenticate,
                icon: const Icon(Icons.lock_open, color: Colors.black),
                label: Text(
                  _isAuthenticating ? 'Authenticating...' : 'Unlock App',
                  style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
