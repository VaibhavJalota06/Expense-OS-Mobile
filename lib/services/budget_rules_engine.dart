import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import 'notification_service.dart';

class BudgetRule {
  final String id;
  final String title;
  final String description;
  final String icon;
  bool isEnabled;

  BudgetRule({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isEnabled = true,
  });
}

class BudgetRulesEngine {
  static final BudgetRulesEngine _instance = BudgetRulesEngine._internal();
  factory BudgetRulesEngine() => _instance;
  BudgetRulesEngine._internal();

  List<BudgetRule> get defaultRules => [
    BudgetRule(
      id: 'rule_80_cap',
      title: '80% Spending Cap Warning',
      description: 'Triggers automated alert banner when active monthly expenses cross 80% of budget limit.',
      icon: '🔔',
      isEnabled: true,
    ),
    BudgetRule(
      id: 'rule_dining_guard',
      title: 'Dining & Entertainment Guard',
      description: 'Flags transactions exceeding 35% of total budget allocated to leisure & dining categories.',
      icon: '🛡️',
      isEnabled: true,
    ),
    BudgetRule(
      id: 'rule_savings_protection',
      title: 'Net Balance Savings Protection',
      description: 'Ensures net balance remains above 20% of monthly income before approving discretionary logs.',
      icon: '💰',
      isEnabled: true,
    ),
    BudgetRule(
      id: 'rule_budget_allocation_guard',
      title: 'Bank Account Allocation Guard',
      description: 'Alerts if monthly spending budget taken out exceeds total available bank account money.',
      icon: '🏦',
      isEnabled: true,
    ),
  ];

  Future<List<BudgetRule>> loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final rules = defaultRules;
    for (var r in rules) {
      r.isEnabled = prefs.getBool('rule_${r.id}') ?? true;
    }
    return rules;
  }

  Future<void> setRuleEnabled(String ruleId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rule_$ruleId', enabled);
  }

  /// Evaluates all rules against current transactions and fires real device push notifications
  Future<List<String>> evaluateRules({
    required List<Expense> expenses,
    required double budgetCap,
    required double totalIncome,
    required String currencySymbol,
  }) async {
    final triggeredAlerts = <String>[];
    final rules = await loadRules();

    final totalSpent = expenses.where((e) => e.type == 'expense').fold(0.0, (sum, e) => sum + e.amount);

    // Rule 1: 80% Spending Cap Warning
    final r1 = rules.firstWhere((r) => r.id == 'rule_80_cap', orElse: () => defaultRules[0]);
    if (r1.isEnabled && budgetCap > 0 && totalSpent >= (budgetCap * 0.8)) {
      final msg = '80% Spending Cap Warning: You have used ${(totalSpent / budgetCap * 100).toInt()}% of your $currencySymbol${budgetCap.toStringAsFixed(0)} limit.';
      triggeredAlerts.add(msg);
      await NotificationService().showNotification(
        id: 301,
        title: '⚠️ 80% Budget Cap Warning',
        body: msg,
      );
    }

    // Rule 2: Dining & Entertainment Guard (35% threshold)
    final r2 = rules.firstWhere((r) => r.id == 'rule_dining_guard', orElse: () => defaultRules[1]);
    if (r2.isEnabled && budgetCap > 0) {
      final diningSpent = expenses
          .where((e) => e.type == 'expense' && (e.category.toLowerCase().contains('food') || e.category.toLowerCase().contains('movie') || e.category.toLowerCase().contains('dining') || e.category.toLowerCase().contains('entertainment')))
          .fold(0.0, (sum, e) => sum + e.amount);

      if (diningSpent >= (budgetCap * 0.35)) {
        final msg = 'Dining Guard: Leisure spending ($currencySymbol${diningSpent.toStringAsFixed(0)}) exceeded 35% of total budget.';
        triggeredAlerts.add(msg);
        await NotificationService().showNotification(
          id: 302,
          title: '🛡️ Dining & Entertainment Guard Alert',
          body: msg,
        );
      }
    }

    // Rule 3: Net Balance Savings Protection (20% income buffer)
    final r3 = rules.firstWhere((r) => r.id == 'rule_savings_protection', orElse: () => defaultRules[2]);
    if (r3.isEnabled && totalIncome > 0) {
      final netBalance = totalIncome - totalSpent;
      if (netBalance < (totalIncome * 0.20)) {
        final msg = 'Savings Protection: Net savings balance ($currencySymbol${netBalance.toStringAsFixed(0)}) is below the recommended 20% safety threshold.';
        triggeredAlerts.add(msg);
        await NotificationService().showNotification(
          id: 303,
          title: '💰 Net Balance Savings Alert',
          body: msg,
        );
      }
    }

    // Rule 4: Bank Account Allocation Guard (Budget vs Total Bank Money)
    final r4 = rules.firstWhere((r) => r.id == 'rule_budget_allocation_guard', orElse: () => defaultRules[3]);
    if (r4.isEnabled && budgetCap > 0 && budgetCap > totalIncome) {
      final msg = 'Allocation Guard: Monthly budget ($currencySymbol${budgetCap.toStringAsFixed(0)}) exceeds your total bank account money ($currencySymbol${totalIncome.toStringAsFixed(0)}).';
      triggeredAlerts.add(msg);
      await NotificationService().showNotification(
        id: 304,
        title: '🏦 Budget Exceeds Bank Balance',
        body: msg,
      );
    }

    return triggeredAlerts;
  }
}
