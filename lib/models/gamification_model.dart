class AchievementBadge {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  AchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    this.unlockedAt,
  });
}

class FinancialHealth {
  final int score; // 0 - 100
  final String grade; // e.g. "Financial Fort", "On Track", "Needs Attention"
  final String summary;
  final int noSpendStreakDays;
  final double budgetUtilizationRatio;
  final List<AchievementBadge> badges;

  FinancialHealth({
    required this.score,
    required this.grade,
    required this.summary,
    required this.noSpendStreakDays,
    required this.budgetUtilizationRatio,
    required this.badges,
  });
}
