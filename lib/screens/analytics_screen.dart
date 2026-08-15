import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import '../services/currency_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Expense> _expenses = [];
  bool _isLoading = true;
  double _monthlyBudgetCap = 0.0;

  @override
  void initState() {
    super.initState();
    SupabaseService.refreshNotifier.addListener(_loadData);
    _loadBudgetCap();
    _loadData();
  }

  @override
  void dispose() {
    SupabaseService.refreshNotifier.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadBudgetCap() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _monthlyBudgetCap = prefs.getDouble('monthly_budget_cap') ?? 0.0;
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    _loadBudgetCap();
    if (_expenses.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final data = await _supabaseService.getExpenses();
      if (!mounted) return;
      setState(() {
        _expenses = data.isNotEmpty ? data : _supabaseService.localExpenses;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _expenses = _supabaseService.localExpenses;
        _isLoading = false;
      });
    }
  }

  Map<String, double> get _categoryTotals {
    final Map<String, double> map = {};
    for (var item in _expenses) {
      if (item.type == 'expense') {
        map[item.category] = (map[item.category] ?? 0.0) + item.amount;
      }
    }
    return map;
  }

  double get _totalExpenses => _expenses
      .where((e) => e.type == 'expense')
      .fold(0.0, (sum, item) => sum + item.amount);

  @override
  Widget build(BuildContext context) {
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final currency = NumberFormat.currency(symbol: currencySymbol, locale: 'en_US', decimalDigits: 2);
    final categoryMap = _categoryTotals;

    final List<Color> chartColors = [
      AppTheme.monexBlue,
      const Color(0xFF12B76A),
      const Color(0xFF7A5AF8),
      const Color(0xFFF79009),
      const Color(0xFFEE46BC),
      const Color(0xFF0BA5EC),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Financial Analytics',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.monexBlue))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Summary Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
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
                                Text('Total Spent', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF667085), fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    currency.format(_totalExpenses),
                                    style: GoogleFonts.plusJakartaSans(color: AppTheme.dangerRed, fontSize: 18, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
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
                                Text('Budget Cap', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF667085), fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    currency.format(_monthlyBudgetCap),
                                    style: GoogleFonts.plusJakartaSans(color: AppTheme.monexBlue, fontSize: 18, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Category Breakdown Pie Chart
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F3F9), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF101828).withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spending by Category',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (categoryMap.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40.0),
                              child: Center(
                                child: Text(
                                  'No expense entries recorded yet.\nLog transactions to see chart breakdown.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 200,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 40,
                                  sections: categoryMap.entries.toList().asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final catEntry = entry.value;
                                    final color = chartColors[index % chartColors.length];
                                    final pct = _totalExpenses > 0 ? (catEntry.value / _totalExpenses) * 100 : 0.0;
                                    return PieChartSectionData(
                                      color: color,
                                      value: catEntry.value,
                                      title: '${pct.toStringAsFixed(0)}%',
                                      radius: 45,
                                      titleStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Category Legend List
                    if (categoryMap.isNotEmpty) ...[
                      Text(
                        'Category Breakdown',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      ...categoryMap.entries.toList().asMap().entries.map((entry) {
                        final index = entry.key;
                        final catEntry = entry.value;
                        final color = chartColors[index % chartColors.length];
                        final pct = _totalExpenses > 0 ? (catEntry.value / _totalExpenses) * 100 : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFF1F3F9), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  catEntry.key,
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(1)}% • ${currency.format(catEntry.value)}',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF667085)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
