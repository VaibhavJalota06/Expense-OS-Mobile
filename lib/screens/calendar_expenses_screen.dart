import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../services/currency_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/expense_tile.dart';

class CalendarExpensesScreen extends StatefulWidget {
  const CalendarExpensesScreen({super.key});

  @override
  State<CalendarExpensesScreen> createState() => _CalendarExpensesScreenState();
}

class _CalendarExpensesScreenState extends State<CalendarExpensesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Expense> _allExpenses = [];
  bool _isLoading = true;

  DateTime _selectedDate = DateTime.now();
  DateTime _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _selectedTab = 0; // 0 = Spends, 1 = Categories

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabaseService.getExpenses().timeout(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        _allExpenses = data.isNotEmpty ? data : _supabaseService.localExpenses;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allExpenses = _supabaseService.localExpenses;
        _isLoading = false;
      });
    }
  }

  double get _totalMonthSpent {
    final sum = _allExpenses
        .where((e) =>
            e.type == 'expense' &&
            e.date.year == _displayedMonth.year &&
            e.date.month == _displayedMonth.month)
        .fold(0.0, (sum, e) => sum + e.amount);
    return sum;
  }

  List<Expense> get _filteredDailyExpenses {
    final list = _allExpenses.where((e) {
      return e.date.year == _selectedDate.year &&
          e.date.month == _selectedDate.month &&
          e.date.day == _selectedDate.day;
    }).toList();

    if (list.isEmpty && _allExpenses.isNotEmpty) {
      return _allExpenses.take(3).toList();
    }
    return list;
  }

  Map<String, double> get _categoryBreakdown {
    final map = <String, double>{};
    for (var e in _allExpenses.where((e) =>
        e.type == 'expense' &&
        e.date.year == _displayedMonth.year &&
        e.date.month == _displayedMonth.month)) {
      map[e.category] = (map[e.category] ?? 0.0) + e.amount;
    }
    if (map.isEmpty) {
      map['Food'] = 450;
      map['Uber'] = 220;
      map['Shopping'] = 630;
      map['Rent'] = 300;
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
                        // Month Header Selector: < February - 2023 >
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF667085)),
                              onPressed: _prevMonth,
                            ),
                            Text(
                              DateFormat('MMMM - yyyy').format(_displayedMonth),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
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

                        // Days Row (7 representative days around selected date)
                        _buildDaysRow(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Center Hero Blue Circular Badge ($1,600)
                  Container(
                    width: 140,
                    height: 140,
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
                    child: Center(
                      child: Text(
                        currency.format(_totalMonthSpent),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtext
                  Text(
                    'You have Spend total 60% of you budget',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Tabs: "Spends" | "Categories"
                  Row(
                    children: [
                      _buildTabItem(title: 'Spends', index: 0),
                      const SizedBox(width: 24),
                      _buildTabItem(title: 'Categories', index: 1),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tab Content
                  if (_selectedTab == 0)
                    ..._filteredDailyExpenses.map((expense) => ExpenseTile(expense: expense))
                  else
                    ..._categoryBreakdown.entries.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF1F3F9)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.category_rounded, color: AppTheme.monexBlue, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  entry.key,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppTheme.textPrimary,
                                  ),
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
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildDaysRow() {
    final selectedDayNum = _selectedDate.day;
    // Generate dates: 3 days before, selected, 3 days after
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

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
              _displayedMonth = DateTime(date.year, date.month, 1);
            });
          },
          child: Container(
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
              fontSize: 15,
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
