import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
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

class _ExpenseOSAppState extends State<ExpenseOSApp> {
  final SupabaseService _supabaseService = SupabaseService();
  final CurrencyService _currencyService = CurrencyService();

  bool _hasSeenOnboarding = false;
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
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
    _authSubscription?.cancel();
    super.dispose();
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
    final authed = _supabaseService.isAuthenticated && (_supabaseService.safeClient?.auth.currentSession != null);

    if (mounted) {
      setState(() {
        _hasSeenOnboarding = hasSeenOnboarding;
        _isAuthenticated = authed;
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
            onAuthSuccess: () {
              setState(() {
                _isAuthenticated = true;
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
