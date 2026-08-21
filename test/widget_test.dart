import 'package:flutter_test/flutter_test.dart';
import 'package:expense_os/main.dart';

void main() {
  testWidgets('Expense OS Mobile smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ExpenseOSApp(
      initialHasSeenOnboarding: true,
      initialIsAuthenticated: true,
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ExpenseOSApp), findsOneWidget);
  });
}
