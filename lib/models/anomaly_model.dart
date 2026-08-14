enum AnomalyType {
  velocitySurge,
  duplicateCharge,
  spikePurchase,
}

enum AnomalySeverity {
  info,
  warning,
  critical,
}

class SpendingAnomaly {
  final String id;
  final String title;
  final String description;
  final AnomalyType type;
  final AnomalySeverity severity;
  final String? category;
  final double? amount;
  final DateTime detectedAt;

  SpendingAnomaly({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.severity,
    this.category,
    this.amount,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'severity': severity.name,
        'category': category,
        'amount': amount,
        'detectedAt': detectedAt.toIso8601String(),
      };
}
