import 'dart:math';
import '../models/expense_model.dart';
import '../models/gamification_model.dart';

class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  FinancialHealth calculateHealthScore(List<Expense> expenses, {double monthlyBudget = 2500.0}) {
    if (expenses.isEmpty) {
      return FinancialHealth(
        score: 75,
        grade: 'On Track',
        summary: 'Log your transactions daily to build your financial score.',
        noSpendStreakDays: 1,
        budgetUtilizationRatio: 0.0,
        badges: _getDefaultBadges(0, 1, 0.0),
      );
    }

    final now = DateTime.now();
    final currentMonthExpenses = expenses.where((e) {
      return e.type.toLowerCase() == 'expense' &&
          e.date.year == now.year &&
          e.date.month == now.month;
    }).toList();

    final totalMonthSpent = currentMonthExpenses.fold(0.0, (sum, item) => sum + item.amount);
    final utilizationRatio = monthlyBudget > 0 ? (totalMonthSpent / monthlyBudget) : 0.5;

    // 1. Budget Score (max 40 pts)
    double budgetScore = 40;
    if (utilizationRatio > 1.0) {
      budgetScore = max(0, 40 - ((utilizationRatio - 1.0) * 100));
    } else if (utilizationRatio > 0.8) {
      budgetScore = 30;
    }

    // 2. Logging Consistency Score (max 30 pts)
    final loggedDaysCount = currentMonthExpenses.map((e) => e.date.day).toSet().length;
    final loggingScore = min(30.0, (loggedDaysCount / 15.0) * 30.0);

    // 3. No-Spend Streak Score (max 30 pts)
    final streakDays = _calculateNoSpendStreak(expenses);
    final streakScore = min(30.0, streakDays * 5.0);

    final totalScore = (budgetScore + loggingScore + streakScore).round().clamp(0, 100);

    String grade = 'On Track';
    String summary = 'Your financial habits are balanced. Keep spending under control!';
    if (totalScore >= 85) {
      grade = 'Financial Fort';
      summary = 'Exceptional discipline! You are managing your budget like a seasoned investor.';
    } else if (totalScore < 60) {
      grade = 'Needs Attention';
      summary = 'High budget utilization detected. Cut back on discretionary expenses this week.';
    }

    return FinancialHealth(
      score: totalScore,
      grade: grade,
      summary: summary,
      noSpendStreakDays: streakDays,
      budgetUtilizationRatio: utilizationRatio,
      badges: _getDefaultBadges(expenses.length, streakDays, utilizationRatio),
    );
  }

  int _calculateNoSpendStreak(List<Expense> expenses) {
    if (expenses.isEmpty) return 0;
    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 30; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final hasExpenseOnDay = expenses.any((e) =>
          e.type.toLowerCase() == 'expense' &&
          e.date.year == checkDate.year &&
          e.date.month == checkDate.month &&
          e.date.day == checkDate.day);

      if (!hasExpenseOnDay) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
  }

  List<AchievementBadge> _getDefaultBadges(int totalLogs, int streakDays, double utilization) {
    return [
      AchievementBadge(
        id: 'master_logger',
        title: 'Master Logger',
        description: 'Logged over 10+ financial transactions',
        icon: '📝',
        isUnlocked: totalLogs >= 5,
        unlockedAt: totalLogs >= 5 ? DateTime.now() : null,
      ),
      AchievementBadge(
        id: 'frugal_warrior',
        title: 'Frugal Warrior',
        description: 'Maintained a 3+ day no-spend streak',
        icon: '⚔️',
        isUnlocked: streakDays >= 3,
        unlockedAt: streakDays >= 3 ? DateTime.now() : null,
      ),
      AchievementBadge(
        id: 'budget_guardian',
        title: 'Budget Guardian',
        description: 'Kept monthly spending under 80% of budget',
        icon: '🛡️',
        isUnlocked: utilization > 0 && utilization <= 0.8,
        unlockedAt: utilization > 0 && utilization <= 0.8 ? DateTime.now() : null,
      ),
      AchievementBadge(
        id: 'ocr_pioneer',
        title: 'OCR Pioneer',
        description: 'Scanned smart receipt images using AI OCR Engine',
        icon: '📷',
        isUnlocked: true,
        unlockedAt: DateTime.now(),
      ),
      AchievementBadge(
        id: 'financial_titan',
        title: 'Financial Titan',
        description: 'Reached a Financial Health Score of 85+',
        icon: '👑',
        isUnlocked: totalLogs >= 10,
        unlockedAt: totalLogs >= 10 ? DateTime.now() : null,
      ),
    ];
  }
}
