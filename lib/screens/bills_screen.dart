import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/subscription_model.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final List<SubscriptionItem> _subscriptions = [
    SubscriptionItem(
      id: '1',
      title: 'Netflix Premium',
      amount: 19.99,
      category: 'Services & Subscriptions',
      cycle: 'monthly',
      dueDate: DateTime.now().add(const Duration(days: 3)),
      paymentMethod: 'Credit Card',
    ),
    SubscriptionItem(
      id: '2',
      title: 'Spotify Family',
      amount: 14.99,
      category: 'Services & Subscriptions',
      cycle: 'monthly',
      dueDate: DateTime.now().add(const Duration(days: 7)),
      paymentMethod: 'PayPal',
    ),
    SubscriptionItem(
      id: '3',
      title: 'High Speed Fiber Internet',
      amount: 65.00,
      category: 'Bills & Utilities',
      cycle: 'monthly',
      dueDate: DateTime.now().add(const Duration(days: 12)),
      paymentMethod: 'Auto Debit',
    ),
    SubscriptionItem(
      id: '4',
      title: 'Cloud Server Hosting',
      amount: 29.00,
      category: 'Services & Subscriptions',
      cycle: 'monthly',
      dueDate: DateTime.now().add(const Duration(days: 18)),
      paymentMethod: 'Credit Card',
    ),
  ];

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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 24,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add Recurring Subscription',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: titleController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Subscription Title',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Cost (\$)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () {
                      if (titleController.text.isEmpty || amountController.text.isEmpty) return;
                      final newSub = SubscriptionItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text.trim(),
                        amount: double.tryParse(amountController.text) ?? 0.0,
                        category: category,
                        cycle: cycle,
                        dueDate: DateTime.now().add(const Duration(days: 30)),
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

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
                child: ListView.separated(
                  itemCount: _subscriptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _subscriptions[index];
                    final daysLeft = item.dueDate.difference(DateTime.now()).inDays;

                    return GlassCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accentCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.subscriptions_outlined, color: AppTheme.accentCyan),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Due in ${daysLeft <= 0 ? "Today" : "$daysLeft days"} (${DateFormat("MMM dd").format(item.dueDate)})',
                                  style: GoogleFonts.poppins(
                                    color: daysLeft <= 3 ? AppTheme.accentRed : AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                currency.format(item.amount),
                                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                item.cycle.toUpperCase(),
                                style: GoogleFonts.poppins(color: AppTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold),
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
