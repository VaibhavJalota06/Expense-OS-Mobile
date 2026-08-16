class SplitMember {
  final String id;
  final String name;
  final double amountOwed;
  final bool isPaid;

  SplitMember({
    required this.id,
    required this.name,
    required this.amountOwed,
    this.isPaid = false,
  });

  SplitMember copyWith({
    String? id,
    String? name,
    double? amountOwed,
    bool? isPaid,
  }) {
    return SplitMember(
      id: id ?? this.id,
      name: name ?? this.name,
      amountOwed: amountOwed ?? this.amountOwed,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amountOwed': amountOwed,
        'isPaid': isPaid,
      };

  /// For the relational split_bill_members table
  Map<String, dynamic> toTableJson(String splitBillId) => {
        'split_bill_id': splitBillId,
        'name': name,
        'amount_owed': amountOwed,
        'is_paid': isPaid,
      };

  factory SplitMember.fromJson(Map<String, dynamic> json) {
    return SplitMember(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: (json['name'] ?? 'Member') as String,
      amountOwed: (json['amountOwed'] ?? json['amount_owed'] ?? 0) is num
          ? ((json['amountOwed'] ?? json['amount_owed'] ?? 0) as num).toDouble()
          : 0.0,
      isPaid: json['isPaid'] == true || json['is_paid'] == true,
    );
  }
}

class SplitBill {
  final String id;
  final String title;
  final double totalAmount;
  final String payerName;
  final DateTime createdAt;
  final List<SplitMember> members;

  SplitBill({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.payerName,
    required this.createdAt,
    required this.members,
  });

  double get perPersonAmount => members.isEmpty ? 0 : totalAmount / members.length;
}
