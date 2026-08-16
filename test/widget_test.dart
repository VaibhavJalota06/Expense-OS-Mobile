import 'package:flutter_test/flutter_test.dart';
import 'package:expense_os/main.dart';

void main() {
  testWidgets('Expense OS Mobile smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ExpenseOSApp());
    expect(find.byType(ExpenseOSApp), findsOneWidget);
  });
}
