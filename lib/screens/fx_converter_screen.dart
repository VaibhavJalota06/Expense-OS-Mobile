import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class FXConverterScreen extends StatefulWidget {
  const FXConverterScreen({super.key});

  @override
  State<FXConverterScreen> createState() => _FXConverterScreenState();
}

class _FXConverterScreenState extends State<FXConverterScreen> {
  final TextEditingController _amountController = TextEditingController(text: '100');
  String _fromCurrency = 'USD';
  String _toCurrency = 'INR';

  final Map<String, double> _ratesAgainstUSD = {
    'USD': 1.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'INR': 83.45,
    'JPY': 156.20,
    'CAD': 1.37,
    'AUD': 1.51,
    'SGD': 1.35,
    'AED': 3.67,
  };

  final Map<String, String> _currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'JPY': '¥',
    'CAD': 'CA\$',
    'AUD': 'A\$',
    'SGD': 'S\$',
    'AED': 'AED',
  };

  double get _convertedAmount {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final fromRate = _ratesAgainstUSD[_fromCurrency] ?? 1.0;
    final toRate = _ratesAgainstUSD[_toCurrency] ?? 1.0;
    return (amount / fromRate) * toRate;
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'FX Currency Converter',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Converter Card
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From Currency Field
                  Text('From', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF667085))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE4E7EC)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _fromCurrency,
                              items: _ratesAgainstUSD.keys.map((c) => DropdownMenuItem(value: c, child: Text('$c (${_currencySymbols[c]})', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)))).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _fromCurrency = v);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Swap Button
                  Center(
                    child: IconButton(
                      onPressed: _swapCurrencies,
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.monexBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.swap_vert_rounded, color: AppTheme.monexBlue, size: 24),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // To Currency Field
                  Text('To', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF667085))),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE4E7EC)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _toCurrency,
                        isExpanded: true,
                        items: _ratesAgainstUSD.keys.map((c) => DropdownMenuItem(value: c, child: Text('$c (${_currencySymbols[c]})', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)))).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _toCurrency = v);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Result Hero Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.monexBlue,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppTheme.heroBlueShadow,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Estimated Conversion',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_currencySymbols[_toCurrency]} ${_convertedAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '1 $_fromCurrency = ${((_ratesAgainstUSD[_toCurrency] ?? 1.0) / (_ratesAgainstUSD[_fromCurrency] ?? 1.0)).toStringAsFixed(4)} $_toCurrency',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Live Rates Grid
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Popular Exchange Rates',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(height: 12),
            ..._ratesAgainstUSD.entries.where((e) => e.key != 'USD').map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F3F9)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1 USD', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text('${_currencySymbols[entry.key]} ${entry.value.toStringAsFixed(2)} ${entry.key}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.monexBlue)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
