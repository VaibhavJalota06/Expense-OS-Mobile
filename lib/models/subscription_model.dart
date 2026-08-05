class SubscriptionItem {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String cycle; // 'monthly', 'yearly'
  final DateTime dueDate;
  final String paymentMethod;
  final bool isPaid;
  final DateTime? lastPaidDate;

  SubscriptionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.cycle = 'monthly',
    required this.dueDate,
    this.paymentMethod = 'Card',
    this.isPaid = false,
    this.lastPaidDate,
  });

  SubscriptionItem copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    String? cycle,
    DateTime? dueDate,
    String? paymentMethod,
    bool? isPaid,
    DateTime? lastPaidDate,
  }) {
    return SubscriptionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      cycle: cycle ?? this.cycle,
      dueDate: dueDate ?? this.dueDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      lastPaidDate: lastPaidDate ?? this.lastPaidDate,
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
      paymentMethod: json['payment_method'] ?? 'Card',
      isPaid: json['is_paid'] ?? false,
      lastPaidDate: json['last_paid_date'] != null ? DateTime.parse(json['last_paid_date'].toString()) : null,
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
      'payment_method': paymentMethod,
      'is_paid': isPaid,
      if (lastPaidDate != null) 'last_paid_date': lastPaidDate!.toIso8601String().split('T')[0],
    };
  }
}
