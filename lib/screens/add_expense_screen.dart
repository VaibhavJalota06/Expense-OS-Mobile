import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../services/currency_service.dart';
import '../theme/app_theme.dart';

class AddExpenseSheet extends StatefulWidget {
  final Expense? expenseToEdit;
  final Function(Expense) onSave;

  const AddExpenseSheet({
    super.key,
    this.expenseToEdit,
    required this.onSave,
  });

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;

  String _selectedCategory = 'Food & Dining';
  String _selectedType = 'expense';
  String _selectedPaymentMethod = 'Google Pay';
  DateTime _selectedDate = DateTime.now();

  // Expense Categories & Icons
  static const List<Map<String, String>> _expenseCategories = [
    {'name': 'Food & Dining', 'icon': '🍔'},
    {'name': 'Transport / Uber', 'icon': '🚗'},
    {'name': 'Shopping', 'icon': '🛍️'},
    {'name': 'Rent & Housing', 'icon': '🏠'},
    {'name': 'Bills & Utilities', 'icon': '💡'},
    {'name': 'Entertainment', 'icon': '🍿'},
    {'name': 'Health & Medical', 'icon': '💊'},
    {'name': 'Education', 'icon': '🎓'},
    {'name': 'Groceries', 'icon': '🛒'},
    {'name': 'Travel', 'icon': '✈️'},
    {'name': 'Other Expense', 'icon': '⚙️'},
  ];

  // Income Categories & Icons
  static const List<Map<String, String>> _incomeCategories = [
    {'name': 'Salary', 'icon': '💼'},
    {'name': 'Freelance', 'icon': '💻'},
    {'name': 'Investments', 'icon': '📈'},
    {'name': 'Business', 'icon': '🏪'},
    {'name': 'Bonus / Gift', 'icon': '🎁'},
    {'name': 'Rental Income', 'icon': '🏠'},
    {'name': 'Side Hustle', 'icon': '💰'},
    {'name': 'Crypto & Trading', 'icon': '🪙'},
    {'name': 'Cashback & Refund', 'icon': '🏷️'},
    {'name': 'Other Income', 'icon': '💵'},
  ];

  // Payment Methods for Expenses (Paid Via)
  static const List<String> _expensePaymentMethods = [
    'Google Pay',
    'Credit Card',
    'Debit Card',
    'Cash',
    'Paytm / UPI',
    'Bank Transfer',
  ];

  // Account Methods for Income (Received Into)
  static const List<String> _incomePaymentMethods = [
    'Bank Account',
    'Google Pay / UPI',
    'Cash in Hand',
    'Savings Account',
    'PayPal',
    'Direct Deposit',
  ];

  List<Map<String, String>> get _currentCategories =>
      _selectedType == 'expense' ? _expenseCategories : _incomeCategories;

  List<String> get _currentPaymentMethods =>
      _selectedType == 'expense' ? _expensePaymentMethods : _incomePaymentMethods;

  @override
  void initState() {
    super.initState();
    final edit = widget.expenseToEdit;
    _titleController = TextEditingController(text: edit?.title ?? '');
    _amountController = TextEditingController(
      text: edit != null ? edit.amount.toStringAsFixed(0) : '',
    );
    _noteController = TextEditingController(text: edit?.notes ?? '');
    if (edit != null) {
      _selectedType = edit.type;
      _selectedCategory = edit.category;
      _selectedPaymentMethod = edit.paymentMethod;
      _selectedDate = edit.date;
    } else {
      _selectedType = 'expense';
      _selectedCategory = _expenseCategories.first['name']!;
      _selectedPaymentMethod = _expensePaymentMethods.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _switchType(String type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      if (type == 'expense') {
        _selectedCategory = _expenseCategories.first['name']!;
        _selectedPaymentMethod = _expensePaymentMethods.first;
      } else {
        _selectedCategory = _incomeCategories.first['name']!;
        _selectedPaymentMethod = _incomePaymentMethods.first;
      }
    });
  }

  void _submitForm() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    if (_selectedType == 'expense') {
      final prefs = await SharedPreferences.getInstance();
      final budgetCap = prefs.getDouble('monthly_budget_cap') ?? 0.0;
      if (budgetCap <= 0) {
        if (!mounted) return;
        _showSetBudgetRequiredDialog();
        return;
      }
    }

