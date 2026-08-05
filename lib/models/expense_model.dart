class Expense {
  final String? id;
  final String title;
  final double amount;
  final String category;
  final String type; // 'expense' or 'income'
  final DateTime date;
  final String paymentMethod;
  final String? userId;
  final DateTime? createdAt;

  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.type = 'expense',
    required this.date,
    this.paymentMethod = 'Card',
    this.userId,
    this.createdAt,
  });

  // Convert JSON from Supabase to Expense model
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id']?.toString(),
      title: json['title'] ?? json['description'] ?? 'Untitled',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? 'Miscellaneous',
      type: json['type'] ?? 'expense',
      date: json['date'] != null 
          ? DateTime.parse(json['date'].toString()) 
          : DateTime.now(),
      paymentMethod: json['payment_method'] ?? 'Card',
      userId: json['user_id']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString()) 
          : null,
    );
  }

  // Convert Expense model to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'type': type,
      'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD format
      'payment_method': paymentMethod,
      if (userId != null) 'user_id': userId,
    };
  }

  // copyWith method for immutability
  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    String? type,
    DateTime? date,
    String? paymentMethod,
    String? userId,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      type: type ?? this.type,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
