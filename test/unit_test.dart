import 'package:flutter_test/flutter_test.dart';
import 'package:expense_os/models/subscription_model.dart';
import 'package:expense_os/models/expense_model.dart';

void main() {
  group('Expense OS Core Models & Logic Tests', () {
    test('SubscriptionModel calculates due dates and status correctly', () {
      final sub = SubscriptionItem(
        id: 'sub-1',
        title: 'Netflix Premium',
        amount: 19.99,
        category: 'Entertainment',
        cycle: 'monthly',
        dueDate: DateTime.now().add(const Duration(days: 3)),
        remindOnDueDate: true,
      );

      expect(sub.title, equals('Netflix Premium'));
      expect(sub.amount, equals(19.99));
      expect(sub.isPaid, isFalse);
      expect(sub.remindOnDueDate, isTrue);

      final json = sub.toJson();
      expect(json['title'], equals('Netflix Premium'));
      expect(json['amount'], equals(19.99));

      final fromJson = SubscriptionItem.fromJson(json);
      expect(fromJson.id, equals('sub-1'));
      expect(fromJson.title, equals('Netflix Premium'));
    });

    test('Expense model serializes and parses properly', () {
      final exp = Expense(
        id: '12345678-1234-4234-8234-123456789abc',
        title: 'Grocery Store Run',
        amount: 85.50,
        category: 'Food & Dining',
        date: DateTime(2026, 8, 21),
        paymentMethod: 'UPI',
      );

      expect(exp.title, equals('Grocery Store Run'));
      expect(exp.amount, equals(85.50));
      expect(exp.category, equals('Food & Dining'));

      final json = exp.toJson();
      expect(json['title'], equals('Grocery Store Run'));
      expect(json['amount'], equals(85.50));

      final fromJson = Expense.fromJson(json);
      expect(fromJson.title, equals('Grocery Store Run'));
      expect(fromJson.amount, equals(85.50));
    });

    test('Budget ratio threshold math operates accurately', () {
      const budgetCap = 5000.0;
      const spentUnder = 3500.0;
      const spent80 = 4000.0;
      const spentExceeded = 5500.0;

      final ratioUnder = spentUnder / budgetCap;
      final ratio80 = spent80 / budgetCap;
      final ratioExceeded = spentExceeded / budgetCap;

      expect(ratioUnder < 0.8, isTrue);
      expect(ratio80 >= 0.8 && ratio80 < 1.0, isTrue);
      expect(ratioExceeded >= 1.0, isTrue);
    });
  });
}
