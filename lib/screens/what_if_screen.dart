import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/currency_service.dart';
import '../services/what_if_simulator.dart';
import '../theme/app_theme.dart';

class WhatIfScreen extends StatefulWidget {
  const WhatIfScreen({super.key});

  @override
  State<WhatIfScreen> createState() => _WhatIfScreenState();
}

class _WhatIfScreenState extends State<WhatIfScreen> {
  double _monthlySavings = 150.0;
  double _annualReturnRate = 0.09; // 9% market average
  String _selectedHabit = '☕ Daily Specialty Coffee';

  final Map<String, double> _habitPresets = {
    '☕ Daily Specialty Coffee': 150.0,
    '🍕 Restaurant Dining Cutback': 250.0,
    '📱 Unused Subscriptions': 60.0,
    '🛍️ Impulse Online Shopping': 200.0,
    '🚖 Rideshare vs Public Transit': 120.0,
  };

  void _applyPreset(String habit, double amount) {
    setState(() {
      _selectedHabit = habit;
      _monthlySavings = amount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final currency = NumberFormat.currency(symbol: currencySymbol, locale: 'en_US', decimalDigits: 0);

    final result = WhatIfSimulator.calculateProjections(
      monthlySavings: _monthlySavings,
      annualReturnRate: _annualReturnRate,
    );

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
          'What-If Wealth Simulator',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Projections Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.monexBlue,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.monexBlue.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '5-Year Future Wealth',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${(_annualReturnRate * 100).toInt()}% CAGR',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currency.format(result.year5Value),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'If you save ${currency.format(_monthlySavings)}/mo invested at ${(_annualReturnRate * 100).toInt()}% annual compounding return.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 1-Yr, 3-Yr, 5-Yr Comparison Cards
            Row(
              children: [
                _buildProjectionStat('1 Year', currency.format(result.year1Value)),
                const SizedBox(width: 10),
                _buildProjectionStat('3 Years', currency.format(result.year3Value)),
                const SizedBox(width: 10),
                _buildProjectionStat('5 Years', currency.format(result.year5Value)),
              ],
            ),

            const SizedBox(height: 28),

            // Interactive Savings Slider
            Container(
              padding: const EdgeInsets.all(18),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Savings Amount',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        currency.format(_monthlySavings),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppTheme.monexBlue,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _monthlySavings,
                    min: 20.0,
                    max: 2000.0,
                    divisions: 198,
                    activeColor: AppTheme.monexBlue,
                    inactiveColor: const Color(0xFFE4E7EC),
                    onChanged: (val) {
                      setState(() => _monthlySavings = val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Habit Presets
            Text(
              'Habit Cutback Presets',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._habitPresets.entries.map((e) {
              final isSelected = _selectedHabit == e.key;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.monexBlue : const Color(0xFFF1F3F9),
                    width: 1.2,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    e.key,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppTheme.monexBlue : AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  trailing: Text(
                    '+${currency.format(e.value)}/mo',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppTheme.monexBlue : AppTheme.successGreen,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () => _applyPreset(e.key, e.value),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionStat(String title, String amount) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F3F9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF101828).withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF667085),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
