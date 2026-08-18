import 'package:flutter/material.dart';
import '../services/app_update_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/spendly_nav_bar.dart';
import 'add_expense_screen.dart';
import 'bills_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'savings_goals_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  const MainNavigationScreen({super.key, required this.onSignOut});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final SupabaseService _supabaseService = SupabaseService();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
        onOpenAddExpense: _openAddExpenseSheet,
        onSignOut: widget.onSignOut,
      ),
      const BillsScreen(showBackButton: false),
      const SavingsGoalsScreen(showBackButton: false),
      ProfileScreen(onSignOut: widget.onSignOut),
    ];

    // Automatic silent check for new updates on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () async {
        if (!mounted) return;
        final updateInfo = await AppUpdateService().checkForUpdate();
        if (mounted && updateInfo.isUpdateAvailable) {
          AppUpdateService().showUpdateModal(context, updateInfo);
        }
      });
    });
  }

  void _openAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddExpenseSheet(
        onSave: (newExpense) async {
          await _supabaseService.addExpense(newExpense);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: EdgeInsets.only(
            left: screenWidth > 600 ? (screenWidth - 560) / 2 : 0,
            right: screenWidth > 600 ? (screenWidth - 560) / 2 : 0,
            bottom: 6,
          ),
          child: SpendlyNavBar(
            currentIndex: _currentIndex,
            onTabSelected: (index) {
              setState(() => _currentIndex = index);
            },
            onAddPressed: _openAddExpenseSheet,
          ),
        ),
      ),
    );
  }
}