    final title = _titleController.text.trim().isEmpty ? _selectedCategory : _titleController.text.trim();

    final expense = Expense(
      id: widget.expenseToEdit?.id,
      title: title,
      amount: amount,
      category: _selectedCategory,
      type: _selectedType,
      date: _selectedDate,
      paymentMethod: _selectedPaymentMethod,
      notes: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
    );

    widget.onSave(expense);
    Navigator.of(context).pop();
  }

  void _showSetBudgetRequiredDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.monexBlue, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Set Monthly Budget First',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please set your monthly budget limit before logging expenses so Expense OS can track your budget progress!',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Monthly Budget Limit (${CurrencyService.currencySymbolNotifier.value})',
                hintText: 'e.g. 10000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.monexBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final val = double.tryParse(controller.text.trim()) ?? 0.0;
              if (val > 0) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('monthly_budget_cap', val);
                if (ctx.mounted) Navigator.pop(ctx);
                _submitForm();
              }
            },
            child: Text('Set Budget & Save', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _selectedType == 'expense';
    final activeColor = isExpense ? AppTheme.monexBlue : const Color(0xFF10B981);
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD0D5DD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.expenseToEdit != null
                      ? (isExpense ? 'Edit Expense' : 'Edit Income Entry')
                      : (isExpense ? 'Log Expense' : 'Log Income Entry'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF667085)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEAECF0)),

          // Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type Switch: Expense vs Income
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: Row(
                        children: [
                          // Expense Tab
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _switchType('expense'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: isExpense ? AppTheme.monexBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isExpense
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.monexBlue.withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('💸', style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Expense',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: isExpense ? Colors.white : const Color(0xFF667085),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Income Tab
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _switchType('income'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: !isExpense ? const Color(0xFF10B981) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: !isExpense
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('💰', style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Income',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: !isExpense ? Colors.white : const Color(0xFF667085),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Amount Field
                    Text(
                      isExpense ? 'Expense Amount' : 'Income Amount',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextInput(
                      controller: _amountController,
                      hint: '0',
                      prefixText: '$currencySymbol ',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      accentColor: activeColor,
                    ),

                    const SizedBox(height: 20),

                    // Category Selection Chips (Context-Aware)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isExpense ? 'Expense Category' : 'Income Source Category',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF667085),
                          ),
                        ),
                        Text(
                          'Select one',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF98A2B3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _currentCategories.map((catMap) {
                        final catName = catMap['name']!;
                        final catIcon = catMap['icon']!;
                        final isSelected = _selectedCategory == catName;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = catName),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected ? activeColor : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? activeColor : const Color(0xFFE4E7EC),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: activeColor.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(catIcon, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  catName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Title / Description
                    Text(
                      isExpense ? 'Expense Description' : 'Income Source Description',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextInput(
                      controller: _titleController,
                      hint: isExpense
                          ? 'e.g. Starbucks, Grocery run, Uber ride'
                          : 'e.g. Monthly Salary, Freelance project, Dividend',
                      accentColor: activeColor,
                    ),

                    const SizedBox(height: 20),

                    // Payment / Account Method Dropdown
                    Text(
                      isExpense ? 'Paid Via (Payment Method)' : 'Received Into (Account / Wallet)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currentPaymentMethods.contains(_selectedPaymentMethod)
                              ? _selectedPaymentMethod
                              : _currentPaymentMethods.first,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF667085)),
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          items: _currentPaymentMethods.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedPaymentMethod = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Date Picker Tile
                    Text(
                      isExpense ? 'Expense Date' : 'Income Deposit Date',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE4E7EC)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(_selectedDate),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF667085)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeColor,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: activeColor.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          widget.expenseToEdit != null
                              ? 'SAVE CHANGES'
                              : (isExpense ? 'LOG EXPENSE' : 'RECORD INCOME'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hint,
    String? prefixText,
    TextInputType? keyboardType,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: (keyboardType?.toString().contains('number') ?? false)
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))]
            : null,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF98A2B3), fontSize: 13),
          prefixText: prefixText,
          prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: accentColor),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
