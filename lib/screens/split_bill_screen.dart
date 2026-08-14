import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/currency_service.dart';
import '../theme/app_theme.dart';

class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final TextEditingController _titleController = TextEditingController(text: 'Group Dinner');
  final TextEditingController _totalAmountController = TextEditingController(text: '120.00');
  final TextEditingController _payerController = TextEditingController(text: 'You');
  final TextEditingController _newMemberController = TextEditingController();

  final List<String> _members = ['You', 'Alex', 'Sarah', 'Mike'];

  @override
  void dispose() {
    _titleController.dispose();
    _totalAmountController.dispose();
    _payerController.dispose();
    _newMemberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _newMemberController.text.trim();
    if (name.isNotEmpty && !_members.contains(name)) {
      setState(() {
        _members.add(name);
        _newMemberController.clear();
      });
    }
  }

  void _removeMember(int index) {
    if (_members.length > 1) {
      setState(() {
        _members.removeAt(index);
      });
    }
  }

  double get _totalAmount => double.tryParse(_totalAmountController.text) ?? 0.0;
  double get _perPerson => _members.isEmpty ? 0 : _totalAmount / _members.length;

  String _formatWhatsAppSummary() {
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final StringBuffer sb = StringBuffer();
    sb.writeln('🧾 *EXPENSE OS BILL SPLIT SUMMARY* 🧾');
    sb.writeln('-----------------------------------');
    sb.writeln('Event: *${_titleController.text}*');
    sb.writeln('Total Amount: *$currencySymbol${_totalAmount.toStringAsFixed(2)}*');
    sb.writeln('Paid by: *${_payerController.text}*');
    sb.writeln('Split among ${_members.length} people:');
    sb.writeln('-----------------------------------');
    for (var m in _members) {
      if (m.toLowerCase() == _payerController.text.toLowerCase() || m == 'You') {
        sb.writeln('• $m (Payer / Settled)');
      } else {
        sb.writeln('• $m owes *$currencySymbol${_perPerson.toStringAsFixed(2)}*');
      }
    }
    sb.writeln('-----------------------------------');
    sb.writeln('Sent via Expense OS Mobile Command Center 🚀');
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final currency = NumberFormat.currency(symbol: currencySymbol, locale: 'en_US', decimalDigits: 2);

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
          'Split Bill & Group Expense',
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
            // Total & Split Header Card
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
                children: [
                  Text(
                    'Per Person Share',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currency.format(_perPerson),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Total ${currency.format(_totalAmount)} ÷ ${_members.length} people',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bill Details Input
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
                  Text(
                    'Bill Details',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Event / Bill Title',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _totalAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.monexBlue),
                    decoration: InputDecoration(
                      prefixText: '$currencySymbol ',
                      labelText: 'Total Bill Amount',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Members List & Add
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
                  Text(
                    'Group Members (${_members.length})',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newMemberController,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Add friend name',
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _addMember,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.monexBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Icon(Icons.add, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _members.asMap().entries.map((entry) {
                      final i = entry.key;
                      final name = entry.value;
                      return Chip(
                        label: Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                        backgroundColor: const Color(0xFFEEF2FF),
                        labelStyle: const TextStyle(color: AppTheme.monexBlue),
                        deleteIcon: i == 0 ? null : const Icon(Icons.close, size: 16, color: AppTheme.monexBlue),
                        onDeleted: i == 0 ? null : () => _removeMember(i),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Share Summary Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  final summary = _formatWhatsAppSummary();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Bill Split Summary', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
                      content: SingleChildScrollView(
                        child: SelectableText(summary, style: GoogleFonts.ibmPlexMono(fontSize: 12)),
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Summary copied to clipboard!', style: GoogleFonts.plusJakartaSans()),
                                backgroundColor: AppTheme.monexBlue,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.monexBlue, foregroundColor: Colors.white),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.share_rounded),
                label: Text('SHARE SPLIT SUMMARY', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.monexBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
