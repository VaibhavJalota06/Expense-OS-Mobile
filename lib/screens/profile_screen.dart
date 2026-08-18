import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';
import '../services/app_update_service.dart';
import '../services/currency_service.dart';
import '../services/export_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_profile_modal.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  const ProfileScreen({super.key, required this.onSignOut});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  String _selectedCurrencySymbol = '\$';

  int _totalTransactions = 0;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _savingsRate = 0.0;

  final List<Map<String, String>> _currencies = [
    {'code': 'USD', 'symbol': '\$', 'name': '\$ USD (US Dollar)'},
    {'code': 'INR', 'symbol': '₹', 'name': '₹ INR (Indian Rupee)'},
    {'code': 'EUR', 'symbol': '€', 'name': '€ EUR (Euro)'},
    {'code': 'GBP', 'symbol': '£', 'name': '£ GBP (British Pound)'},
    {'code': 'JPY', 'symbol': '¥', 'name': '¥ JPY (Japanese Yen)'},
    {'code': 'CAD', 'symbol': 'CA\$', 'name': 'CA\$ CAD (Canadian Dollar)'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'A\$ AUD (Australian Dollar)'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'S\$ SGD (Singapore Dollar)'},
    {'code': 'AED', 'symbol': 'AED', 'name': 'AED (UAE Dirham)'},
  ];

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserStatistics();

    SupabaseService.refreshNotifier.addListener(_loadUserStatistics);

    if (_supabaseService.safeClient != null) {
      _authSubscription = _supabaseService.safeClient!.auth.onAuthStateChange.listen((data) {
        if (mounted) {
          _loadUserData();
          _loadUserStatistics();
        }
      });
    }
  }

  @override
  void dispose() {
    SupabaseService.refreshNotifier.removeListener(_loadUserStatistics);
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSymbol = prefs.getString('app_currency_symbol') ?? CurrencyService.currencySymbolNotifier.value;

    if (mounted) {
      setState(() {
        _selectedCurrencySymbol = savedSymbol;
      });
    }
  }

  Future<void> _loadUserStatistics() async {
    try {
      final list = await _supabaseService.getExpenses();
      if (mounted) {
        _recalculateUserStatistics(list);
      }
    } catch (_) {}
  }

  void _recalculateUserStatistics(List<Expense> expenses) {
    double income = 0;
    double expense = 0;

    for (var e in expenses) {
      if (e.type.toLowerCase() == 'income') {
        income += e.amount;
      } else {
        expense += e.amount;
      }
    }

    final rate = income > 0 ? (((income - expense) / income) * 100).clamp(0.0, 100.0) : 0.0;

    setState(() {
      _totalTransactions = expenses.length;
      _totalIncome = income;
      _totalExpense = expense;
      _savingsRate = rate;
    });
  }

  void _showCurrencySelector() {
    final isDark = AppTheme.isDark(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.60,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A29) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Default Currency',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _currencies.length,
                  itemBuilder: (context, index) {
                    final curr = _currencies[index];
                    final isSelected = _selectedCurrencySymbol == curr['symbol'];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      title: Text(
                        curr['name']!,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.monexBlue
                              : (isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppTheme.monexBlue)
                          : null,
                      onTap: () async {
                        await CurrencyService().setCurrency(curr['code']!, curr['symbol']!, curr['name']!);
                        setState(() {
                          _selectedCurrencySymbol = curr['symbol']!;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditBudgetDialog() async {
    final isDark = AppTheme.isDark(context);
    final prefs = await SharedPreferences.getInstance();
    final currentCap = prefs.getDouble('monthly_budget_cap') ?? 0.0;
    final controller = TextEditingController(text: currentCap > 0 ? currentCap.toStringAsFixed(0) : '');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131A29) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Monthly Budget Limit',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set your total monthly spending cap:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                prefixText: '$_selectedCurrencySymbol ',
                prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.monexBlue),
                hintText: 'e.g. 50000',
                hintStyle: GoogleFonts.plusJakartaSans(color: isDark ? const Color(0xFF64748B) : const Color(0xFF98A2B3)),
                filled: true,
                fillColor: isDark ? const Color(0xFF0D1322) : const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.monexBlue, foregroundColor: Colors.white),
            onPressed: () async {
              final newCap = double.tryParse(controller.text.trim()) ?? 0.0;
              await prefs.setDouble('monthly_budget_cap', newCap);
              SupabaseService.refreshNotifier.value++;
              if (mounted) setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Save Limit'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditStartingBalanceDialog() async {
    final isDark = AppTheme.isDark(context);
    final prefs = await SharedPreferences.getInstance();
    final currentBal = prefs.getDouble('user_starting_balance') ?? 0.0;
    final controller = TextEditingController(text: currentBal != 0 ? currentBal.toStringAsFixed(0) : '');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131A29) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Starting Bank Balance',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your initial bank / wallet balance:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                prefixText: '$_selectedCurrencySymbol ',
                prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.monexBlue),
                hintText: 'e.g. 25000',
                hintStyle: GoogleFonts.plusJakartaSans(color: isDark ? const Color(0xFF64748B) : const Color(0xFF98A2B3)),
                filled: true,
                fillColor: isDark ? const Color(0xFF0D1322) : const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.monexBlue, foregroundColor: Colors.white),
            onPressed: () async {
              final newBal = double.tryParse(controller.text.trim()) ?? 0.0;
              await prefs.setDouble('user_starting_balance', newBal);
              await SupabaseService.syncFinancialProfileToCloud(startingBalance: newBal);
              SupabaseService.refreshNotifier.value++;
              if (mounted) setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Save Balance'),
          ),
        ],
      ),
    );
  }

  void _showThemeSelector() {
    final isDarkNow = AppTheme.isDark(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.themeModeNotifier,
          builder: (context, activeMode, _) {
            final isDark = activeMode == ThemeMode.dark ||
                (activeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

            return Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131A29) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE4E7EC),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'App Appearance & Theme',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Choose your preferred visual theme',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildThemeOption(
                    title: '☀️ Light Mode',
                    subtitle: 'Clean white canvas with blue accents',
                    mode: ThemeMode.light,
                    currentMode: activeMode,
                    isDark: isDark,
                    ctx: ctx,
                  ),
                  const SizedBox(height: 10),
                  _buildThemeOption(
                    title: '🌙 Dark Mode',
                    subtitle: 'Deep charcoal & glassmorphic dark palette',
                    mode: ThemeMode.dark,
                    currentMode: activeMode,
                    isDark: isDark,
                    ctx: ctx,
                  ),
                  const SizedBox(height: 10),
                  _buildThemeOption(
                    title: '📱 System Default',
                    subtitle: 'Automatically match device system theme',
                    mode: ThemeMode.system,
                    currentMode: activeMode,
                    isDark: isDark,
                    ctx: ctx,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required bool isDark,
    required BuildContext ctx,
  }) {
    final isSelected = mode == currentMode;
    return GestureDetector(
      onTap: () async {
        await ThemeService.setThemeMode(mode);
        if (mounted) setState(() {});
        Navigator.pop(ctx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.monexBlue.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1A2234) : const Color(0xFFF8F9FC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.monexBlue
                : (isDark ? const Color(0xFF2E3A52) : const Color(0xFFEAECF0)),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppTheme.monexBlue
                          : (isDark ? Colors.white : AppTheme.textPrimary),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.monexBlue, size: 20)
            else
              Icon(Icons.radio_button_unchecked_rounded,
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFD0D5DD), size: 20),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final activeSymbol = CurrencyService.currencySymbolNotifier.value;
    final currencyFormatter = NumberFormat.currency(symbol: activeSymbol, locale: 'en_US', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings & Profile',
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // ------------------------------------------------------------
            // 1. APP SETTINGS HEADER BANNER
            // ------------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131A29) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9), width: 1.2),
                boxShadow: isDark ? [] : [
                  BoxShadow(
                    color: const Color(0xFF101828).withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.monexBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.settings_suggest_rounded, color: AppTheme.monexBlue, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Settings & Preferences',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Configure currency, budget limits & security',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => UserProfileModal(
                          onSignOut: widget.onSignOut,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.monexBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.monexBlue),
                          const SizedBox(width: 4),
                          Text(
                            'Profile',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.monexBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ------------------------------------------------------------
            // 2. USER FINANCIAL STATS & LIFETIME SUMMARY
            // ------------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131A29) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9), width: 1.2),
                boxShadow: isDark ? [] : [
                  BoxShadow(
                    color: const Color(0xFF101828).withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial Health Overview',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          label: 'Transactions',
                          value: '$_totalTransactions',
                          icon: Icons.receipt_long_rounded,
                          color: AppTheme.monexBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricItem(
                          label: 'Savings Rate',
                          value: '${_savingsRate.toStringAsFixed(0)}%',
                          icon: Icons.pie_chart_rounded,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          label: 'Total Inflow',
                          value: currencyFormatter.format(_totalIncome),
                          icon: Icons.arrow_downward_rounded,
                          color: AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricItem(
                          label: 'Total Outflow',
                          value: currencyFormatter.format(_totalExpense),
                          icon: Icons.arrow_upward_rounded,
                          color: AppTheme.dangerRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),



            const SizedBox(height: 20),

            // ------------------------------------------------------------
            // 4. PREFERENCES & CURRENCY
            // ------------------------------------------------------------
            _buildSectionCard(
              title: 'Preferences & Financial Controls',
              children: [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeService.themeModeNotifier,
                  builder: (context, currentMode, _) {
                    String modeLabel = 'System Default';
                    IconData modeIcon = Icons.brightness_auto_rounded;
                    if (currentMode == ThemeMode.dark) {
                      modeLabel = 'Dark Mode';
                      modeIcon = Icons.dark_mode_rounded;
                    } else if (currentMode == ThemeMode.light) {
                      modeLabel = 'Light Mode';
                      modeIcon = Icons.light_mode_rounded;
                    }
                    return ListTile(
                      leading: Icon(modeIcon, color: const Color(0xFF6366F1)),
                      title: Text('App Theme & Appearance', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary)),
                      subtitle: Text(modeLabel, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
                      onTap: _showThemeSelector,
                    );
                  },
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9)),
                ListTile(
                  leading: const Icon(Icons.attach_money_rounded, color: AppTheme.monexBlue),
                  title: Text('Default Currency', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activeSymbol,
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.monexBlue, fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
                    ],
                  ),
                  onTap: _showCurrencySelector,
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9)),
                ListTile(
                  leading: const Icon(Icons.savings_rounded, color: AppTheme.successGreen),
                  title: Text('Monthly Budget Limit', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary)),
                  subtitle: Text('Set monthly spending threshold & alerts', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
                  onTap: _showEditBudgetDialog,
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9)),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF7A5AF8)),
                  title: Text('Starting Bank Balance', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary)),
                  subtitle: Text('Initial money across accounts & cards', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
                  onTap: _showEditStartingBalanceDialog,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ------------------------------------------------------------
            // 5. ABOUT & DIRECT APP UPDATES
            // ------------------------------------------------------------
            _buildSectionCard(
              title: 'About & App Updates',
              children: [
                ListTile(
                  leading: const Icon(Icons.system_update_alt_rounded, color: AppTheme.monexBlue),
                  title: Text('App Version', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary)),
                  subtitle: Text('v${AppUpdateService.currentAppVersion} (Build ${AppUpdateService.currentBuildNumber})', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Checking for updates...', style: GoogleFonts.plusJakartaSans()),
                          duration: const Duration(milliseconds: 1000),
                        ),
                      );
                      final updateInfo = await AppUpdateService().checkForUpdate();
                      if (context.mounted) {
                        AppUpdateService().showUpdateModal(context, updateInfo, showUpToDateNotice: true);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.monexBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: Text('Check Update', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.monexBlue)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ------------------------------------------------------------
            // 6. ACCOUNT SECURITY & DATA
            // ------------------------------------------------------------
            _buildSectionCard(
              title: 'Account Security & Data',
              children: [
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: AppTheme.monexBlue),
                  title: Text('Export Expenses (CSV)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary)),
                  subtitle: Text('Generate downloadable CSV report of all expenses', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF98A2B3)),
                  onTap: () => _showExportModal(context),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9)),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: Color(0xFFF79009)),
                  title: Text(
                    'Clear All Local App Data',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFFF79009)),
                  ),
                  subtitle: Text('Reset local goals, bills, and cached records', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
                  onTap: () async {
                    final isDarkDialog = AppTheme.isDark(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: isDarkDialog ? const Color(0xFF131A29) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text(
                          'Clear All Local Data?',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: isDarkDialog ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                          ),
                        ),
                        content: Text(
                          'This will clear all locally saved goals, recurring bills, and budget caps.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: isDarkDialog ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: isDarkDialog ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear Data'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _supabaseService.resetAllFinancialData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✨ All financial records, expenses, and balances reset cleanly!', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                      }
                    }
                  },
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9)),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppTheme.dangerRed),
                  title: Text(
                    'Sign Out',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.dangerRed),
                  ),
                  onTap: () async {
                    await _supabaseService.signOut();
                    widget.onSignOut();
                  },
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2234) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2E3A52) : const Color(0xFFEAECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    final isDark = AppTheme.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A29) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9), width: 1.2),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: isDark ? const Color(0xFF131A29) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 16, bottom: 6),
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF98A2B3),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  void _showExportModal(BuildContext context) async {
    final isDark = AppTheme.isDark(context);
    final list = await _supabaseService.getExpenses();
    final expenses = list.isNotEmpty ? list : _supabaseService.localExpenses;
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;

    double totalIncome = 0;
    double totalExpense = 0;
    for (var e in expenses) {
      if (e.type.toLowerCase() == 'income') {
        totalIncome += e.amount;
      } else {
        totalExpense += e.amount;
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A29) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.monexBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.file_download_outlined, color: AppTheme.monexBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Financial Records',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${expenses.length} total transactions ready for export',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Summary Stats Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1322) : const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEAECF0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Income', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('$currencySymbol${totalIncome.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.successGreen)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEAECF0)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Expenses', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('$currencySymbol${totalExpense.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFFF04438))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Main Download Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.monexBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final file = await ExportService().saveCsvFile(expenses);
                  if (context.mounted) {
                    if (file != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ CSV File saved to Downloads: ${file.path.split("/").last}',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: AppTheme.successGreen,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } else {
                      final rawCsv = ExportService().generateCSV(expenses);
                      await Clipboard.setData(ClipboardData(text: rawCsv));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '📋 ${expenses.length} records copied to clipboard!',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: AppTheme.monexBlue,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  'Download CSV File',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD0D5DD)),
                      ),
                      onPressed: () async {
                        final rawCsv = ExportService().generateCSV(expenses);
                        await Clipboard.setData(ClipboardData(text: rawCsv));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                '📋 Raw CSV copied to clipboard!',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: AppTheme.monexBlue,
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.copy_rounded, size: 16, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary),
                      label: Text(
                        'Copy CSV',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD0D5DD)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showStatementPreviewModal(context, expenses);
                      },
                      icon: Icon(Icons.receipt_long_rounded, size: 16, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary),
                      label: Text(
                        'Statement',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showStatementPreviewModal(BuildContext context, List<Expense> expenses) {
    final isDark = AppTheme.isDark(context);
    final statement = ExportService().generateExecutiveStatementText(expenses);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A29) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Executive Statement',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 20, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: statement));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('📋 Statement copied to clipboard!', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                            backgroundColor: AppTheme.monexBlue,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.transparent),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      statement,
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 11,
                        color: const Color(0xFF38BDF8),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
