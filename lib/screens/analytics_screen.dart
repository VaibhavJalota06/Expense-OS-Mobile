import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _supabaseService.getExpenses();
    setState(() {
      _expenses = data;
      _isLoading = false;
    });
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

  double get _totalIncome => _expenses
      .where((e) => e.type == 'income')
      .fold(0.0, (sum, item) => sum + item.amount);

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2);
    final categoryMap = _categoryTotals;

    final List<Color> chartColors = [
      const Color(0xFF34D399),
      const Color(0xFF38BDF8),
      const Color(0xFFA78BFA),
      const Color(0xFFFBBF24),
      const Color(0xFFF472B6),
      const Color(0xFFFB923C),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(
          'Financial Analytics',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Summary Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Spent', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  currency.format(_totalExpenses),
                                  style: GoogleFonts.poppins(color: AppTheme.accentRed, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Income', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  currency.format(_totalIncome),
                                  style: GoogleFonts.poppins(color: AppTheme.accentGreen, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Donut Chart Header
                    Text(
                      'Expense Category Breakdown',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Donut Chart Container
                    GlassCard(
                      child: categoryMap.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Center(
                                child: Text(
                                  'Add expenses to view category analytics',
                                  style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                SizedBox(
                                  height: 200,
                                  child: PieChart(
                                    PieChartData(
                                      sectionsSpace: 4,
                                      centerSpaceRadius: 50,
                                      sections: categoryMap.entries.toList().asMap().entries.map((entry) {
                                        final idx = entry.key;
                                        final val = entry.value;
                                        final percentage = _totalExpenses > 0 ? (val.value / _totalExpenses) * 100 : 0.0;

                                        return PieChartSectionData(
                                          color: chartColors[idx % chartColors.length],
                                          value: val.value,
                                          title: '${percentage.toStringAsFixed(0)}%',
                                          radius: 35,
                                          titleStyle: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Category Legends
                                ...categoryMap.entries.toList().asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final val = entry.value;
                                  final color = chartColors[idx % chartColors.length];

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(val.key, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
                                          ],
                                        ),
                                        Text(
                                          currency.format(val.value),
                                          style: GoogleFonts.poppins(color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
