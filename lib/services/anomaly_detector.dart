import '../models/anomaly_model.dart';
import '../models/expense_model.dart';

class AnomalyDetector {
  static final AnomalyDetector _instance = AnomalyDetector._internal();
  factory AnomalyDetector() => _instance;
  AnomalyDetector._internal();

  List<SpendingAnomaly> detectAnomalies(List<Expense> expenses) {
    final List<SpendingAnomaly> anomalies = [];
    if (expenses.isEmpty) return anomalies;

    final now = DateTime.now();
    final expenseOnly = expenses.where((e) => e.type.toLowerCase() == 'expense').toList();
    if (expenseOnly.isEmpty) return anomalies;

    // 1. Check 24-Hour Duplicate Charge Detection
    final Map<String, List<Expense>> duplicateMap = {};
    for (var e in expenseOnly) {
      final key = '${e.title.toLowerCase().trim()}_${e.amount}';
      duplicateMap.putIfAbsent(key, () => []).add(e);
    }

    duplicateMap.forEach((key, list) {
      if (list.length >= 2) {
        list.sort((a, b) => b.date.compareTo(a.date));
        final diff = list[0].date.difference(list[1].date).inHours.abs();
        if (diff <= 24) {
          anomalies.add(
            SpendingAnomaly(
              id: 'dup_${list[0].id}',
              title: '24-Hour Duplicate Charge',
              description: 'Identical transaction of \$${list[0].amount.toStringAsFixed(2)} for "${list[0].title}" logged twice within $diff hours.',
              type: AnomalyType.duplicateCharge,
              severity: AnomalySeverity.warning,
              category: list[0].category,
              amount: list[0].amount,
              detectedAt: list[0].date,
            ),
          );
        }
      }
    });

    // 2. Check Spike Purchase Alert (>3.5x Average Order Value)
    final totalAmount = expenseOnly.fold(0.0, (sum, item) => sum + item.amount);
    final avgOrderValue = totalAmount / expenseOnly.length;

    final recent7Days = expenseOnly.where((e) => now.difference(e.date).inDays <= 7).toList();
    for (var e in recent7Days) {
      if (e.amount >= avgOrderValue * 3.5 && avgOrderValue > 0) {
        anomalies.add(
          SpendingAnomaly(
            id: 'spike_${e.id}',
            title: 'Spike Purchase Alert',
            description: '"${e.title}" (\$${e.amount.toStringAsFixed(2)}) is ${(e.amount / avgOrderValue).toStringAsFixed(1)}x higher than your average order value of \$${avgOrderValue.toStringAsFixed(2)}.',
            type: AnomalyType.spikePurchase,
            severity: AnomalySeverity.critical,
            category: e.category,
            amount: e.amount,
            detectedAt: e.date,
          ),
        );
      }
    }

    // 3. Check Category Velocity Surge (>45% surge over 30d avg)
    final Map<String, double> categoryMonthlyTotals = {};
    final Map<String, double> categoryRecent7DayTotals = {};

    for (var e in expenseOnly) {
      final daysAgo = now.difference(e.date).inDays;
      if (daysAgo <= 30) {
        categoryMonthlyTotals[e.category] = (categoryMonthlyTotals[e.category] ?? 0) + e.amount;
      }
      if (daysAgo <= 7) {
        categoryRecent7DayTotals[e.category] = (categoryRecent7DayTotals[e.category] ?? 0) + e.amount;
      }
    }

    categoryRecent7DayTotals.forEach((cat, recent7Total) {
      final monthlyTotal = categoryMonthlyTotals[cat] ?? 0;
      final expected7DayAvg = monthlyTotal / 4.0;

      if (expected7DayAvg > 10 && recent7Total > expected7DayAvg * 1.45) {
        final surgePct = (((recent7Total - expected7DayAvg) / expected7DayAvg) * 100).round();
        anomalies.add(
          SpendingAnomaly(
            id: 'surge_$cat',
            title: 'Category Velocity Surge',
            description: 'Spending in "$cat" surged by $surgePct% this week (\$${recent7Total.toStringAsFixed(0)} vs \$${expected7DayAvg.toStringAsFixed(0)} expected).',
            type: AnomalyType.velocitySurge,
            severity: AnomalySeverity.warning,
            category: cat,
            amount: recent7Total,
          ),
        );
      }
    });

    return anomalies;
  }
}
