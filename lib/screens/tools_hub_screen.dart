import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/export_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'bills_screen.dart';
import 'budget_rules_screen.dart';
import 'calendar_expenses_screen.dart';
import 'fx_converter_screen.dart';
import 'gamification_screen.dart';
import 'ocr_scanner_screen.dart';
import 'savings_goals_screen.dart';
import 'split_bill_screen.dart';
import 'what_if_screen.dart';

class ToolsHubScreen extends StatelessWidget {
  final bool? showBackButton;
  const ToolsHubScreen({super.key, this.showBackButton});

  @override
  Widget build(BuildContext context) {
    final SupabaseService supabase = SupabaseService();
    final ExportService exporter = ExportService();

    final List<Map<String, dynamic>> tools = [
      {
        'title': 'Receipt OCR Scanner',
        'subtitle': 'Scan & extract amounts, merchant & category with camera',
        'icon': Icons.document_scanner_rounded,
        'color': AppTheme.monexBlue,
        'badge': 'AI',
        'action': (BuildContext ctx) {
          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => OCRScannerScreen(
                onParsedResult: (amount, title, category) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Scanned receipt: $title • \$$amount', style: GoogleFonts.plusJakartaSans()),
                      backgroundColor: AppTheme.monexBlue,
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
    ];

    final canPop = showBackButton ?? (ModalRoute.of(context)?.canPop ?? false);

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
          'Tools & Features Hub',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F3F9), width: 1.2),
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (tool['color'] as Color).withValues(alpha: 0.12),
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
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (tool['color'] as Color).withValues(alpha: 0.1),
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
                            color: const Color(0xFF667085),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF98A2B3)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
