import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/currency_service.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'services/theme_service.dart';
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

  // Instant local storage access (<5ms)
  final prefs = await SharedPreferences.getInstance();

  // Non-blocking background initializations
  SupabaseService.initialize().catchError((e) {
    debugPrint('Supabase initialization error: $e');
  });
  CurrencyService().initialize().catchError((_) {});
  NotificationService().initialize().catchError((_) {});
  ThemeService.initialize().catchError((_) {});

  final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
  final isPersistentLoggedIn = prefs.getBool('persistent_user_logged_in') ?? false;
  final cachedUserId = prefs.getString('supabase_user_id');
  final hasCachedUser = (cachedUserId != null && cachedUserId.isNotEmpty) || (prefs.getString('google_user_email') != null);

  final initialAuthed = isPersistentLoggedIn || hasCachedUser;

  runApp(ExpenseOSApp(
    initialHasSeenOnboarding: hasSeenOnboarding,
    initialIsAuthenticated: initialAuthed,
  ));
}

class ExpenseOSApp extends StatefulWidget {
  final bool initialHasSeenOnboarding;
  final bool initialIsAuthenticated;

  const ExpenseOSApp({
    super.key,
    required this.initialHasSeenOnboarding,
    required this.initialIsAuthenticated,
  });

  @override
  State<ExpenseOSApp> createState() => _ExpenseOSAppState();
}

class _ExpenseOSAppState extends State<ExpenseOSApp> {
  final SupabaseService _supabaseService = SupabaseService();

  bool _showSplash = true;
  late bool _hasSeenOnboarding;
  late bool _isAuthenticated;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _hasSeenOnboarding = widget.initialHasSeenOnboarding;
    _isAuthenticated = widget.initialIsAuthenticated;

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
          final prefs = await SharedPreferences.getInstance();
          final isStillPersistent = prefs.getBool('persistent_user_logged_in') ?? false;
          if (!isStillPersistent && mounted) {
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: CurrencyService.currencySymbolNotifier,
          builder: (context, currentCurrencySymbol, _) {
            Widget initialScreen;
            if (_showSplash) {
              initialScreen = SplashScreen(
                onFinish: () {
                  if (mounted) {
                    setState(() {
                      _showSplash = false;
                    });
                  }
                },
              );
            } else if (!_hasSeenOnboarding) {
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
              key: ValueKey('auth_state_$_isAuthenticated'),
              title: 'Expense OS',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              themeMode: ThemeMode.light,
              home: initialScreen,
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (context) => initialScreen,
                  settings: settings,
                );
              },
              onUnknownRoute: (settings) {
                return MaterialPageRoute(
                  builder: (context) => initialScreen,
                  settings: settings,
                );
              },
            );
          },
        );
      },
    );
  }
}
