import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/budget_rules_engine.dart';
import '../theme/app_theme.dart';

class BudgetRulesScreen extends StatefulWidget {
  const BudgetRulesScreen({super.key});

  @override
  State<BudgetRulesScreen> createState() => _BudgetRulesScreenState();
}

class _BudgetRulesScreenState extends State<BudgetRulesScreen> {
  final BudgetRulesEngine _engine = BudgetRulesEngine();
  List<BudgetRule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final list = await _engine.loadRules();
    if (mounted) {
      setState(() {
        _rules = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AI Budget Rules & Automation',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.monexBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero AI Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: Color(0xFF12B76A), size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'AI Smart Budget Rules & Alert Automation',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Automate your financial discipline with real-time budget threshold alerts and spending caps running in the background.',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Active Automation Rules',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Rule Cards
                  ..._rules.map((rule) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: rule.isEnabled ? AppTheme.monexBlue.withValues(alpha: 0.3) : const Color(0xFFF1F3F9),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF101828).withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(rule.icon, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 10),
                                  Text(
                                    rule.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: rule.isEnabled,
                                activeTrackColor: AppTheme.monexBlue,
                                onChanged: (val) async {
                                  await _engine.setRuleEnabled(rule.id, val);
                                  setState(() => rule.isEnabled = val);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            rule.description,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF667085),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: rule.isEnabled ? const Color(0xFFECFDF3) : const Color(0xFFF2F4F7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              rule.isEnabled ? 'AUTO PUSH ACTIVE' : 'DISABLED',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: rule.isEnabled ? AppTheme.successGreen : const Color(0xFF667085),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
