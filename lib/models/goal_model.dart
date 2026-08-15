class FinancialGoal {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String contributionType; // 'Weekly', 'Monthly', 'Yearly'
  final DateTime deadline;
  final String icon;

  FinancialGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.contributionType,
    required this.deadline,
    this.icon = '🎯',
  });

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  int get percentage => (progress * 100).toInt();

  FinancialGoal copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    String? contributionType,
    DateTime? deadline,
    String? icon,
  }) {
    return FinancialGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      contributionType: contributionType ?? this.contributionType,
      deadline: deadline ?? this.deadline,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'savings_goal',
        'title': title,
        'name': title,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'savedAmount': currentAmount,
        'contributionType': contributionType,
        'deadline': deadline.toIso8601String(),
        'targetDate': deadline.toIso8601String(),
        'icon': icon,
      };

  factory FinancialGoal.fromJson(Map<String, dynamic> json) => FinancialGoal(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? json['name']?.toString() ?? '',
        targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? (json['target'] as num?)?.toDouble() ?? 0.0,
        currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? (json['savedAmount'] as num?)?.toDouble() ?? 0.0,
        contributionType: json['contributionType']?.toString() ?? 'Monthly',
        deadline: json['deadline'] != null
            ? (DateTime.tryParse(json['deadline'].toString()) ?? DateTime.now())
            : (json['targetDate'] != null
                ? (DateTime.tryParse(json['targetDate'].toString()) ?? DateTime.now())
                : DateTime.now()),
        icon: json['icon']?.toString() ?? '🎯',
      );
}
