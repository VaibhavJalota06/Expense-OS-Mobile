import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_model.dart';
import '../services/currency_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class BillsScreen extends StatefulWidget {
  final bool? showBackButton;
  const BillsScreen({super.key, this.showBackButton});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<SubscriptionItem> _subscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_saved_subscriptions');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        _subscriptions = decoded.map((e) => SubscriptionItem.fromJson(e)).toList();
      } catch (_) {
        _subscriptions = [];
      }
    } else {
      _subscriptions = [];
    }

    _processCycleRollovers();

    setState(() => _isLoading = false);
    _checkPendingBillAlerts();
  }

  void _setDefaults() {
    _subscriptions = [];
    _saveSubscriptions();
  }

  /// Automatically rolls over paid bills whose due date has passed to the next cycle
  void _processCycleRollovers() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool changed = false;

    for (int i = 0; i < _subscriptions.length; i++) {
      final item = _subscriptions[i];
      final due = DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day);

      // If a bill was marked PAID and today has passed its due date, advance to next cycle and reset to pending
      if (item.isPaid && today.isAfter(due)) {
        DateTime nextDue = item.dueDate;
        if (item.cycle == 'monthly') {
          nextDue = DateTime(item.dueDate.year, item.dueDate.month + 1, item.dueDate.day);
        } else if (item.cycle == 'yearly') {
          nextDue = DateTime(item.dueDate.year + 1, item.dueDate.month, item.dueDate.day);
        } else if (item.cycle == 'weekly') {
          nextDue = item.dueDate.add(const Duration(days: 7));
        } else if (item.cycle == 'quarterly') {
          nextDue = DateTime(item.dueDate.year, item.dueDate.month + 3, item.dueDate.day);
        }

        _subscriptions[i] = item.copyWith(
          dueDate: nextDue,
          isPaid: false, // Reset to pending for the new period
        );
        changed = true;
      }
    }

    if (changed) {
      _saveSubscriptions();
    }
  }

  Future<void> _saveSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_subscriptions.map((s) => s.toJson()).toList());
    await prefs.setString('user_saved_subscriptions', encoded);
  }

  /// Automatically alerts user when a recurring bill renewal is pending or due
  Future<void> _checkPendingBillAlerts() async {
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var item in _subscriptions) {
      if (item.remindOnDueDate && !item.isPaid) {
        final due = DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day);
        final diffDays = due.difference(today).inDays;
        if (diffDays <= 1 && diffDays >= 0) {
          final timing = diffDays == 0 ? 'Due Today' : 'Due Tomorrow';
          await NotificationService().showNotification(
            id: item.id.hashCode.abs() % 100000,
            title: '🔔 $timing: ${item.title}',
            body: 'Your bill of $currencySymbol${item.amount.toStringAsFixed(2)} is pending payment.',
          );
        }
      }
    }
  }

  double get _totalMonthlyCost {
    return _subscriptions.where((item) => !item.isPaid).fold(0.0, (sum, item) {
      if (item.cycle == 'yearly') return sum + (item.amount / 12);
      if (item.cycle == 'weekly') return sum + (item.amount * 4.33);
      if (item.cycle == 'quarterly') return sum + (item.amount / 3);
      return sum + item.amount;
    });
  }

  void _showAddSubscriptionSheet([SubscriptionItem? itemToEdit]) {
    final isEdit = itemToEdit != null;
    final titleController = TextEditingController(text: itemToEdit?.title ?? '');
    final amountController = TextEditingController(text: itemToEdit != null ? itemToEdit.amount.toStringAsFixed(2) : '');
    String category = itemToEdit?.category ?? 'Services & Subscriptions';
    String cycle = itemToEdit?.cycle ?? 'monthly';
    DateTime selectedDueDate = itemToEdit?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    bool remind = itemToEdit?.remindOnDueDate ?? true;

    final List<String> categories = [
      'Services & Subscriptions',
      'Bills & Utilities',
      'Housing',
      'Entertainment',
      'Health & Fitness',
      'Insurance',
      'Education',
      'Miscellaneous',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final currencySymbol = CurrencyService.currencySymbolNotifier.value;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  top: 20,
                  left: 20,
                  right: 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD0D5DD),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEdit ? 'Edit Recurring Bill' : 'Add Recurring Bill',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Title input
                      TextField(
                        controller: titleController,
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'e.g. Netflix, Rent, Internet, Gym',
                          labelText: 'Bill / Subscription Name',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Amount
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          prefixText: '$currencySymbol ',
                          hintText: '0.00',
                          labelText: 'Amount Due',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                          ),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat, style: GoogleFonts.plusJakartaSans(fontSize: 14)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Cycle selector: Monthly / Yearly / Weekly / Custom
                      Text(
                        'Billing Frequency',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildCycleChip('monthly', 'Monthly', cycle, (val) => setSheetState(() => cycle = val)),
                          _buildCycleChip('yearly', 'Yearly', cycle, (val) => setSheetState(() => cycle = val)),
                          _buildCycleChip('weekly', 'Weekly', cycle, (val) => setSheetState(() => cycle = val)),
                          _buildCycleChip('quarterly', 'Quarterly', cycle, (val) => setSheetState(() => cycle = val)),
                          _buildCycleChip('custom', 'Custom Date', cycle, (val) => setSheetState(() => cycle = val)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Single Due / Renewal Date Selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE4E7EC)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Due / Renewal Date',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('EEEE, dd MMM yyyy').format(selectedDueDate),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.monexBlue),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDueDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                                );
                                if (picked != null) {
                                  setSheetState(() => selectedDueDate = picked);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.monexBlue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.monexBlue),
                              label: Text('Change', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.monexBlue)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Reminder Notification toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE4E7EC)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.notifications_active_outlined, size: 18, color: AppTheme.monexBlue),
                                const SizedBox(width: 8),
                                Text(
                                  'Alert when due is pending',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: remind,
                              activeColor: AppTheme.monexBlue,
                              onChanged: (val) => setSheetState(() => remind = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Save Button
                      ElevatedButton(
                        onPressed: () {
                          if (titleController.text.trim().isEmpty || amountController.text.trim().isEmpty) return;
                          final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                          if (amount <= 0) return;

                          final newSub = SubscriptionItem(
                            id: isEdit ? itemToEdit.id : DateTime.now().millisecondsSinceEpoch.toString(),
                            title: titleController.text.trim(),
                            amount: amount,
                            category: category,
                            cycle: cycle,
                            dueDate: selectedDueDate,
                            remindOnDueDate: remind,
                            isPaid: isEdit ? itemToEdit.isPaid : false,
                          );

                          setState(() {
                            if (isEdit) {
                              final idx = _subscriptions.indexWhere((s) => s.id == itemToEdit.id);
                              if (idx != -1) _subscriptions[idx] = newSub;
                            } else {
                              _subscriptions.add(newSub);
                            }
                          });
                          _saveSubscriptions();
                          _checkPendingBillAlerts();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.monexBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          isEdit ? 'UPDATE BILL' : 'SAVE BILL & REMINDER',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCycleChip(String key, String label, String currentCycle, Function(String) onSelect) {
    final isSelected = currentCycle == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.monexBlue,
      labelStyle: GoogleFonts.plusJakartaSans(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      onSelected: (_) => onSelect(key),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final currency = NumberFormat.currency(symbol: currencySymbol, locale: 'en_US', decimalDigits: 2);

    final canPop = widget.showBackButton ?? (ModalRoute.of(context)?.canPop ?? false);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
                onPressed: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
              )
            : null,
        title: Text(
          'Recurring Bills & Subscriptions',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bills_add_subscription_fab',
        onPressed: () => _showAddSubscriptionSheet(),
        backgroundColor: AppTheme.monexBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Bill', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  children: [
                    // Summary Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                                'Total Monthly Bills',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currency.format(_totalMonthlyCost),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_subscriptions.length} commitments • ${_subscriptions.where((s) => !s.isPaid).length} pending',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Active List
                    Expanded(
                      child: _subscriptions.isEmpty
                          ? Center(
                              child: Text(
                                'No recurring bills yet.\nTap + Add Bill below.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _subscriptions.length,
                              itemBuilder: (context, index) {
                                final item = _subscriptions[index];
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                final due = DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day);
                                final daysLeft = due.difference(today).inDays;

                                return GestureDetector(
                                  onTap: () => _showAddSubscriptionSheet(item),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: item.isPaid
                                            ? const Color(0xFFD1FADF)
                                            : (daysLeft <= 2 ? const Color(0xFFFECDCA) : const Color(0xFFF1F3F9)),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF101828).withValues(alpha: 0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: item.isPaid
                                                ? const Color(0xFFECFDF3)
                                                : (daysLeft <= 2 ? const Color(0xFFFEF3F2) : const Color(0xFFEEF2FF)),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            item.isPaid
                                                ? Icons.check_circle_outline_rounded
                                                : Icons.event_repeat_rounded,
                                            color: item.isPaid
                                                ? const Color(0xFF12B76A)
                                                : (daysLeft <= 2 ? AppTheme.dangerRed : AppTheme.monexBlue),
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item.title,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppTheme.textPrimary,
                                                        decoration: item.isPaid ? TextDecoration.lineThrough : null,
                                                      ),
                                                    ),
                                                  ),
                                                  if (item.isPaid)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFECFDF3),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        'PAID ✓',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w800,
                                                          color: const Color(0xFF027A48),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                item.isPaid
                                                    ? 'Paid for this period • Due: ${DateFormat("dd MMM").format(item.dueDate)}'
                                                    : '${daysLeft == 0 ? "Due Today ⚠️" : (daysLeft < 0 ? "Overdue ⚠️" : "Due in $daysLeft days (${DateFormat("dd MMM").format(item.dueDate)})")} • ${item.cycle.toUpperCase()}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  color: item.isPaid
                                                      ? const Color(0xFF12B76A)
                                                      : (daysLeft <= 2 ? AppTheme.dangerRed : const Color(0xFF667085)),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              currency.format(item.amount),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (!item.isPaid) ...[
                                                  GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _subscriptions[index] = item.copyWith(
                                                          isPaid: true,
                                                          lastPaidDate: DateTime.now(),
                                                        );
                                                      });
                                                      _saveSubscriptions();
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFECFDF3),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: const Color(0xFFD1FADF)),
                                                      ),
                                                      child: Text(
                                                        'Pay',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 11,
                                                          color: const Color(0xFF027A48),
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() => _subscriptions.removeAt(index));
                                                    _saveSubscriptions();
                                                  },
                                                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFF98A2B3), size: 19),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
