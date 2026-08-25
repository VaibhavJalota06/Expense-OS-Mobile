import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import '../models/goal_model.dart';
import '../services/currency_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class SavingsGoalsScreen extends StatefulWidget {
  final bool showYourGoalsDirectly;
  final bool? showBackButton;

  const SavingsGoalsScreen({
    super.key,
    this.showYourGoalsDirectly = false,
    this.showBackButton,
  });

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  List<FinancialGoal> _goals = [];

  @override
  void initState() {
    super.initState();
    _loadGoals();
    SupabaseService.refreshNotifier.addListener(_loadGoals);
  }

  @override
  void dispose() {
    SupabaseService.refreshNotifier.removeListener(_loadGoals);
    super.dispose();
  }

  Future<void> _loadGoals() async {
    // 1. Instant local render from cached preferences
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('expense_os_goals') ?? prefs.getString('monex_goals');
    if (data != null && mounted) {
      try {
        final List decoded = jsonDecode(data);
        setState(() {
          _goals = decoded.map((e) => FinancialGoal.fromJson(e)).toList();
        });
      } catch (_) {}
    }

    // 2. Fetch fresh data from Supabase Cloud so any goals added/updated on Web/Desktop show up immediately
    try {
      await SupabaseService().getExpenses();
      final freshData = prefs.getString('expense_os_goals') ?? prefs.getString('monex_goals');
      if (freshData != null && mounted) {
        final List freshDecoded = jsonDecode(freshData);
        setState(() {
          _goals = freshDecoded.map((e) => FinancialGoal.fromJson(e)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_goals.map((g) => g.toJson()).toList());
    await prefs.setString('expense_os_goals', encoded);
    try {
      await SupabaseService().pushAllDataToCloud();
    } catch (_) {}
  }

  double get _totalCurrentSavings => _goals.fold(0.0, (sum, g) => sum + g.currentAmount);
  double get _totalTargetSavings => _goals.fold(0.0, (sum, g) => sum + g.targetAmount);
  double get _overallProgress => _totalTargetSavings > 0 ? (_totalCurrentSavings / _totalTargetSavings).clamp(0.0, 1.0) : 0.0;

  void _showAddGoalScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddGoalScreen(
          onAdd: (newGoal) async {
            setState(() {
              _goals.add(newGoal);
            });
            await _saveGoals();

            // Auto-log initial deposit as an expense transaction if starting with money
            if (newGoal.currentAmount > 0) {
              final now = DateTime.now();
              final goalExpense = Expense(
                id: 'goal_dep_${newGoal.id}_${now.millisecondsSinceEpoch}',
                title: 'Goal Deposit: ${newGoal.title}',
                amount: newGoal.currentAmount,
                category: 'Savings & Goals',
                type: 'expense',
                date: now,
                paymentMethod: 'Bank Account',
                notes: 'Initial savings allocation for ${newGoal.title}',
              );
              await SupabaseService().addExpense(goalExpense);
            }
          },
        ),
      ),
    );
  }

  void _showEditGoalScreen(FinancialGoal goal) {
    final oldAmount = goal.currentAmount;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddGoalScreen(
          goalToEdit: goal,
          onAdd: (_) {},
          onUpdate: (updatedGoal) async {
            setState(() {
              final index = _goals.indexWhere((g) => g.id == updatedGoal.id);
              if (index != -1) {
                _goals[index] = updatedGoal;
              }
            });
            await _saveGoals();

            final added = updatedGoal.currentAmount - oldAmount;
            if (added > 0) {
              final now = DateTime.now();
              final goalExpense = Expense(
                id: 'goal_dep_${updatedGoal.id}_${now.millisecondsSinceEpoch}',
                title: 'Goal Deposit: ${updatedGoal.title}',
                amount: added,
                category: 'Savings & Goals',
                type: 'expense',
                date: now,
                paymentMethod: 'Bank Account',
                notes: 'Additional savings deposit for ${updatedGoal.title}',
              );
              await SupabaseService().addExpense(goalExpense);
            }
          },
          onDelete: (id) async {
            final targetGoal = _goals.firstWhere((g) => g.id == id, orElse: () => goal);
            setState(() {
              _goals.removeWhere((g) => g.id == id);
            });
            await _saveGoals();

            // When a goal is deleted, delete all associated goal deposit transactions
            // so the money is restored back to the budget and balance!
            try {
              final currentExpenses = await SupabaseService().getExpenses();
              final targetTitle = targetGoal.title.trim().toLowerCase();
              final expensesToDelete = currentExpenses.where((e) {
                final idMatch = e.id != null && (e.id == 'goal_dep_$id' || e.id!.startsWith('goal_dep_${id}_'));
                final titleMatch = (e.category == 'Savings & Goals' || e.title.toLowerCase().startsWith('goal deposit:')) &&
                    targetTitle.isNotEmpty &&
                    e.title.toLowerCase().contains(targetTitle);
                return idMatch || titleMatch;
              }).toList();

              for (final exp in expensesToDelete) {
                if (exp.id != null) {
                  await SupabaseService().deleteExpense(exp.id!);
                }
              }
            } catch (_) {}
          },
        ),
      ),
    );
  }

  void _showQuickDepositDialog(FinancialGoal goal) {
    final isDark = AppTheme.isDark(context);
    final controller = TextEditingController();
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A29) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(goal.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Deposit to ${goal.title}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Quick Deposit Presets:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [500, 1000, 5000, 10000].map((amt) {
                return ActionChip(
                  label: Text('+$currencySymbol$amt'),
                  labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.monexBlue),
                  backgroundColor: isDark ? const Color(0xFF1A2234) : AppTheme.monexBlue.withValues(alpha: 0.1),
                  side: BorderSide(color: isDark ? const Color(0xFF1E293B) : Colors.transparent),
                  onPressed: () {
                    controller.text = amt.toString();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Deposit Amount ($currencySymbol)',
                labelStyle: GoogleFonts.plusJakartaSans(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085)),
                hintText: 'Enter amount to add',
                hintStyle: GoogleFonts.plusJakartaSans(color: isDark ? const Color(0xFF64748B) : const Color(0xFF98A2B3)),
                filled: true,
                fillColor: isDark ? const Color(0xFF0D1322) : const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.monexBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final added = double.tryParse(controller.text.trim()) ?? 0.0;
                  if (added > 0) {
                    setState(() {
                      final idx = _goals.indexWhere((g) => g.id == goal.id);
                      if (idx != -1) {
                        _goals[idx] = goal.copyWith(currentAmount: goal.currentAmount + added);
                      }
                    });
                    await _saveGoals();

                    // Auto-log deposit to Expense Logs & deduct from budget/total money
                    final now = DateTime.now();
                    final goalExpense = Expense(
                      id: 'goal_dep_${goal.id}_${now.millisecondsSinceEpoch}',
                      title: 'Goal Deposit: ${goal.title}',
                      amount: added,
                      category: 'Savings & Goals',
                      type: 'expense',
                      date: now,
                      paymentMethod: 'Bank Account',
                      notes: 'Quick savings deposit towards ${goal.title}',
                    );
                    await SupabaseService().addExpense(goalExpense);

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Deposited $currencySymbol${added.toStringAsFixed(0)} to "${goal.title}" and recorded in Transactions!'),
                          backgroundColor: AppTheme.successGreen,
                        ),
                      );
                    }
                  }
                },
                child: Text('Confirm Deposit', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final currency = NumberFormat.currency(symbol: currencySymbol, locale: 'en_US', decimalDigits: 0);
    final canPop = widget.showBackButton ?? (ModalRoute.of(context)?.canPop ?? false);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary, size: 20),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
        title: Text(
          'Savings & Financial Goals',
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // "Current Savings" Subtitle & Circular Card
            Text(
              'Total Accumulated Savings',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 16),

            // Hero Circular Badge Card
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: AppTheme.monexBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.monexBlue.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currency.format(_totalCurrentSavings),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (_totalTargetSavings > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${(_overallProgress * 100).toInt()}% of Target',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (_totalTargetSavings > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131A29) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Overall Savings Progress', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                        Text('${currency.format(_totalCurrentSavings)} / ${currency.format(_totalTargetSavings)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.monexBlue)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _overallProgress,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.monexBlue),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // "Your Goals" Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Savings Goals',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${_goals.length} ${_goals.length == 1 ? 'goal' : 'goals'}',
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF98A2B3),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Goal Items or Starter Presets Card
            if (_goals.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131A29) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.monexBlue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.savings_outlined, size: 28, color: AppTheme.monexBlue),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Savings Goals Created Yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap "+ Add Goal" below to set custom financial targets & track milestones.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._goals.map((goal) => _buildGoalItem(goal)),

            const SizedBox(height: 20),

            // Add Goal Trigger Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _showAddGoalScreen,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'Add New Custom Goal',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                ),
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

  Widget _buildGoalItem(FinancialGoal goal) {
    final isDark = AppTheme.isDark(context);
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final currency = NumberFormat.currency(symbol: currencySymbol, locale: 'en_US', decimalDigits: 0);

    final isAchieved = goal.currentAmount >= goal.targetAmount;
    final isAlmost = goal.percentage >= 80 && !isAchieved;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A29) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAchieved
              ? AppTheme.successGreen.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9)),
          width: 1.2,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF101828).withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon Badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isAchieved
                      ? (isDark ? const Color(0xFF0D3320) : const Color(0xFFECFDF3))
                      : (isDark ? const Color(0xFF1A2234) : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(goal.icon, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),

              // Title & Deadline
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (isAchieved)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0D3320) : const Color(0xFFECFDF3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('🎉 Achieved!', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.successGreen)),
                          )
                        else if (isAlmost)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF3B2406) : const Color(0xFFFEF0C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('🔥 80%+ Done', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Target Date: ${DateFormat('MMM d, yyyy').format(goal.deadline)} • ${goal.contributionType}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.monexBlue),
                onPressed: () => _showEditGoalScreen(goal),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal.progress.clamp(0.0, 1.0),
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEAECF0),
              valueColor: AlwaysStoppedAnimation<Color>(isAchieved ? AppTheme.successGreen : AppTheme.monexBlue),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),

          // Progress Row + Quick Deposit Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${goal.percentage}% Saved (${currency.format(goal.currentAmount)})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isAchieved ? AppTheme.successGreen : AppTheme.monexBlue,
                    ),
                  ),
                  Text(
                    'Goal: ${currency.format(goal.targetAmount)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF98A2B3),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showQuickDepositDialog(goal),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: Text('Deposit', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.monexBlue.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.monexBlue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Add & Edit Goal Screen
class AddGoalScreen extends StatefulWidget {
  final FinancialGoal? goalToEdit;
  final Function(FinancialGoal) onAdd;
  final Function(FinancialGoal)? onUpdate;
  final Function(String)? onDelete;

  const AddGoalScreen({
    super.key,
    this.goalToEdit,
    required this.onAdd,
    this.onUpdate,
    this.onDelete,
  });

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _currentAmountController;
  late String _contributionType;
  late DateTime _deadline;
  late String _selectedIcon;

  final List<String> _frequencies = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  final List<String> _availableIcons = ['🏍️', '📱', '🏠', '✈️', '💻', '🚗', '💍', '🎓', '🏖️', '🎮'];

  @override
  void initState() {
    super.initState();
    final g = widget.goalToEdit;
    _titleController = TextEditingController(text: g?.title ?? '');
    _targetAmountController = TextEditingController(text: g != null && g.targetAmount > 0 ? g.targetAmount.toStringAsFixed(0) : '');
    _currentAmountController = TextEditingController(text: g != null && g.currentAmount > 0 ? g.currentAmount.toStringAsFixed(0) : '');
    _contributionType = g?.contributionType ?? 'Monthly';
    _deadline = g?.deadline ?? DateTime.now().add(const Duration(days: 180));
    _selectedIcon = g?.icon ?? '🎯';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  void _showFrequencyPicker() {
    final isDark = AppTheme.isDark(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A29) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _frequencies.map((freq) {
              final isSelected = _contributionType == freq;
              return ListTile(
                title: Text(
                  freq,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.monexBlue
                        : (isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary),
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.monexBlue)
                    : null,
                onTap: () {
                  setState(() => _contributionType = freq);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final isDark = AppTheme.isDark(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppTheme.monexBlue,
                    onPrimary: Colors.white,
                    surface: Color(0xFF131A29),
                    onSurface: Color(0xFFF8FAFC),
                  )
                : const ColorScheme.light(
                    primary: AppTheme.monexBlue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppTheme.textPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  void _submit() {
    final target = double.tryParse(_targetAmountController.text.trim()) ?? 0.0;
    final current = double.tryParse(_currentAmountController.text.trim()) ?? 0.0;
    if (_titleController.text.trim().isEmpty || target < 0) return;

    if (widget.goalToEdit != null) {
      final updated = widget.goalToEdit!.copyWith(
        title: _titleController.text.trim(),
        targetAmount: target,
        currentAmount: current >= 0 ? current : 0.0,
        contributionType: _contributionType,
        deadline: _deadline,
        icon: _selectedIcon,
      );
      widget.onUpdate?.call(updated);
    } else {
      final newGoal = FinancialGoal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        targetAmount: target,
        currentAmount: current >= 0 ? current : 0.0,
        contributionType: _contributionType,
        deadline: _deadline,
        icon: _selectedIcon,
      );
      widget.onAdd(newGoal);
    }
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _confirmDelete() {
    final isDark = AppTheme.isDark(context);
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131A29) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Goal',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.goalToEdit?.title}"?',
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dCtx);
              widget.onDelete?.call(widget.goalToEdit!.id);
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isEditing = widget.goalToEdit != null;
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
        title: Text(
          isEditing ? 'Edit Goal' : 'Add Goal',
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Picker Row
            Text(
              'Select Icon',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _availableIcons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final icon = _availableIcons[index];
                  final isSelected = _selectedIcon == icon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.monexBlue.withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF131A29) : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.monexBlue
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFD0D5DD)),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(icon, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Goal Title
            Text(
              'Goal Title',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _titleController,
              hint: 'e.g. New Bike, iPhone 16',
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Target Amount
            Text(
              'Target Amount ($currencySymbol)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _targetAmountController,
              hint: 'Target goal cost',
              suffixText: currencySymbol,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Current Amount Saved
            Text(
              'Current Amount Saved ($currencySymbol)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _currentAmountController,
              hint: '0',
              suffixText: currencySymbol,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Contribution Type
            Text(
              'Contribution Frequency',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showFrequencyPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1322) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC), width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _contributionType,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Target Date
            Text(
              'Target Date',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDeadline,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1322) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC), width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM d, yyyy').format(_deadline),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                      ),
                    ),
                    const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.monexBlue),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.monexBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: Text(
                  isEditing ? 'UPDATE GOAL' : 'CREATE GOAL',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            if (isEditing) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: _confirmDelete,
                  child: Text(
                    'Delete Goal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dangerRed,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    String? suffixText,
    TextInputType? keyboardType,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1322) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE4E7EC), width: 1.2),
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
          color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF98A2B3),
          ),
          suffixText: suffixText,
          suffixStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
