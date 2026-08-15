import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/biometric_service.dart';
import 'services/currency_service.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure Transparent System Status Bar & Navigation Bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(const ExpenseOSApp());
}

class ExpenseOSApp extends StatefulWidget {
  const ExpenseOSApp({super.key});

  @override
  State<ExpenseOSApp> createState() => _ExpenseOSAppState();
}

class _ExpenseOSAppState extends State<ExpenseOSApp> with WidgetsBindingObserver {
  final SupabaseService _supabaseService = SupabaseService();
  final BiometricService _biometricService = BiometricService();
  final CurrencyService _currencyService = CurrencyService();

  bool _hasSeenOnboarding = false;
  bool _isAuthenticated = false;
  bool _isAppLocked = false;
  bool _isInitialized = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAppState();
    if (_supabaseService.safeClient != null) {
      _authSubscription = _supabaseService.safeClient!.auth.onAuthStateChange.listen((data) async {
        final AuthChangeEvent event = data.event;
        if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.initialSession) {
          final user = data.session?.user ?? _supabaseService.currentUser;
          if (user != null) {
            await SupabaseService.cacheUserData(user);
            if (mounted) {
              setState(() {
                _isAuthenticated = true;
              });
            }
          }
        } else if (event == AuthChangeEvent.signedOut) {
          if (mounted) {
            setState(() {
              _isAuthenticated = false;
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    super.dispose();
  }

  DateTime? _pausedTimestamp;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedTimestamp = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkAndLockOnResume();
    }
  }

  Future<void> _checkAndLockOnResume() async {
    // If resume was triggered by dismissing the Face ID / Touch ID system dialog, do not re-lock!
    if (BiometricService.isAuthenticating) return;

    final lockEnabled = await _biometricService.isAppLockEnabled();
    if (lockEnabled && _isAuthenticated && !_isAppLocked) {
      if (_pausedTimestamp != null) {
        final elapsed = DateTime.now().difference(_pausedTimestamp!).inSeconds;
        // Require at least 2 seconds in background to trigger app lock on return
        if (elapsed < 2) {
          _pausedTimestamp = null;
          return;
        }
      }
      _pausedTimestamp = null;
      if (mounted) {
        setState(() {
          _isAppLocked = true;
        });
      }
    }
  }

  Future<void> _initializeAppState() async {
    // 1. Auto-detect & initialize local currency
    await _currencyService.initialize();

    // 2. Initialize automatic background device notifications
    NotificationService().initialize().catchError((e) {
      debugPrint('Notification init error: $e');
    });

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    final lockEnabled = await _biometricService.isAppLockEnabled();
    final authed = _supabaseService.isAuthenticated && (_supabaseService.safeClient?.auth.currentSession != null);

    if (mounted) {
      setState(() {
        _hasSeenOnboarding = hasSeenOnboarding;
        _isAuthenticated = authed;
        _isAppLocked = lockEnabled;
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: CurrencyService.currencySymbolNotifier,
      builder: (context, currentCurrencySymbol, _) {
        if (!_isInitialized) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const ExpenseOSSplashLoadingScreen(),
          );
        }

        Widget initialScreen;
        if (!_hasSeenOnboarding) {
          initialScreen = OnboardingScreen(
            onFinish: () {
              setState(() {
                _hasSeenOnboarding = true;
              });
            },
          );
        } else if (_isAppLocked) {
          initialScreen = BiometricLockScreen(
            onUnlocked: () {
              setState(() {
                _isAppLocked = false;
              });
            },
          );
        } else if (_isAuthenticated) {
          initialScreen = MainNavigationScreen(
            onSignOut: () {
              setState(() {
                _isAuthenticated = false;
              });
            },
          );
        } else {
          initialScreen = AuthScreen(
            onAuthSuccess: () async {
              final lockEnabled = await _biometricService.isAppLockEnabled();
              setState(() {
                _isAuthenticated = true;
                _isAppLocked = lockEnabled;
              });
            },
          );
        }

        return MaterialApp(
          title: 'Expense OS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: initialScreen,
        );
      },
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
      reason: 'Scan fingerprint or Face to unlock Expense OS',
    );
    setState(() => _isAuthenticating = false);

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
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.monexBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  size: 44,
                  color: AppTheme.monexBlue,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Expense OS is Locked',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock with Biometrics to access your financial records',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isAuthenticating ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.monexBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isAuthenticating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'UNLOCK NOW',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpenseOSSplashLoadingScreen extends StatelessWidget {
  const ExpenseOSSplashLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF101828).withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'assets/logo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Expense OS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: AppTheme.monexBlue,
                strokeWidth: 2.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
