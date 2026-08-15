import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import '../services/currency_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/expense_tile.dart';
import 'add_expense_screen.dart';

class CalendarExpensesScreen extends StatefulWidget {
  const CalendarExpensesScreen({super.key});

  @override
  State<CalendarExpensesScreen> createState() => _CalendarExpensesScreenState();
}

class _CalendarExpensesScreenState extends State<CalendarExpensesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Expense> _allExpenses = [];
  bool _isLoading = true;
  double _monthlyBudgetCap = 0.0;

  DateTime _selectedDate = DateTime.now();
  DateTime _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _selectedTab = 0; // 0 = Spends, 1 = Categories

  @override
  void initState() {
    super.initState();
    SupabaseService.refreshNotifier.addListener(_loadExpenses);
    _loadExpenses();
  }

  @override
  void dispose() {
    SupabaseService.refreshNotifier.removeListener(_loadExpenses);
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    if (_allExpenses.isEmpty) {
      setState(() => _isLoading = true);
    }
    final prefs = await SharedPreferences.getInstance();
    final cap = prefs.getDouble('monthly_budget_cap') ?? 0.0;

    try {
      final data = await _supabaseService.getExpenses().timeout(const Duration(milliseconds: 1200));
      if (!mounted) return;
      setState(() {
        _allExpenses = data.isNotEmpty ? data : _supabaseService.localExpenses;
        _monthlyBudgetCap = cap;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allExpenses = _supabaseService.localExpenses;
        _monthlyBudgetCap = cap;
        _isLoading = false;
      });
    }
  }

  double get _totalMonthSpent {
    return _allExpenses
        .where((e) =>
            e.type == 'expense' &&
            e.date.year == _displayedMonth.year &&
            e.date.month == _displayedMonth.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get _totalSelectedDaySpent {
    return _filteredDailyExpenses.fold(0.0, (sum, e) => sum + e.amount);
  }

  Set<int> get _daysWithExpensesInMonth {
    final set = <int>{};
    for (var e in _allExpenses) {
      if (e.type == 'expense' &&
          e.date.year == _displayedMonth.year &&
          e.date.month == _displayedMonth.month) {
        set.add(e.date.day);
      }
    }
    return set;
  }

  String get _budgetSubtext {
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    if (_monthlyBudgetCap <= 0) {
      return 'Log transactions daily to track your monthly budget';
    }
    final pct = ((_totalMonthSpent / _monthlyBudgetCap) * 100).clamp(0.0, 999.0).toStringAsFixed(0);
    return 'Spent $pct% of monthly budget ($currencySymbol${_totalMonthSpent.toStringAsFixed(0)} / $currencySymbol${_monthlyBudgetCap.toStringAsFixed(0)})';
  }

  List<Expense> get _filteredDailyExpenses {
    return _allExpenses.where((e) {
      return e.date.year == _selectedDate.year &&
          e.date.month == _selectedDate.month &&
          e.date.day == _selectedDate.day;
    }).toList();
  }

  Map<String, double> get _categoryBreakdown {
    final map = <String, double>{};
    for (var e in _allExpenses.where((e) =>
        e.type == 'expense' &&
        e.date.year == _displayedMonth.year &&
        e.date.month == _displayedMonth.month)) {
      map[e.category] = (map[e.category] ?? 0.0) + e.amount;
    }
    return map;
  }

  void _prevMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
        _selectedDate = picked;
        _displayedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  void _openAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddExpenseSheet(
        onSave: (expense) async {
          await _supabaseService.addExpense(expense);
          _loadExpenses();
        },
      ),
    );
  }

  bool get _isTodaySelected {
    final now = DateTime.now();
    return _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final currency = NumberFormat.currency(symbol: currencySymbol, locale: 'en_US', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Total Expenses',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.monexBlue, size: 22),
            onPressed: _pickDate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpenseSheet,
        backgroundColor: AppTheme.monexBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Log Expense', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.monexBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                children: [
                  // Calendar Card Container
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Column(
                      children: [
                        // Month Header Selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF667085)),
                              onPressed: _prevMonth,
                            ),
                            GestureDetector(
                              onTap: _pickDate,
                              child: Row(
                                children: [
                                  Text(
                                    DateFormat('MMMM - yyyy').format(_displayedMonth),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.monexBlue),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF667085)),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Weekdays Row: Mo Tu We Th Fr Sa Su
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'].map((day) {
                            return SizedBox(
                              width: 38,
                              child: Text(
                                day,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF98A2B3),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),

                        // Days Row
                        _buildDaysRow(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Center Hero Blue Circular Badge showing Selected Day Spend
                  Container(
                    width: 145,
                    height: 145,
                    decoration: BoxDecoration(
                      color: AppTheme.monexBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.monexBlue.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('MMM d').format(_selectedDate),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currency.format(_totalSelectedDaySpent),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Day Spend',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Subtext / Budget Status
                  Text(
                    _budgetSubtext,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  if (!_isTodaySelected) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = DateTime.now();
                          _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.monexBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Go to Today',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.monexBlue),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Tabs: "Spends" | "Categories"
                  Row(
                    children: [
                      _buildTabItem(title: 'Spends (${_filteredDailyExpenses.length})', index: 0),
                      const SizedBox(width: 24),
                      _buildTabItem(title: 'Categories (${_categoryBreakdown.length})', index: 1),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tab Content
                  if (_selectedTab == 0)
                    if (_filteredDailyExpenses.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF1F3F9)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 40, color: Color(0xFFD0D5DD)),
                            const SizedBox(height: 12),
                            Text(
                              'No transactions logged for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._filteredDailyExpenses.map((expense) => ExpenseTile(expense: expense))
                  else
                    if (_categoryBreakdown.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF1F3F9)),
                        ),
                        child: Center(
                          child: Text(
                            'No expense categories logged for ${DateFormat('MMMM yyyy').format(_displayedMonth)}.',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._categoryBreakdown.entries.map((entry) {
                        final totalSpent = _totalMonthSpent;
                        final pct = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFF1F3F9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppTheme.monexBlue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(_getCategoryIcon(entry.key), color: AppTheme.monexBlue, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.key,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '${pct.toStringAsFixed(1)}% of month',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    currency.format(entry.value),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: totalSpent > 0 ? (entry.value / totalSpent).clamp(0.0, 1.0) : 0.0,
                                  backgroundColor: const Color(0xFFF1F3F9),
                                  color: AppTheme.monexBlue,
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
      case 'uber':
        return Icons.directions_car_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'bills & utilities':
      case 'rent':
        return Icons.receipt_rounded;
      case 'income':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildDaysRow() {
    final daysWithData = _daysWithExpensesInMonth;
    final selectedDayNum = _selectedDate.day;

    final days = <DateTime>[];
    for (int i = -3; i <= 3; i++) {
      days.add(_selectedDate.add(Duration(days: i)));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days.map((date) {
        final isSelected = date.day == selectedDayNum &&
            date.month == _selectedDate.month &&
            date.year == _selectedDate.year;

        final hasExpenses = date.month == _displayedMonth.month && daysWithData.contains(date.day);

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
              _displayedMonth = DateTime(date.year, date.month, 1);
            });
          },
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.monexBlue : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (date.month == _displayedMonth.month ? AppTheme.textPrimary : const Color(0xFFD0D5DD)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: hasExpenses ? (isSelected ? AppTheme.monexBlue : const Color(0xFFF04438)) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTabItem({required String title, required int index}) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppTheme.monexBlue : const Color(0xFF98A2B3),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.monexBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
