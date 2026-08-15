class Expense {
  final String? id;
  final String title;
  final double amount;
  final String category;
  final String type; // 'expense' or 'income'
  final DateTime date;
  final String paymentMethod;
  final String? notes;
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
    this.notes,
    this.userId,
    this.createdAt,
  });

  // Convert JSON from Supabase user_data to Expense model
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id']?.toString(),
      title: json['description'] ?? json['title'] ?? json['source'] ?? 'Untitled',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? (json['type'] == 'income' || json['source'] != null ? 'Income' : 'Food & Dining'),
      type: json['type'] ?? (json['source'] != null ? 'income' : 'expense'),
      date: json['date'] != null 
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      paymentMethod: json['payment'] ?? json['payment_method'] ?? 'UPI',
      notes: json['notes']?.toString(),
      userId: json['user_id']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
    );
  }

  // Convert Expense model to JSON for Supabase user_data JSON array
  Map<String, dynamic> toJson() {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return {
      'id': id ?? 'exp_${DateTime.now().millisecondsSinceEpoch}',
      'description': title,
      'amount': amount,
      'category': category,
      'payment': paymentMethod,
      'date': dateStr,
      'type': type,
      if (notes != null) 'notes': notes,
      if (userId != null) 'user_id': userId,
    };
  }

  Map<String, dynamic> toIncomeJson() {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return {
      'id': id ?? 'inc_${DateTime.now().millisecondsSinceEpoch}',
      'source': title,
      'amount': amount,
      'date': dateStr,
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
