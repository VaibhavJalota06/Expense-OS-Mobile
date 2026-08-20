import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../services/currency_service.dart';
import '../theme/app_theme.dart';

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.onTap,
    this.onLongPress,
    this.onDelete,
  });

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
      case 'food & dining':
        return Icons.restaurant_rounded;
      case 'uber':
      case 'transport':
      case 'transportation':
        return Icons.directions_car_rounded;
      case 'shopping':
      case 'groceries':
        return Icons.shopping_bag_rounded;
      case 'rent':
      case 'house':
        return Icons.home_rounded;
      case 'bill':
      case 'utilities':
      case 'bills & utilities':
        return Icons.receipt_rounded;
      case 'movie':
      case 'entertainment':
        return Icons.movie_rounded;
      case 'health':
      case 'healthcare':
        return Icons.medical_services_rounded;
      case 'salary':
      case 'income':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.credit_card_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isIncome = expense.type == 'income';
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;
    final currencyFormatter = NumberFormat.currency(symbol: currencySymbol, locale: 'en_US', decimalDigits: 0);
    final dateStr = DateFormat('dd MMM yyyy').format(expense.date);

    return Dismissible(
      key: Key(expense.id ?? '${expense.title}_${expense.date.toIso8601String()}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete?.call();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.dangerRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed, size: 24),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A29) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9), width: 1.2),
          boxShadow: isDark ? [] : [
            BoxShadow(
              color: const Color(0xFF101828).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap?.call();
          },
          onLongPress: () {
            HapticFeedback.heavyImpact();
            onLongPress?.call();
          },
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              // Soft Rounded Icon Container
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isIncome
                      ? (isDark ? const Color(0xFF0D3320) : const Color(0xFFECFDF3))
                      : (isDark ? const Color(0xFF1A2234) : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getCategoryIcon(expense.category),
                  color: isIncome ? AppTheme.successGreen : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E293B)),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF98A2B3),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount & Subtitle (Payment Method)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? "+ " : "- "}${currencyFormatter.format(expense.amount)}',
                    style: GoogleFonts.plusJakartaSans(
                      color: isIncome ? AppTheme.successGreen : AppTheme.dangerRed,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    expense.paymentMethod.isNotEmpty ? expense.paymentMethod : (isIncome ? 'Income' : 'Card'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF98A2B3),
                      fontWeight: FontWeight.w500,
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
