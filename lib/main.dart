import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_screen.dart';
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

  // Initialize Supabase Client
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
  bool _isGuestOrLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _checkAuthStatus() {
    if (_supabaseService.isAuthenticated) {
      setState(() {
        _isGuestOrLoggedIn = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense OS Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _isGuestOrLoggedIn
          ? MainNavigationScreen(
              onSignOut: () {
                setState(() {
                  _isGuestOrLoggedIn = false;
                });
              },
            )
          : AuthScreen(
              onAuthSuccess: () {
                setState(() {
                  _isGuestOrLoggedIn = true;
                });
              },
            ),
    );
  }
}
