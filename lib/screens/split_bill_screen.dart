import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import '../services/currency_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class GroupExpenseItem {
  final String id;
  final String title;
  final double totalAmount;
  final String paidBy;
  final List<String> members;
  final Map<String, double> customShares;
  final Map<String, bool> settledStatus; // member -> isSettled
  final DateTime date;

  GroupExpenseItem({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.paidBy,
    required this.members,
    required this.customShares,
    required this.settledStatus,
    required this.date,
  });

  factory GroupExpenseItem.fromJson(Map<String, dynamic> json) {
    return GroupExpenseItem(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'Group Expense',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidBy: json['paidBy'] ?? 'You',
      members: List<String>.from(json['members'] ?? ['You']),
      customShares: Map<String, double>.from(
        (json['customShares'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      ),
      settledStatus: Map<String, bool>.from(
        (json['settledStatus'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), v == true),
        ),
      ),
      date: json['date'] != null ? DateTime.parse(json['date'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'totalAmount': totalAmount,
    'paidBy': paidBy,
    'members': members,
    'customShares': customShares,
    'settledStatus': settledStatus,
    'date': date.toIso8601String(),
  };
}

class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _newMemberController = TextEditingController();

  final List<String> _members = ['You'];
  String _selectedPayer = 'You';
  bool _isUnequalSplit = false;
  final Map<String, TextEditingController> _customShareControllers = {};

  List<GroupExpenseItem> _savedGroupExpenses = [];

  @override
  void initState() {
    super.initState();
    _loadGroupExpenses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalAmountController.dispose();
    _newMemberController.dispose();
    for (var c in _customShareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadGroupExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_group_expenses');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List decoded = jsonDecode(raw);
        if (mounted) {
          setState(() {
            _savedGroupExpenses = decoded.map((e) => GroupExpenseItem.fromJson(e)).toList();
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _saveGroupExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_savedGroupExpenses.map((e) => e.toJson()).toList());
    await prefs.setString('saved_group_expenses', encoded);
  }

  void _addMember() {
    final name = _newMemberController.text.trim();
    if (name.isNotEmpty && !_members.contains(name)) {
      setState(() {
        _members.add(name);
        _customShareControllers[name] = TextEditingController();
        _newMemberController.clear();
      });
    }
  }

  void _removeMember(int index) {
    if (_members.length > 1) {
      final removed = _members[index];
      setState(() {
        _members.removeAt(index);
        if (_selectedPayer == removed) {
          _selectedPayer = _members.first;
        }
        _customShareControllers[removed]?.dispose();
        _customShareControllers.remove(removed);
      });
    }
  }

  double get _totalAmount => double.tryParse(_totalAmountController.text) ?? 0.0;
  double get _perPersonEqual => _members.isEmpty ? 0 : _totalAmount / _members.length;

  Map<String, double> _calculateFinalShares() {
    final Map<String, double> map = {};
    if (!_isUnequalSplit) {
      final equalShare = _perPersonEqual;
      for (var m in _members) {
        map[m] = equalShare;
      }
    } else {
      for (var m in _members) {
        final val = double.tryParse(_customShareControllers[m]?.text ?? '') ?? 0.0;
        map[m] = val;
      }
    }
    return map;
  }

  Future<void> _saveAndLogGroupExpense() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a bill title', style: GoogleFonts.plusJakartaSans()),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    if (_totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid bill total amount', style: GoogleFonts.plusJakartaSans()),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final shares = _calculateFinalShares();
    final Map<String, bool> settled = {};
    for (var m in _members) {
      settled[m] = (m == _selectedPayer);
    }

    final groupExpense = GroupExpenseItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      totalAmount: _totalAmount,
      paidBy: _selectedPayer,
      members: List.from(_members),
      customShares: shares,
      settledStatus: settled,
      date: DateTime.now(),
    );

    setState(() {
      _savedGroupExpenses.insert(0, groupExpense);
    });
    await _saveGroupExpenses();

    // Automatically log "My Share" into Supabase Expenses if "You" paid or owe
    final myShare = shares['You'] ?? _perPersonEqual;
    if (myShare > 0) {
      final expense = Expense(
        title: '$title (Group Share)',
        amount: myShare,
        category: 'Food & Dining',
        type: 'expense',
        date: DateTime.now(),
        paymentMethod: 'Card',
      );
      await _supabaseService.addExpense(expense);
    }

    if (mounted) {
      final symbol = CurrencyService.currencySymbolNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group expense saved & your share ($symbol${myShare.toStringAsFixed(2)}) logged to transactions!', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      _titleController.clear();
      _totalAmountController.clear();
      setState(() {});
    }
  }

  void _toggleSettled(String groupExpenseId, String member) {
    setState(() {
      final index = _savedGroupExpenses.indexWhere((e) => e.id == groupExpenseId);
      if (index != -1) {
        final item = _savedGroupExpenses[index];
        item.settledStatus[member] = !(item.settledStatus[member] ?? false);
      }
    });
    _saveGroupExpenses();
  }

  String _formatWhatsAppSummary() {
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final shares = _calculateFinalShares();
    final StringBuffer sb = StringBuffer();
    sb.writeln('🧾 *EXPENSE OS GROUP BILL SPLIT* 🧾');
    sb.writeln('-----------------------------------');
    sb.writeln('Event: *${_titleController.text.isEmpty ? 'Group Bill' : _titleController.text}*');
    sb.writeln('Total Amount: *$currencySymbol${_totalAmount.toStringAsFixed(2)}*');
    sb.writeln('Paid by: *$_selectedPayer*');
    sb.writeln('Split among ${_members.length} people:');
    sb.writeln('-----------------------------------');
    for (var m in _members) {
      final share = shares[m] ?? 0.0;
      if (m.toLowerCase() == _selectedPayer.toLowerCase()) {
        sb.writeln('• $m (Payer • $currencySymbol${share.toStringAsFixed(2)})');
      } else {
        sb.writeln('• $m owes *$currencySymbol${share.toStringAsFixed(2)}*');
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
    final shares = _calculateFinalShares();

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
          'Split Bill & Group Expenses',
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
            // Per Person Share Card
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
                    _isUnequalSplit ? 'Custom Split Total' : 'Per Person Equal Share',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isUnequalSplit ? currency.format(_totalAmount) : currency.format(_perPersonEqual),
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
                      'Paid by $_selectedPayer • ${_members.length} members',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bill Details Input Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F3F9), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bill Information',
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
                  const SizedBox(height: 14),

                  // Who Paid Dropdown Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Who Paid for this Bill?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                      DropdownButton<String>(
                        value: _members.contains(_selectedPayer) ? _selectedPayer : _members.first,
                        underline: const SizedBox(),
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.monexBlue, fontSize: 14),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPayer = val);
                          }
                        },
                        items: _members.map((m) {
                          return DropdownMenuItem(value: m, child: Text(m));
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Split Mode Switcher (Equal vs Custom Shares)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Custom Unequal Shares', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                      Switch(
                        value: _isUnequalSplit,
                        activeColor: AppTheme.monexBlue,
                        onChanged: (val) {
                          setState(() {
                            _isUnequalSplit = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Members List & Custom Share Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F3F9), width: 1.2),
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

                  // Member Shares Breakdown List
                  ...List.generate(_members.length, (index) {
                    final member = _members[index];
                    final share = shares[member] ?? 0.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.monexBlue.withValues(alpha: 0.1),
                            child: Text(
                              member[0].toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(color: AppTheme.monexBlue, fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              member + (member == _selectedPayer ? ' (Payer)' : ''),
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                            ),
                          ),
                          if (_isUnequalSplit)
                            SizedBox(
                              width: 90,
                              height: 38,
                              child: TextField(
                                controller: _customShareControllers[member] ??= TextEditingController(text: share.toStringAsFixed(2)),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  prefixText: '$currencySymbol',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            )
                          else
                            Text(
                              currency.format(share),
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary),
                            ),
                          if (index > 0)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                              onPressed: () => _removeMember(index),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons: Save to Database & Share Summary
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveAndLogGroupExpense,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text('SAVE & LOG EXPENSE', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.monexBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () {
                    final summary = _formatWhatsAppSummary();
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Share Bill Split Summary', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
                        content: SingleChildScrollView(
                          child: SelectableText(summary, style: GoogleFonts.ibmPlexMono(fontSize: 12)),
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.monexBlue, foregroundColor: Colors.white),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, color: AppTheme.monexBlue),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    side: const BorderSide(color: AppTheme.monexBlue, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Saved Active Group Expenses & Settlement Tracker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved Group Expenses (${_savedGroupExpenses.length})',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                if (_savedGroupExpenses.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _savedGroupExpenses.clear();
                      });
                      _saveGroupExpenses();
                    },
                    child: Text('Clear History', style: GoogleFonts.plusJakartaSans(color: AppTheme.dangerRed, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_savedGroupExpenses.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F3F9)),
                ),
                child: Center(
                  child: Text(
                    'No saved group expenses yet. Create one above!',
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              )
            else
              ..._savedGroupExpenses.map((group) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            group.title,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary),
                          ),
                          Text(
                            currency.format(group.totalAmount),
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.monexBlue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Paid by ${group.paidBy} • ${DateFormat('MMM dd, yyyy').format(group.date)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const Divider(height: 18, color: Color(0xFFF1F3F9)),

                      Text('Member Settlement Balances:', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),

                      ...group.members.map((m) {
                        final share = group.customShares[m] ?? (group.totalAmount / group.members.length);
                        final isSettled = group.settledStatus[m] ?? false;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isSettled ? Icons.check_circle_rounded : Icons.pending_rounded,
                                    size: 16,
                                    color: isSettled ? AppTheme.successGreen : AppTheme.warningOrange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$m: ${currency.format(share)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isSettled ? AppTheme.textSecondary : AppTheme.textPrimary,
                                      decoration: isSettled ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ],
                              ),
                              if (m != group.paidBy)
                                GestureDetector(
                                  onTap: () => _toggleSettled(group.id, m),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSettled ? const Color(0xFFF1F3F9) : const Color(0xFFECFDF3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isSettled ? 'Settled' : 'Mark Settled',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isSettled ? AppTheme.textSecondary : AppTheme.successGreen,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
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
