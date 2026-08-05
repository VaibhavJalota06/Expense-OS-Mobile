import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../models/subscription_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final List<SubscriptionItem> _subscriptions = [];

  double get _totalMonthlyCost {
    return _subscriptions.fold(0.0, (sum, item) {
      return sum + (item.cycle == 'yearly' ? item.amount / 12 : item.amount);
    });
  }

  void _showAddSubscriptionSheet() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String category = 'Services & Subscriptions';
    String cycle = 'monthly';
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 7));

    final List<String> categories = [
      'Services & Subscriptions',
      'Bills & Utilities',
      'Housing',
      'Entertainment',
      'Health & Fitness',
      'Miscellaneous',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Recurring Subscription / Bill',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    TextField(
                      controller: titleController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.sentences,
                      style: GoogleFonts.poppins(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Subscription / Bill Name',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cost
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      style: GoogleFonts.poppins(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: category,
                      dropdownColor: const Color(0xFF0F172A),
                      style: GoogleFonts.poppins(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: categories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Billing Cycle Dropdown (Monthly vs Yearly)
                    DropdownButtonFormField<String>(
                      value: cycle,
                      dropdownColor: const Color(0xFF0F172A),
                      style: GoogleFonts.poppins(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Billing Cycle',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => cycle = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Due Date Picker Button
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDueDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDueDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: AppTheme.accentCyan, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Due Date: ${DateFormat('MMM dd, yyyy').format(selectedDueDate)}',
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    ElevatedButton(
                      onPressed: () {
                        if (titleController.text.isEmpty || amountController.text.isEmpty) return;
                        final newSub = SubscriptionItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text.trim(),
                          amount: double.tryParse(amountController.text) ?? 0.0,
                          category: category,
                          cycle: cycle,
                          dueDate: selectedDueDate,
                        );

                        setState(() {
                          _subscriptions.add(newSub);
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.accentCyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('SAVE SUBSCRIPTION', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(
          'Bills & Subscriptions',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSubscriptionSheet,
        backgroundColor: AppTheme.accentCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: Text('Add Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Summary Header Card
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Monthly Bills', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13)),
                        const Icon(Icons.receipt_long, color: AppTheme.accentCyan),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currency.format(_totalMonthlyCost),
                        style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Colors.amber, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${_subscriptions.length} Active recurring subscriptions',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Upcoming Payment Reminders',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              // Subscriptions List
              Expanded(
                child: _subscriptions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.subscriptions_outlined, size: 54, color: AppTheme.textSecondary),
                            const SizedBox(height: 12),
                            Text(
                              'No subscriptions added yet.',
                              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Add Bill" below to track recurring payments.',
                              style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _subscriptions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _subscriptions[index];
                          final now = DateTime.now();
                          final daysLeft = item.dueDate.difference(now).inDays;
                          final isExpiringSoon = !item.isPaid && daysLeft >= 0 && daysLeft <= 7;
                          final isOverdue = !item.isPaid && daysLeft < 0;

                          return GlassCard(
                            child: Row(
                              children: [
                                // Category / Status Badge Icon
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: item.isPaid
                                        ? AppTheme.emerald.withOpacity(0.15)
                                        : (isOverdue
                                            ? AppTheme.accentRed.withOpacity(0.15)
                                            : AppTheme.accentCyan.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item.isPaid
                                        ? Icons.check_circle_outline
                                        : (isOverdue ? Icons.warning_amber_rounded : Icons.subscriptions_outlined),
                                    color: item.isPaid
                                        ? AppTheme.emerald
                                        : (isOverdue ? AppTheme.accentRed : AppTheme.accentCyan),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Details: Title, Due / Paid status & Expiring Soon tag
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.title,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isExpiringSoon) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.amber.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppTheme.amber.withOpacity(0.5)),
                                              ),
                                              child: Text(
                                                'Expiring Soon',
                                                style: GoogleFonts.poppins(color: AppTheme.amber, fontSize: 9, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                          if (isOverdue) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.accentRed.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppTheme.accentRed.withOpacity(0.5)),
                                              ),
                                              child: Text(
                                                'Overdue',
                                                style: GoogleFonts.poppins(color: AppTheme.accentRed, fontSize: 9, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),

                                      // Subtitle: Due Date & Month Expiration Notice
                                      Text(
                                        item.isPaid
                                            ? 'Paid for this month • Next due ${DateFormat("MMM dd, yyyy").format(item.dueDate)}'
                                            : (daysLeft <= 0
                                                ? 'Due Today (${DateFormat("MMM dd").format(item.dueDate)})'
                                                : 'Due in $daysLeft days (${DateFormat("MMM dd").format(item.dueDate)})'),
                                        style: GoogleFonts.poppins(
                                          color: item.isPaid
                                              ? AppTheme.emerald
                                              : (daysLeft <= 3 ? AppTheme.accentRed : AppTheme.textSecondary),
                                          fontSize: 12,
                                          fontWeight: item.isPaid ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Amount & Pay Now / Paid Button
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currency.format(item.amount),
                                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: item.isPaid
                                          ? null // Already paid
                                          : () async {
                                              final newExpense = Expense(
                                                title: item.title,
                                                amount: item.amount,
                                                category: item.category,
                                                type: 'expense',
                                                date: DateTime.now(),
                                                paymentMethod: item.paymentMethod,
                                              );
                                              await _supabaseService.addExpense(newExpense);

                                              // Advance due date by 1 month or 1 year
                                              final nextDueDate = item.cycle == 'yearly'
                                                  ? DateTime(item.dueDate.year + 1, item.dueDate.month, item.dueDate.day)
                                                  : DateTime(item.dueDate.year, item.dueDate.month + 1, item.dueDate.day);

                                              setState(() {
                                                _subscriptions[index] = item.copyWith(
                                                  isPaid: true,
                                                  lastPaidDate: DateTime.now(),
                                                  dueDate: nextDueDate,
                                                );
                                              });

                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Logged ${item.title} payment (${currency.format(item.amount)}) in Expenses!'),
                                                    backgroundColor: AppTheme.emerald,
                                                  ),
                                                );
                                              }
                                            },
                                      borderRadius: BorderRadius.circular(8),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: item.isPaid
                                              ? AppTheme.emerald.withOpacity(0.2)
                                              : AppTheme.accentCyan.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: item.isPaid
                                                ? AppTheme.emerald.withOpacity(0.6)
                                                : AppTheme.accentCyan.withOpacity(0.4),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (item.isPaid) ...[
                                              const Icon(Icons.check, size: 12, color: AppTheme.emerald),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              item.isPaid ? 'PAID ✓' : 'PAY NOW',
                                              style: GoogleFonts.poppins(
                                                color: item.isPaid ? AppTheme.emerald : AppTheme.accentCyan,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
