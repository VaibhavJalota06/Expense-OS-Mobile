class SubscriptionItem {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String cycle; // 'monthly', 'yearly'
  final DateTime dueDate;
  final String paymentMethod;

  SubscriptionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.cycle = 'monthly',
    required this.dueDate,
    this.paymentMethod = 'Card',
  });

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
    };
  }
}
