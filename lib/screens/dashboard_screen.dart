import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/expense_tile.dart';
import 'add_expense_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  double _monthlyBudgetCap = 0.0;

  @override
  void initState() {
    super.initState();
    SupabaseService.refreshNotifier.addListener(_loadExpenses);
    _loadBudgetCap();
    _loadExpenses();
  }

  @override
  void dispose() {
    SupabaseService.refreshNotifier.removeListener(_loadExpenses);
    super.dispose();
  }

  Future<void> _loadBudgetCap() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _monthlyBudgetCap = prefs.getDouble('monthly_budget_cap') ?? 0.0;
    });
  }

  Future<void> _saveBudgetCap(double newBudget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_budget_cap', newBudget);
    if (!mounted) return;
    setState(() {
      _monthlyBudgetCap = newBudget;
    });
    SupabaseService.refreshNotifier.value++;
  }

  Future<void> _loadExpenses() async {
    if (!mounted) return;
    _loadBudgetCap();
    setState(() => _isLoading = true);
    try {
      final list = await _supabaseService.getExpenses();
      if (!mounted) return;
      setState(() {
        _expenses = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  double get _totalExpense => _expenses
      .where((e) => e.type == 'expense')
      .fold(0.0, (sum, e) => sum + e.amount);

  void _openAddExpenseSheet([Expense? expenseToEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddExpenseSheet(
        expenseToEdit: expenseToEdit,
        onSave: (newExpense) async {
          if (newExpense.id != null) {
            await _supabaseService.updateExpense(newExpense);
          } else {
            await _supabaseService.addExpense(newExpense);
          }
          _loadExpenses();
        },
      ),
    );
  }

  void _openSetBudgetSheet() {
    final controller = TextEditingController(text: _monthlyBudgetCap.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Set Monthly Budget Cap',
                    style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: const TextStyle(color: Colors.white, fontFamily: 'IBM Plex Mono', fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Monthly Target (₹)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixIcon: const Icon(Icons.currency_rupee, color: AppTheme.amber),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final val = double.tryParse(controller.text.trim());
                    if (val != null && val >= 0) {
                      _saveBudgetCap(val);
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.amber,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'SAVE BUDGET CAP',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => controller.dispose());
  }

  void _deleteExpense(String id) async {
    await _supabaseService.deleteExpense(id);
    _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2);
    final filteredExpenses = _expenses.where((e) {
      return e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadExpenses,
          color: AppTheme.primaryCyan,
          backgroundColor: AppTheme.background,
          child: CustomScrollView(
            slivers: [
              // Header & Balance Card Section
              SliverPadding(
                padding: const EdgeInsets.all(20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Title Bar with Branding Logo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/icon/app_icon.png',
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expense OS',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        fontSize: 22,
                                      ),
                                ),
                                const Text(
                                  'Finance Command Center',
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white10,
                          child: IconButton(
                            icon: const Icon(Icons.refresh, color: AppTheme.primaryCyan, size: 20),
                            onPressed: _loadExpenses,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Total Monthly Expenses Card
                    GlassCard(
                      borderColor: AppTheme.primaryCyan.withOpacity(0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL MONTHLY EXPENSES',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              currencyFormat.format(_totalExpense),
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryCyan,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Budget Breakdown Row (Budget Cap vs Remaining)
                          Row(
                            children: [
                              // Budget Cap
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.amber.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.account_balance_wallet, color: AppTheme.amber, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Budget Cap', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              currencyFormat.format(_monthlyBudgetCap),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Remaining Budget
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emerald.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Remaining', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              currencyFormat.format((_monthlyBudgetCap - _totalExpense).clamp(0.0, double.infinity)),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Monthly Budget Cap Card (Tappable anywhere to set budget)
                    GestureDetector(
                      onTap: _openSetBudgetSheet,
                      child: GlassCard(
                        borderColor: AppTheme.amber.withOpacity(0.5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: const [
                                      Icon(Icons.tune, color: AppTheme.amber, size: 18),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'MONTHLY BUDGET CAP',
                                          style: TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.2,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.amber.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.edit, color: AppTheme.amber, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Set Budget',
                                        style: TextStyle(color: AppTheme.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  currencyFormat.format(_monthlyBudgetCap),
                                  style: const TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${(_totalExpense / (_monthlyBudgetCap > 0 ? _monthlyBudgetCap : 1) * 100).toStringAsFixed(1)}% Spent',
                                  style: TextStyle(
                                    color: _totalExpense > _monthlyBudgetCap ? AppTheme.dangerRed : AppTheme.emerald,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (_monthlyBudgetCap > 0 ? (_totalExpense / _monthlyBudgetCap).clamp(0.0, 1.0) : 0.0),
                                minHeight: 8,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _totalExpense > _monthlyBudgetCap ? AppTheme.dangerRed : AppTheme.emerald,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Spent: ${currencyFormat.format(_totalExpense)}',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                ),
                                Text(
                                  'Remaining: ${currencyFormat.format((_monthlyBudgetCap - _totalExpense).clamp(0.0, double.infinity))}',
                                  style: TextStyle(
                                    color: _monthlyBudgetCap - _totalExpense < 0 ? AppTheme.dangerRed : AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Search Bar & Recent Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${filteredExpenses.length} items',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search Field
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search title or category...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.primaryCyan),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.cardBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ]),
                ),
              ),

              // Transactions List
              _isLoading
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(color: AppTheme.primaryCyan),
                        ),
                      ),
                    )
                  : filteredExpenses.isEmpty
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Column(
                                children: const [
                                  Icon(Icons.receipt_long, size: 48, color: Colors.white24),
                                  SizedBox(height: 12),
                                  Text(
                                    'No transactions found',
                                    style: TextStyle(color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final expense = filteredExpenses[index];
                                return ExpenseTile(
                                  expense: expense,
                                  onTap: () => _openAddExpenseSheet(expense),
                                  onDelete: () {
                                    if (expense.id != null) {
                                      _deleteExpense(expense.id!);
                                    }
                                  },
                                );
                              },
                              childCount: filteredExpenses.length,
                            ),
                          ),
                        ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddExpenseSheet(),
        backgroundColor: AppTheme.primaryCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
