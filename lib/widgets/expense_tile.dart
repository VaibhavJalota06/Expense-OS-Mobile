import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
  });

  // Get icon and color based on category using built-in Material Icons
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
        return Icons.restaurant;
      case 'shopping':
        return Icons.shopping_bag;
      case 'housing':
      case 'rent':
        return Icons.home;
      case 'transport':
      case 'travel':
        return Icons.directions_car;
      case 'entertainment':
        return Icons.movie;
      case 'utilities':
      case 'bills':
        return Icons.bolt;
      case 'healthcare':
      case 'medical':
        return Icons.favorite;
      case 'salary':
      case 'income':
        return Icons.account_balance_wallet;
      case 'investment':
        return Icons.trending_up;
      default:
        return Icons.receipt_long;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food & Dining':
        return const Color(0xFF34D399); // Emerald
      case 'Transportation':
        return const Color(0xFF38BDF8); // Sky
      case 'Shopping':
        return const Color(0xFFA78BFA); // Violet
      case 'Bills & Utilities':
        return const Color(0xFFFBBF24); // Amber
      case 'Services & Subscriptions':
        return const Color(0xFF818CF8); // Indigo
      case 'Entertainment':
        return const Color(0xFFF472B6); // Pink
      case 'Health & Fitness':
        return const Color(0xFFFB923C); // Orange
      case 'Miscellaneous':
      default:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = expense.type == 'income';
    final categoryColor = _getCategoryColor(expense.category);
    final currencyFormatter = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2);
    final dateStr = DateFormat('MMM dd, yyyy').format(expense.date);

    return Dismissible(
      key: Key(expense.id ?? DateTime.now().toIso8601String()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.dangerRed.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 12),
        borderRadius: 16,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // Icon Badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: categoryColor.withOpacity(0.4), width: 1.5),
                ),
                child: Icon(
                  _getCategoryIcon(expense.category),
                  color: categoryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Title & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            expense.category,
                            style: TextStyle(
                              color: categoryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: Colors.white38)),
                        Text(
                          dateStr,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${isIncome ? "+" : "-"}${currencyFormatter.format(expense.amount)}',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: isIncome ? AppTheme.successGreen : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      expense.paymentMethod,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
