import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/expense_model.dart';
import '../services/currency_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'calendar_expenses_screen.dart';
import 'gamification_screen.dart';
import 'ocr_scanner_screen.dart';
import 'split_bill_screen.dart';

class ToolsHubScreen extends StatelessWidget {
  final bool? showBackButton;
  const ToolsHubScreen({super.key, this.showBackButton});

  @override
  Widget build(BuildContext context) {
    final SupabaseService supabase = SupabaseService();

    final List<Map<String, dynamic>> tools = [
      {
        'title': 'AI Receipt Scanner',
        'subtitle': 'Scan paper receipts to extract amount & category automatically',
        'icon': Icons.document_scanner_rounded,
        'color': AppTheme.monexBlue,
        'badge': 'AI',
        'action': (BuildContext ctx) {
          final symbol = CurrencyService.currencySymbolNotifier.value;
          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => OCRScannerScreen(
                onParsedResult: (totalAmount, merchant, category, lineItems) async {
                  if (lineItems.isNotEmpty) {
                    for (var item in lineItems) {
                      final scannedExpense = Expense(
                        title: '${item.name} ($merchant)',
                        amount: item.price,
                        category: item.category.isNotEmpty ? item.category : category,
                        type: 'expense',
                        date: DateTime.now(),
                        paymentMethod: 'Card',
                      );
                      await supabase.addExpense(scannedExpense);
                    }
                  } else {
                    final scannedExpense = Expense(
                      title: merchant,
                      amount: totalAmount,
                      category: category,
                      type: 'expense',
                      date: DateTime.now(),
                      paymentMethod: 'Card',
                    );
                    await supabase.addExpense(scannedExpense);
                  }
                  final count = lineItems.isNotEmpty ? lineItems.length : 1;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('$count scanned item(s) saved from $merchant • $symbol${totalAmount.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                },
              ),
            ),
          );
        },
      },
      {
        'title': 'Split Bill & Group Expense',
        'subtitle': 'Split dinner, trips & rent evenly or with custom weights',
        'icon': Icons.call_split_rounded,
        'color': const Color(0xFF7A5AF8),
        'badge': 'GROUPS',
        'action': (BuildContext ctx) {
          Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SplitBillScreen()));
        },
      },
      {
        'title': 'Gamification & Quests',
        'subtitle': 'Earn XP, unlock achievement badges & level up financial tier',
        'icon': Icons.emoji_events_rounded,
        'color': const Color(0xFFF79009),
        'badge': 'XP',
        'action': (BuildContext ctx) {
          Navigator.push(ctx, MaterialPageRoute(builder: (_) => const GamificationScreen()));
        },
      },
      {
        'title': 'Total Expenses Calendar',
        'subtitle': 'Day-by-day cashflow breakdown with spending gauges',
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFF2E90FA),
        'badge': 'CALENDAR',
        'action': (BuildContext ctx) {
          Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CalendarExpensesScreen()));
        },
      },
      {
        'title': 'Smart Push Notifications',
        'subtitle': 'Manage budget limits, bill due dates, daily streaks & fraud alerts',
        'icon': Icons.notifications_active_rounded,
        'color': const Color(0xFF12B76A),
        'badge': 'ALERTS',
        'action': (BuildContext ctx) {
          _showNotificationManagerModal(ctx);
        },
      },
    ];

    final isDark = AppTheme.isDark(context);
    final canPop = showBackButton ?? (ModalRoute.of(context)?.canPop ?? false);

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
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
              )
            : null,
        title: Text(
          'Tools & Features Hub',
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        itemCount: tools.length,
        itemBuilder: (context, index) {
          final tool = tools[index];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              (tool['action'] as Function(BuildContext))(context);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131A29) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9), width: 1.2),
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
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (tool['color'] as Color).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      tool['icon'] as IconData,
                      color: tool['color'] as Color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                tool['title'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (tool['color'] as Color).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tool['badge'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: tool['color'] as Color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tool['subtitle'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF98A2B3)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showNotificationManagerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    color: const Color(0xFFE4E7EC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12B76A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF12B76A), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Push Notifications & Alerts',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Real-time proactive financial intelligence',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF667085),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildChannelRow(
                icon: Icons.pie_chart_rounded,
                color: const Color(0xFFF04438),
                title: 'Budget Threshold Warnings',
                subtitle: 'Alerts at 80% and 100% of your monthly spending cap',
              ),
              const SizedBox(height: 12),
              _buildChannelRow(
                icon: Icons.calendar_today_rounded,
                color: const Color(0xFF7A5AF8),
                title: 'Bill & Subscription Due Dates',
                subtitle: 'Automatic reminders 24h before recurring bill renewals',
              ),
              const SizedBox(height: 12),
              _buildChannelRow(
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFF79009),
                title: 'Daily Streak Reminders',
                subtitle: 'Evening alerts to log expenses & maintain your streak',
              ),
              const SizedBox(height: 12),
              _buildChannelRow(
                icon: Icons.security_rounded,
                color: const Color(0xFF2E90FA),
                title: 'Fraud & Anomaly Detection',
                subtitle: 'Instant warnings for duplicate charges and spike expenses',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: Color(0xFFD0D5DD)),
                      ),
                      onPressed: () async {
                        final granted = await NotificationService().requestPermissions();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                granted ? '✅ Notification permissions active' : '⚠️ Permissions not granted',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: granted ? AppTheme.successGreen : const Color(0xFFF04438),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.verified_user_rounded, size: 18, color: AppTheme.textPrimary),
                      label: Text(
                        'Permissions',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF12B76A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await NotificationService().showTestNotification();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                '🚀 Test notification sent to your device!',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      label: Text(
                        'Send Test Alert',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChannelRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF667085),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF12B76A), size: 18),
        ],
      ),
    );
  }
}
