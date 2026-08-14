class SubscriptionItem {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String cycle; // 'monthly', 'yearly', 'weekly', 'quarterly', 'one-time'
  final DateTime dueDate;
  final DateTime? endDate;
  final String paymentMethod;
  final bool isPaid;
  final DateTime? lastPaidDate;
  final bool remindOnDueDate;

  SubscriptionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.cycle = 'monthly',
    required this.dueDate,
    this.endDate,
    this.paymentMethod = 'Card',
    this.isPaid = false,
    this.lastPaidDate,
    this.remindOnDueDate = true,
  });

  SubscriptionItem copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    String? cycle,
    DateTime? dueDate,
    DateTime? endDate,
    String? paymentMethod,
    bool? isPaid,
    DateTime? lastPaidDate,
    bool? remindOnDueDate,
  }) {
    return SubscriptionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      cycle: cycle ?? this.cycle,
      dueDate: dueDate ?? this.dueDate,
      endDate: endDate ?? this.endDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      lastPaidDate: lastPaidDate ?? this.lastPaidDate,
      remindOnDueDate: remindOnDueDate ?? this.remindOnDueDate,
    );
  }

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) {
    return SubscriptionItem(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'Subscription',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? 'Services & Subscriptions',
      cycle: json['cycle'] ?? 'monthly',
      dueDate: json['due_date'] != null 
          ? DateTime.parse(json['due_date'].toString()) 
          : DateTime.now().add(const Duration(days: 15)),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'].toString()) : null,
      paymentMethod: json['payment_method'] ?? 'Card',
      isPaid: json['is_paid'] ?? false,
      lastPaidDate: json['last_paid_date'] != null ? DateTime.parse(json['last_paid_date'].toString()) : null,
      remindOnDueDate: json['remind_on_due_date'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'cycle': cycle,
      'due_date': dueDate.toIso8601String().split('T')[0],
      if (endDate != null) 'end_date': endDate!.toIso8601String().split('T')[0],
      'payment_method': paymentMethod,
      'is_paid': isPaid,
      if (lastPaidDate != null) 'last_paid_date': lastPaidDate!.toIso8601String().split('T')[0],
      'remind_on_due_date': remindOnDueDate,
    };
  }
}
