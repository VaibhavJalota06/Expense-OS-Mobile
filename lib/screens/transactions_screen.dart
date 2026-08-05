import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/expense_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/expense_tile.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<Expense> _allExpenses = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _selectedType = 'All'; // 'All', 'expense', 'income'

  final List<String> _categories = [
    'All',
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Bills & Utilities',
    'Services & Subscriptions',
    'Health & Fitness',
    'Miscellaneous'
  ];

  @override
  void initState() {
    super.initState();
    SupabaseService.refreshNotifier.addListener(_loadData);
    _loadData();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    SupabaseService.refreshNotifier.removeListener(_loadData);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final items = await _supabaseService.getExpenses();
      if (!mounted) return;
      setState(() {
        _allExpenses = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Expense> get _filteredExpenses {
    final query = _searchController.text.toLowerCase().trim();
    return _allExpenses.where((item) {
      final matchesSearch = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);

      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesType = _selectedType == 'All' || item.type == _selectedType;

      return matchesSearch && matchesCategory && matchesType;
    }).toList();
  }

  Future<void> _deleteExpense(Expense item) async {
    if (item.id == null) return;
    await _supabaseService.deleteExpense(item.id!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${item.title}"', style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.accentRed,
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredExpenses;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(
          'Transactions History',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accentCyan),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.accentCyan),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filter Type Selector (All | Expenses | Income)
              Row(
                children: [
                  _buildTypeChip('All', 'All'),
                  const SizedBox(width: 8),
                  _buildTypeChip('Expenses', 'expense'),
                  const SizedBox(width: 8),
                  _buildTypeChip('Income', 'income'),
                ],
              ),
              const SizedBox(height: 12),

              // Category Filter Horizontal List
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      selectedColor: AppTheme.accentCyan,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      labelStyle: GoogleFonts.poppins(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // List View
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off, size: 54, color: AppTheme.textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  'No transactions match your filters.',
                                  style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            color: AppTheme.accentCyan,
                            child: ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return Dismissible(
                                  key: Key(item.id ?? index.toString()),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentRed.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  onDismissed: (_) => _deleteExpense(item),
                                  child: ExpenseTile(expense: item),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentCyan.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.accentCyan : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: isSelected ? AppTheme.accentCyan : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
