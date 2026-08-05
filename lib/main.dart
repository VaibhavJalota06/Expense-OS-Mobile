import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';

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

class ExpenseOSApp extends StatelessWidget {
  const ExpenseOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense OS Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DashboardScreen(),
    );
  }
}
