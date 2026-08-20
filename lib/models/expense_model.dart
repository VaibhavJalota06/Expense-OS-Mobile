import 'dart:math';

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

  static String generateUuidV4() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // Version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Variant RFC4122
    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  // Convert JSON from Supabase user_data or relational expenses table to Expense model
  factory Expense.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString().toLowerCase();
    final inferredType = rawType != null && rawType.isNotEmpty 
        ? rawType 
        : (json['source'] != null ? 'income' : 'expense');

    return Expense(
      id: json['id']?.toString(),
      title: json['title'] ?? json['description'] ?? json['source'] ?? 'Untitled',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? (inferredType == 'income' ? 'Income' : 'Food & Dining'),
      type: inferredType,
      date: json['date'] != null 
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      paymentMethod: json['payment_method'] ?? json['payment'] ?? 'Card',
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
      'id': (id != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id!)) ? id : generateUuidV4(),
      'description': title,
      'title': title,
      'amount': amount,
      'category': category,
      'payment': paymentMethod,
      'payment_method': paymentMethod,
      'date': dateStr,
      'type': type,
      if (notes != null) 'notes': notes,
      if (userId != null) 'user_id': userId,
    };
  }

  // Convert Expense model to JSON for Supabase relational expenses table
  Map<String, dynamic> toTableJson([String? effectiveUserId]) {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final uid = userId ?? effectiveUserId;
    final validId = (id != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id!)) ? id : generateUuidV4();
    return {
      'id': validId,
      'title': title,
      'amount': amount,
      'category': category,
      'type': type,
      'date': dateStr,
      'payment_method': paymentMethod,
      if (notes != null) 'notes': notes,
      if (uid != null) 'user_id': uid,
    };
  }

  Map<String, dynamic> toIncomeJson() {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return {
      'id': id ?? 'inc_${DateTime.now().millisecondsSinceEpoch}',
      'source': title,
      'title': title,
      'description': title,
      'amount': amount,
      'date': dateStr,
      'type': 'income',
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
    String? notes,
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
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
