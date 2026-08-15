import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';
import '../services/app_update_service.dart';
import '../services/currency_service.dart';
import '../services/supabase_service.dart';
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

  String _displayName = 'User';
  String _email = 'user@gmail.com';
  String? _avatarUrl;
  String? _customAvatarPath;
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
    final user = _supabaseService.currentUser;

    if (user != null) {
      await SupabaseService.cacheUserData(user);
    }

    final googleEmail = prefs.getString('google_user_email');
    final googleAvatar = prefs.getString('google_user_avatar');
    final customName = prefs.getString('custom_user_name');
    final customAvatar = prefs.getString('custom_avatar_path');

    String email = user?.email ?? googleEmail ?? 'Member';
    String name = customName ?? (user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'] ?? (email.contains('@') ? email.split('@').first : 'Expense User'));
    String? photoUrl = googleAvatar ?? user?.userMetadata?['avatar_url'] ?? user?.userMetadata?['picture'];

    final savedSymbol = prefs.getString('app_currency_symbol') ?? CurrencyService.currencySymbolNotifier.value;

    if (mounted) {
      setState(() {
        _displayName = name;
        _email = email;
        _avatarUrl = photoUrl;
        _customAvatarPath = customAvatar;
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('custom_avatar_path', pickedFile.path);
        if (mounted) {
          setState(() {
            _customAvatarPath = pickedFile.path;
          });
        }
      }
    } catch (e) {
      debugPrint('Image picking error: $e');
    }
  }

  void _showEditNameDialog() {
    final nameController = TextEditingController(text: _displayName);
    final emailController = TextEditingController(text: _email);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Edit Profile Details',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.textPrimary, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Full Name',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                autofocus: true,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\.]"))],
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Vaibhav Jalota',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: AppTheme.monexBlue),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gmail / Email Address',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'yourname@gmail.com',
                  prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20, color: AppTheme.monexBlue),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF667085), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newEmail = emailController.text.trim();
              final prefs = await SharedPreferences.getInstance();

              if (newName.isNotEmpty) {
                await prefs.setString('custom_user_name', newName);
              }
              if (newEmail.isNotEmpty) {
                await prefs.setString('google_user_email', newEmail);
              }

              setState(() {
                if (newName.isNotEmpty) _displayName = newName;
                if (newEmail.isNotEmpty) _email = newEmail;
              });

              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.monexBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Save Profile', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showCurrencySelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.60,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFD0D5DD), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Default Currency',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
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
                          color: isSelected ? AppTheme.monexBlue : AppTheme.textPrimary,
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
    final prefs = await SharedPreferences.getInstance();
    final currentCap = prefs.getDouble('monthly_budget_cap') ?? 0.0;
    final controller = TextEditingController(text: currentCap > 0 ? currentCap.toStringAsFixed(0) : '');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Monthly Budget Limit', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set your total monthly spending cap:', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              decoration: InputDecoration(
                prefixText: '$_selectedCurrencySymbol ',
                hintText: 'e.g. 50000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
    final prefs = await SharedPreferences.getInstance();
    final currentBal = prefs.getDouble('user_starting_balance') ?? 0.0;
    final controller = TextEditingController(text: currentBal != 0 ? currentBal.toStringAsFixed(0) : '');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Starting Bank Balance', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter your initial bank / wallet balance:', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              decoration: InputDecoration(
                prefixText: '$_selectedCurrencySymbol ',
                hintText: 'e.g. 25000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.monexBlue, foregroundColor: Colors.white),
            onPressed: () async {
              final newBal = double.tryParse(controller.text.trim()) ?? 0.0;
              await prefs.setDouble('user_starting_balance', newBal);
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

  @override
  Widget build(BuildContext context) {
    final activeSymbol = CurrencyService.currencySymbolNotifier.value;
    final currencyFormatter = NumberFormat.currency(symbol: activeSymbol, locale: 'en_US', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'App Settings & Financial Controls',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F3F9), width: 1.2),
                boxShadow: [
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
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Configure currency, budget limits & security',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF667085),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F3F9), width: 1.2),
                boxShadow: [
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
                      color: AppTheme.textPrimary,
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
              title: 'Preferences',
              children: [
                ListTile(
                  leading: const Icon(Icons.attach_money_rounded, color: AppTheme.monexBlue),
                  title: Text('Default Currency', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
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
                  title: Text('App Version', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  subtitle: Text('v${AppUpdateService.currentAppVersion} (Build ${AppUpdateService.currentBuildNumber})', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
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
                  title: Text('Export Expenses (CSV)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  subtitle: Text('Generate downloadable CSV report of all expenses', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                  onTap: () async {
                    final list = await _supabaseService.getExpenses();
                    final expenses = list.isNotEmpty ? list : _supabaseService.localExpenses;

                    final StringBuffer csv = StringBuffer();
                    csv.writeln('Date,Category,Title,Amount,Type,PaymentMethod,Notes');
                    for (var e in expenses) {
                      csv.writeln('${DateFormat('yyyy-MM-dd').format(e.date)},"${e.category}","${e.title}",${e.amount},"${e.type}","${e.paymentMethod}","${e.notes ?? ''}"');
                    }

                    await Clipboard.setData(ClipboardData(text: csv.toString()));

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('📋 ${expenses.length} expenses exported & copied to clipboard!', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                          backgroundColor: AppTheme.monexBlue,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1, color: Color(0xFFF1F3F9)),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: Color(0xFFF79009)),
                  title: Text(
                    'Clear All Local App Data',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFFB54708)),
                  ),
                  subtitle: Text('Reset local goals, bills, and cached records', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text('Clear All Local Data?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
                        content: Text('This will clear all locally saved goals, recurring bills, and budget caps.', style: GoogleFonts.plusJakartaSans(fontSize: 14)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
                const Divider(height: 1, color: Color(0xFFF1F3F9)),
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

  Widget _buildInitials() {
    final initials = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U';
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAECF0)),
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
                  color: const Color(0xFF667085),
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
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F3F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
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
                  color: const Color(0xFF98A2B3),
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
}
