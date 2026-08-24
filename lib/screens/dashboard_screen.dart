import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/expense_tile.dart';
import 'add_expense_screen.dart';
import 'calendar_expenses_screen.dart';
import 'gamification_screen.dart';
import 'ocr_scanner_screen.dart';
import 'split_bill_screen.dart';
import '../services/app_update_service.dart';
import '../services/budget_rules_engine.dart';
import '../services/currency_service.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenAddExpense;
  final VoidCallback? onSignOut;

  const DashboardScreen({super.key, this.onOpenAddExpense, this.onSignOut});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final bool _isLoading = false;
  List<Expense> _expenses = [];
  double _monthlyBudgetCap = 0.0;
  double _startingBalance = 0.0;
  int _activeStatIndex = 1; // Default highlighted card: 1 = Total Expense
  String _activeEntryType = 'expense'; // 'expense' or 'income'

  DateTime _selectedDashboardDate = DateTime.now();
  bool _filterDashboardByDate = false;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Expense> get _filteredEntries {
    final list = _expenses.where((e) => e.type == _activeEntryType).toList();
    if (!_filterDashboardByDate) return list;
    return list.where((e) => _isSameDay(e.date, _selectedDashboardDate)).toList();
  }

  double get _displayTotalExpenses {
    final list = _expenses.where((e) => e.type == 'expense');
    if (!_filterDashboardByDate) {
      return list.fold(0.0, (sum, e) => sum + e.amount);
    }
    return list.where((e) => _isSameDay(e.date, _selectedDashboardDate)).fold(0.0, (sum, e) => sum + e.amount);
  }

  String get _expenseCardTitle {
    if (!_filterDashboardByDate) return 'All-Time Expense';
    if (_isSameDay(_selectedDashboardDate, DateTime.now())) return "Today's Expense";
    if (_isSameDay(_selectedDashboardDate, DateTime.now().subtract(const Duration(days: 1)))) return "Yesterday's Expense";
    return "${DateFormat('MMM d').format(_selectedDashboardDate)} Expense";
  }

  Future<void> _pickDashboardDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDashboardDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.monexBlue,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDashboardDate = picked;
        _filterDashboardByDate = true;
      });
    }
  }

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadFromLocalCacheImmediate();
    SupabaseService.refreshNotifier.addListener(_refreshDashboard);
    _refreshDashboard();
    _supabaseService.startRealtimeSync();
    if (_supabaseService.safeClient != null) {
      _authSubscription = _supabaseService.safeClient!.auth.onAuthStateChange.listen((data) {
        if (mounted) {
          _loadUserData();
        }
      });
    }
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      try {
        final updateInfo = await AppUpdateService().checkForUpdate();
        if (updateInfo.isUpdateAvailable && updateInfo.isMandatory && mounted) {
          AppUpdateService().showUpdateModal(context, updateInfo);
        }
      } catch (_) {}
    });
  }

  Future<void> _loadFromLocalCacheImmediate() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final bal = prefs.getDouble('user_starting_balance') ?? 0.0;
    final budget = prefs.getDouble('monthly_budget_cap') ?? 0.0;
    final local = _supabaseService.localExpenses;
    setState(() {
      _startingBalance = bal;
      _monthlyBudgetCap = budget;
      if (local.isNotEmpty) {
        _expenses = List<Expense>.from(local);
      }
    });
  }

  Future<void> _refreshDashboard() async {
    await _loadExpenses();
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _supabaseService.currentUser;

    if (user != null) {
      await SupabaseService.cacheUserData(user);
      await SupabaseService.loadFinancialProfileFromCloud();
      final prefs = await SharedPreferences.getInstance();
      final bal = prefs.getDouble('user_starting_balance') ?? 0.0;
      final budget = prefs.getDouble('monthly_budget_cap') ?? 0.0;
      if (mounted) {
        setState(() {
          if (bal > 0 || _startingBalance == 0.0) {
            _startingBalance = bal;
          }
          if (budget > 0 || _monthlyBudgetCap == 0.0) {
            _monthlyBudgetCap = budget;
          }
        });
        _evaluateBudgetRules();
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    SupabaseService.refreshNotifier.removeListener(_refreshDashboard);
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    try {
      final list = await _supabaseService.getExpenses();
      final prefs = await SharedPreferences.getInstance();
      final budget = prefs.getDouble('monthly_budget_cap') ?? 0.0;
      final bal = prefs.getDouble('user_starting_balance') ?? 0.0;
      if (!mounted) return;
      setState(() {
        _expenses = list;
        if (budget > 0 || _monthlyBudgetCap == 0.0) {
          _monthlyBudgetCap = budget;
        }
        if (bal > 0 || _startingBalance == 0.0) {
          _startingBalance = bal;
        }
      });

      // Automatically evaluate AI Smart Budget Rules and push device notifications
      BudgetRulesEngine().evaluateRules(
        expenses: _expenses,
        budgetCap: _monthlyBudgetCap,
        totalIncome: _totalIncome,
        currencySymbol: CurrencyService.currencySymbolNotifier.value,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _expenses = _supabaseService.localExpenses;
      });
    }
  }

  double get _totalIncome {
    final loggedIncome = _expenses.where((e) => e.type == 'income').fold(0.0, (sum, e) => sum + e.amount);
    return _startingBalance + loggedIncome;
  }

  /// Available money after monthly budget allocation is deducted
  double get _availableMoney {
    if (_monthlyBudgetCap <= 0) return _totalIncome;
    return (_totalIncome - _monthlyBudgetCap).clamp(0.0, double.infinity);
  }

  double get _currentMonthExpenses {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.type == 'expense' && e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get _remainingMonthlyBudget {
    if (_monthlyBudgetCap <= 0) return 0.0;
    return _monthlyBudgetCap - _currentMonthExpenses;
  }

  void _openAddExpenseSheet([Expense? expenseToEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddExpenseSheet(
        expenseToEdit: expenseToEdit,
        onSave: (newExpense) async {
          if (newExpense.id != null) {
            await _supabaseService.updateExpense(newExpense);
          } else {
            await _supabaseService.addExpense(newExpense);
          }
          _loadExpenses();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: CurrencyService.currencySymbolNotifier,
      builder: (context, activeSymbol, _) {
        final currency = NumberFormat.currency(symbol: activeSymbol, locale: 'en_US', decimalDigits: 0);

        final isDark = AppTheme.isDark(context);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.monexBlue))
              : SafeArea(
                  child: RefreshIndicator(
                    color: AppTheme.monexBlue,
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      await _refreshDashboard();
                    },
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Header: Official Logo + Brand Name + Reminders & Alerts
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.asset(
                                      'assets/logo.png',
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Expense OS',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      Text(
                                        'Overview',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.notifications_none_rounded,
                                        color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary, size: 24),
                                    tooltip: 'Reminders & Alerts',
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      _showRemindersSheet();
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.logout_rounded,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085), size: 22),
                                    tooltip: 'Sign Out / Switch Account',
                                    onPressed: () async {
                                      HapticFeedback.mediumImpact();
                                      await _supabaseService.signOut();
                                      if (widget.onSignOut != null) {
                                        widget.onSignOut!();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Horizontal Stat Cards Carousel
                          SizedBox(
                            height: 145,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              children: [
                                // Card 1: Total Money (Bank Funds = Initial Starting Balance + Incomes)
                                _buildStatCard(
                                  index: 0,
                                  title: 'Total Money',
                                  amount: currency.format(_availableMoney),
                                  subtitle: _monthlyBudgetCap > 0 ? 'Gross: ${currency.format(_totalIncome)}' : null,
                                  icon: Icons.account_balance_wallet_outlined,
                                  isHighlighted: _activeStatIndex == 0,
                                ),
                                const SizedBox(width: 14),

                                // Card 2: Total Expense (Hero Royal Blue Card with dynamic date filtering)
                                _buildStatCard(
                                  index: 1,
                                  title: _expenseCardTitle,
                                  amount: currency.format(_displayTotalExpenses),
                                  icon: Icons.credit_card_rounded,
                                  isHighlighted: _activeStatIndex == 1,
                                ),
                                const SizedBox(width: 14),

                                // Card 3: Remaining Monthly Budget (Budget Cap - Expenses Spent)
                                _buildStatCard(
                                  index: 2,
                                  title: 'Remaining Budget',
                                  amount: currency.format(_remainingMonthlyBudget),
                                  subtitle: _monthlyBudgetCap > 0 ? 'Cap: ${currency.format(_monthlyBudgetCap)}' : 'Tap to set cap',
                                  icon: Icons.pie_chart_outline_rounded,
                                  isHighlighted: _activeStatIndex == 2,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Pagination Indicator Dots for Stat Cards
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (i) {
                              final isActive = _activeStatIndex == i;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _activeStatIndex = i);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: isActive ? 22 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppTheme.primaryBlue
                                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFD0D5DD)),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 16),

                      // Interactive Date Selector Filter Bar for Dashboard (Sleek Monex Pill Design)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: [
                            // All Time Pill
                            _buildDateFilterPill(
                              label: 'All Time',
                              isSelected: !_filterDashboardByDate,
                              showCheck: true,
                              onTap: () => setState(() {
                                _filterDashboardByDate = false;
                              }),
                            ),
                            const SizedBox(width: 8),

                            // Today Pill
                            _buildDateFilterPill(
                              label: 'Today',
                              isSelected: _filterDashboardByDate && _isSameDay(_selectedDashboardDate, DateTime.now()),
                              showCheck: true,
                              onTap: () => setState(() {
                                _filterDashboardByDate = true;
                                _selectedDashboardDate = DateTime.now();
                              }),
                            ),
                            const SizedBox(width: 8),

                            // Yesterday Pill
                            _buildDateFilterPill(
                              label: 'Yesterday',
                              isSelected: _filterDashboardByDate && _isSameDay(_selectedDashboardDate, DateTime.now().subtract(const Duration(days: 1))),
                              showCheck: true,
                              onTap: () => setState(() {
                                _filterDashboardByDate = true;
                                _selectedDashboardDate = DateTime.now().subtract(const Duration(days: 1));
                              }),
                            ),
                            const SizedBox(width: 8),
                            // Custom Calendar Date Picker Pill
                            _buildDateFilterPill(
                              label: _filterDashboardByDate && !_isSameDay(_selectedDashboardDate, DateTime.now()) && !_isSameDay(_selectedDashboardDate, DateTime.now().subtract(const Duration(days: 1)))
                                  ? DateFormat('MMM d, yyyy').format(_selectedDashboardDate)
                                  : 'Pick Date 🗓️',
                              isSelected: _filterDashboardByDate && !_isSameDay(_selectedDashboardDate, DateTime.now()) && !_isSameDay(_selectedDashboardDate, DateTime.now().subtract(const Duration(days: 1))),
                              icon: Icons.calendar_month_rounded,
                              onTap: _pickDashboardDate,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Quick Intelligence Tools Bar
                      Row(
                        children: [
                          _buildQuickToolButton(
                            icon: Icons.document_scanner_rounded,
                            label: 'Scan Receipt',
                            badge: 'AI',
                            color: AppTheme.monexBlue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OCRScannerScreen(
                                    onParsedResult: (totalAmount, merchant, category, lineItems) async {
                                      if (lineItems.isNotEmpty) {
                                        for (var item in lineItems) {
                                          final scannedExpense = Expense(
                                            title: '${item.name} ($merchant)',
                                            amount: item.price,
                                            category: item.category.isNotEmpty ? item.category : category,
                                            type: 'expense',
                                            date: DateTime.now(),
                                            paymentMethod: 'Card',
                                          );
                                          await _supabaseService.addExpense(scannedExpense);
                                        }
                                      } else {
                                        final scannedExpense = Expense(
                                          title: merchant,
                                          amount: totalAmount,
                                          category: category,
                                          type: 'expense',
                                          date: DateTime.now(),
                                          paymentMethod: 'Card',
                                        );
                                        await _supabaseService.addExpense(scannedExpense);
                                      }
                                      _loadExpenses();
                                      if (mounted) {
                                        final count = lineItems.isNotEmpty ? lineItems.length : 1;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('$count scanned item(s) saved from $merchant • $activeSymbol${totalAmount.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                                            backgroundColor: AppTheme.successGreen,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildQuickToolButton(
                            icon: Icons.call_split_rounded,
                            label: 'Split Bill',
                            color: const Color(0xFF7A5AF8),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const SplitBillScreen()));
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildQuickToolButton(
                            icon: Icons.calendar_month_rounded,
                            label: 'Calendar',
                            color: const Color(0xFF2E90FA),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarExpensesScreen()));
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildQuickToolButton(
                            icon: Icons.emoji_events_rounded,
                            label: 'Quests',
                            badge: 'XP',
                            color: const Color(0xFFF79009),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const GamificationScreen()));
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Category Filter Capsule Switcher: [💸 Expenses] & [💰 Extra Income Logs]
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131A29) : const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            // 💸 Expenses Pill
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _activeEntryType = 'expense'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _activeEntryType == 'expense' ? AppTheme.monexBlue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: _activeEntryType == 'expense'
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.monexBlue.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('💸', style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Expenses',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: _activeEntryType == 'expense'
                                              ? Colors.white
                                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // 💰 Extra Income Logs Pill
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _activeEntryType = 'income'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _activeEntryType == 'income' ? AppTheme.monexBlue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: _activeEntryType == 'income'
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.monexBlue.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('💰', style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Extra Income Logs',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: _activeEntryType == 'income'
                                              ? Colors.white
                                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // "Latest Entries" Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _activeEntryType == 'expense' ? 'Expense Logs' : 'Income Logs',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${_filteredEntries.length} ${_filteredEntries.length == 1 ? 'entry' : 'entries'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF98A2B3),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Filtered Transaction Entries List
                      if (_filteredEntries.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(
                                _activeEntryType == 'expense' ? Icons.receipt_long_outlined : Icons.account_balance_wallet_outlined,
                                size: 44,
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFD0D5DD),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _activeEntryType == 'expense' ? 'No expense logs recorded yet' : 'No extra income logs recorded yet',
                                style: GoogleFonts.plusJakartaSans(
                                  color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredEntries.length,
                          itemBuilder: (context, index) {
                            final expense = _filteredEntries[index];
                            return ExpenseTile(
                              expense: expense,
                              onTap: () => _openAddExpenseSheet(expense),
                              onLongPress: () => _showTransactionContextMenu(expense),
                              onDelete: () async {
                                if (expense.id != null) {
                                  await _supabaseService.deleteExpense(expense.id!);
                                  _loadExpenses();
                                }
                              },
                            );
                          },
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
        );
      },
    );
  }

  void _showTransactionContextMenu(Expense expense) {
    final isDark = AppTheme.isDark(context);
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final currency = NumberFormat.currency(symbol: currencySymbol, locale: 'en_US', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A29) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: expense.type == 'income'
                        ? (isDark ? const Color(0xFF0D3320) : const Color(0xFFECFDF3))
                        : (isDark ? const Color(0xFF1A2234) : const Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      expense.type == 'income' ? '💰' : '💸',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${expense.category} • ${currency.format(expense.amount)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: expense.type == 'income' ? AppTheme.successGreen : AppTheme.dangerRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppTheme.primaryBlue),
              title: Text('Edit Transaction', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _openAddExpenseSheet(expense);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Color(0xFF7A5AF8)),
              title: Text('Duplicate Entry', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(ctx);
                final duplicated = Expense(
                  title: '${expense.title} (Copy)',
                  amount: expense.amount,
                  category: expense.category,
                  type: expense.type,
                  date: DateTime.now(),
                  paymentMethod: expense.paymentMethod,
                  notes: expense.notes,
                );
                await _supabaseService.addExpense(duplicated);
                _loadExpenses();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Transaction duplicated!', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed),
              title: Text('Delete Transaction', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppTheme.dangerRed)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(ctx);
                if (expense.id != null) {
                  final deletedExpense = expense;
                  await _supabaseService.deleteExpense(expense.id!);
                  _loadExpenses();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Transaction deleted', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                        action: SnackBarAction(
                          label: 'UNDO',
                          textColor: Colors.white,
                          onPressed: () async {
                            await _supabaseService.addExpense(deletedExpense);
                            _loadExpenses();
                          },
                        ),
                        backgroundColor: const Color(0xFF1E293B),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showRemindersSheet() {
    final isDark = AppTheme.isDark(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (rCtx) {
        bool dailyLogReminder = true;
        bool billDueReminder = true;
        bool budgetWarning = true;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131A29) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
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
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Expense OS Reminders',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0D3320) : const Color(0xFFECFDF3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('ACTIVE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.successGreen)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A2234) : const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_calendar_rounded, color: AppTheme.monexBlue, size: 20),
                        ),
                        title: Text('Daily Spending Log Reminder', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary)),
                        subtitle: Text('Remind me at 9:00 PM to record today\'s expenses', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
                        value: dailyLogReminder,
                        activeTrackColor: AppTheme.monexBlue,
                        onChanged: (val) => setSheetState(() => dailyLogReminder = val),
                      ),
                      Divider(height: 16, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9)),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF3B1515) : const Color(0xFFFEF3F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.event_repeat_rounded, color: AppTheme.dangerRed, size: 20),
                        ),
                        title: Text('Bill Due Date Alert', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary)),
                        subtitle: Text('Alert 2 days before recurring bills and rent', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
                        value: billDueReminder,
                        activeTrackColor: AppTheme.monexBlue,
                        onChanged: (val) => setSheetState(() => billDueReminder = val),
                      ),
                      Divider(height: 16, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9)),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF332008) : const Color(0xFFFEF0C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF79009), size: 20),
                        ),
                        title: Text('80% Budget Cap Warning', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary)),
                        subtitle: Text('Notify when nearing monthly limit threshold', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
                        value: budgetWarning,
                        activeTrackColor: AppTheme.monexBlue,
                        onChanged: (val) => setSheetState(() => budgetWarning = val),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(rCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Notification preferences saved!', style: GoogleFonts.plusJakartaSans()),
                                backgroundColor: AppTheme.monexBlue,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.monexBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('SAVE PREFERENCES', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSetTotalMoneyDialog() {
    final isDark = AppTheme.isDark(context);
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final controller = TextEditingController(text: _totalIncome > 0 ? _totalIncome.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131A29) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Total Money (Bank Balance)',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your total bank account money (overall available funds):',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.monexBlue),
              decoration: InputDecoration(
                prefixText: '$currencySymbol ',
                prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.monexBlue),
                hintText: 'e.g. 50000',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF98A2B3),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0D1322) : const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                final prefs = await SharedPreferences.getInstance();
                final currentIncomeLogs = _expenses.where((e) => e.type == 'income').fold(0.0, (sum, e) => sum + e.amount);
                final newStarting = (val - currentIncomeLogs).clamp(0.0, double.infinity);
                await prefs.setDouble('user_starting_balance', newStarting);
                if (mounted) {
                  setState(() {
                    _startingBalance = newStarting;
                  });
                  _evaluateBudgetRules();
                }
                await SupabaseService.syncFinancialProfileToCloud(startingBalance: newStarting);
              }
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.monexBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Save', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showSetBudgetDialog() {
    final isDark = AppTheme.isDark(context);
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final controller = TextEditingController(text: _monthlyBudgetCap > 0 ? _monthlyBudgetCap.toStringAsFixed(0) : '');
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF131A29) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Set Monthly Budget',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the spending budget taken out from your total bank money ($currencySymbol${_totalIncome.toStringAsFixed(0)} available):',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                onChanged: (text) {
                  final val = double.tryParse(text.trim()) ?? 0.0;
                  if (val > _totalIncome) {
                    setDialogState(() {
                      errorMessage = 'Cannot exceed total bank money ($currencySymbol${_totalIncome.toStringAsFixed(0)})';
                    });
                  } else if (errorMessage != null) {
                    setDialogState(() {
                      errorMessage = null;
                    });
                  }
                },
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: errorMessage != null ? AppTheme.dangerRed : AppTheme.monexBlue,
                ),
                decoration: InputDecoration(
                  prefixText: '$currencySymbol ',
                  prefixStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: errorMessage != null ? AppTheme.dangerRed : AppTheme.monexBlue,
                  ),
                  hintText: 'e.g. 20000',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF98A2B3),
                  ),
                  filled: true,
                  fillColor: errorMessage != null
                      ? (isDark ? const Color(0xFF3B1515) : const Color(0xFFFEF3F2))
                      : (isDark ? const Color(0xFF0D1322) : const Color(0xFFF9FAFB)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: errorMessage != null ? AppTheme.dangerRed : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC))),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: errorMessage != null ? AppTheme.dangerRed : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC))),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: errorMessage != null ? AppTheme.dangerRed : AppTheme.monexBlue, width: 1.5),
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.dangerRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = double.tryParse(controller.text.trim());
                if (val == null || val < 0) return;

                // Hard block if budget exceeds total bank account money
                if (val > _totalIncome) {
                  setDialogState(() {
                    errorMessage = 'Cannot exceed total bank money ($currencySymbol${_totalIncome.toStringAsFixed(0)})';
                  });
                  return;
                }

                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('monthly_budget_cap', val);
                setState(() => _monthlyBudgetCap = val);
                await SupabaseService.syncFinancialProfileToCloud(budgetCap: val);
                SupabaseService.refreshNotifier.value++;
                _evaluateBudgetRules();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.monexBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Save Budget', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _evaluateBudgetRules() async {
    final alerts = await BudgetRulesEngine().evaluateRules(
      expenses: _expenses,
      budgetCap: _monthlyBudgetCap,
      totalIncome: _totalIncome,
      currencySymbol: CurrencyService.currencySymbolNotifier.value,
    );

    if (alerts.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alerts.first,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFB42318),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  Widget _buildStatCard({
    required int index,
    required String title,
    required String amount,
    String? subtitle,
    required IconData icon,
    required bool isHighlighted,
  }) {
    final isDark = AppTheme.isDark(context);
    final isEditable = index == 0 || index == 2;

    return GestureDetector(
      onTap: () {
        setState(() => _activeStatIndex = index);
        if (index == 0) {
          _showSetTotalMoneyDialog();
        } else if (index == 2) {
          _showSetBudgetDialog();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 155,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppTheme.monexBlue
              : (isDark ? const Color(0xFF131A29) : Colors.white),
          borderRadius: BorderRadius.circular(22),
          border: isHighlighted
              ? null
              : Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9),
                  width: 1.5,
                ),
          boxShadow: isHighlighted ? AppTheme.heroBlueShadow : (isDark ? [] : AppTheme.cardShadow),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon in small square container
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? Colors.white.withValues(alpha: 0.2)
                        : (isDark ? const Color(0xFF1A2234) : const Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isHighlighted
                        ? Colors.white
                        : (isDark ? const Color(0xFF38BDF8) : AppTheme.textPrimary),
                    size: 18,
                  ),
                ),
                if (isEditable)
                  Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: isHighlighted ? Colors.white70 : const Color(0xFF98A2B3),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isHighlighted
                        ? Colors.white70
                        : (isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isHighlighted
                        ? Colors.white
                        : (isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary),
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isHighlighted
                          ? Colors.white.withValues(alpha: 0.8)
                          : (isDark ? const Color(0xFF64748B) : const Color(0xFF98A2B3)),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    bool showCheck = false,
  }) {
    final isDark = AppTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppTheme.monexBlue.withValues(alpha: 0.25) : const Color(0xFFEFF4FF))
                : (isDark ? const Color(0xFF131A29) : Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? AppTheme.monexBlue
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC)),
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.monexBlue.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : (isDark
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF101828).withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showCheck && isSelected) ...[
                const Icon(Icons.check_rounded, size: 14, color: AppTheme.monexBlue),
                const SizedBox(width: 5),
              ] else if (icon != null) ...[
                Icon(icon, size: 14, color: isSelected ? AppTheme.monexBlue : (isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary)),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? AppTheme.monexBlue
                      : (isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    final isDark = AppTheme.isDark(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A29) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC), width: 1.1),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF101828).withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 19),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
