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
    final now = DateTime.now();
    final currentYM = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final rawPaidMonth = json['lastPaidMonth']?.toString() ?? json['last_paid_month']?.toString();
    final bool isPaidBool = json['is_paid'] == true || 
                            json['isPaid'] == true || 
                            (rawPaidMonth != null && rawPaidMonth == currentYM);

    DateTime dueDate;
    if (json['due_date'] != null && json['due_date'].toString().isNotEmpty) {
      dueDate = DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now().add(const Duration(days: 15));
    } else if (json['dueDate'] != null && json['dueDate'].toString().isNotEmpty) {
      dueDate = DateTime.tryParse(json['dueDate'].toString()) ?? DateTime.now().add(const Duration(days: 15));
    } else if (json['dueDay'] != null) {
      final day = int.tryParse(json['dueDay'].toString()) ?? 15;
      dueDate = DateTime(now.year, now.month, day.clamp(1, 28));
    } else {
      dueDate = DateTime.now().add(const Duration(days: 15));
    }

    return SubscriptionItem(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? json['name'] ?? 'Subscription',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? 'Services & Subscriptions',
      cycle: json['cycle'] ?? 'monthly',
      dueDate: dueDate,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'].toString()) : null,
      paymentMethod: json['payment_method'] ?? json['paymentMethod'] ?? 'Card',
      isPaid: isPaidBool,
      lastPaidDate: json['last_paid_date'] != null 
          ? DateTime.tryParse(json['last_paid_date'].toString()) 
          : (json['lastPaidDate'] != null ? DateTime.tryParse(json['lastPaidDate'].toString()) : (isPaidBool ? now : null)),
      remindOnDueDate: json['remind_on_due_date'] ?? json['remindOnDueDate'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final now = DateTime.now();
    final currentYM = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return {
      'id': id,
      'title': title,
      'name': title,
      'amount': amount,
      'category': category,
      'cycle': cycle,
      'due_date': dueDate.toIso8601String().split('T')[0],
      'dueDate': dueDate.toIso8601String().split('T')[0],
      'dueDay': dueDate.day,
      if (endDate != null) 'end_date': endDate!.toIso8601String().split('T')[0],
      'payment_method': paymentMethod,
      'paymentMethod': paymentMethod,
      'is_paid': isPaid,
      'isPaid': isPaid,
      'lastPaidMonth': isPaid ? currentYM : null,
      if (lastPaidDate != null) 'last_paid_date': lastPaidDate!.toIso8601String().split('T')[0],
      if (lastPaidDate != null) 'lastPaidDate': lastPaidDate!.toIso8601String().split('T')[0],
      'remind_on_due_date': remindOnDueDate,
      'remindOnDueDate': remindOnDueDate,
      'type': 'subscription',
    };
  }

  Map<String, dynamic> toTableJson([String? effectiveUserId]) {
    final dateStr = dueDate.toIso8601String().split('T')[0];
    final endStr = endDate != null ? endDate!.toIso8601String().split('T')[0] : null;
    final lastPaidStr = lastPaidDate != null ? lastPaidDate!.toIso8601String().split('T')[0] : null;
    return {
      'id': id,
      if (effectiveUserId != null && effectiveUserId != 'local_device_user') 'user_id': effectiveUserId,
      'title': title,
      'amount': amount,
      'category': category,
      'cycle': cycle,
      'due_date': dateStr,
      if (endStr != null) 'end_date': endStr,
      'payment_method': paymentMethod,
      'is_paid': isPaid,
      if (lastPaidStr != null) 'last_paid_date': lastPaidStr,
      'remind_on_due_date': remindOnDueDate,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
