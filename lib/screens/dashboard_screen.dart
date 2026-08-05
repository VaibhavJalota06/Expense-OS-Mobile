import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final list = await _supabaseService.getExpenses();
      setState(() {
        _expenses = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  double get _totalIncome => _expenses
      .where((e) => e.type == 'income')
      .fold(0.0, (sum, e) => sum + e.amount);

  double get _totalExpense => _expenses
      .where((e) => e.type == 'expense')
      .fold(0.0, (sum, e) => sum + e.amount);

  double get _totalBalance => _totalIncome - _totalExpense;

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

  void _deleteExpense(String id) async {
    await _supabaseService.deleteExpense(id);
    _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
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
                    // Title Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expense OS',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            const Text(
                              'Finance Command Center',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
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

                    // Total Balance Card
                    GlassCard(
                      borderColor: AppTheme.primaryCyan.withOpacity(0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL NET BALANCE',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormat.format(_totalBalance),
                            style: const TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryCyan,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Income & Expense Breakdown Row
                          Row(
                            children: [
                              // Income
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successGreen.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.arrow_downward, color: AppTheme.successGreen, size: 16),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Income', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                        Text(
                                          currencyFormat.format(_totalIncome),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Expense
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.dangerRed.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.arrow_upward, color: AppTheme.dangerRed, size: 16),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Expenses', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                        Text(
                                          currencyFormat.format(_totalExpense),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Search Input
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.primaryCyan),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Recent Transactions Header
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
                  ]),
                ),
              ),

              // Expense List or Loading State
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(30.0),
                      child: CircularProgressIndicator(color: AppTheme.primaryCyan),
                    ),
                  ),
                )
              else if (filteredExpenses.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text(
                        'No transactions found.\nTap + to add your first expense!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final expense = filteredExpenses[index];
                        return ExpenseTile(
                          expense: expense,
                          onTap: () => _openAddExpenseSheet(expense),
                          onDelete: () => _deleteExpense(expense.id!),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddExpenseSheet(),
        backgroundColor: AppTheme.primaryCyan,
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
    );
  }
}
