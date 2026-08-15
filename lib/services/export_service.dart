import '../models/expense_model.dart';
import 'currency_service.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Formats transactions into clean CSV text
  String generateCSV(List<Expense> expenses) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('ID,Date,Title,Amount,Type,Category,Payment Method');

    for (var e in expenses) {
      final dateStr = e.date.toIso8601String().split('T').first;
      final cleanTitle = e.title.replaceAll(',', ';').replaceAll('\n', ' ');
      buffer.writeln('${e.id ?? ""},$dateStr,"$cleanTitle",${e.amount},${e.type},"${e.category}","${e.paymentMethod}"');
    }

    return buffer.toString();
  }

  /// Formats transactions into executive text report for PDF export/sharing
  String generateExecutiveStatementText(List<Expense> expenses, {String? currencySymbol}) {
    final symbol = currencySymbol ?? CurrencyService.currencySymbolNotifier.value;
    final now = DateTime.now();
    final StringBuffer sb = StringBuffer();
    
    double totalIncome = 0;
    double totalExpense = 0;

    for (var e in expenses) {
      if (e.type.toLowerCase() == 'income') {
        totalIncome += e.amount;
      } else {
        totalExpense += e.amount;
      }
    }

    final netSavings = totalIncome - totalExpense;

    sb.writeln('====================================================');
    sb.writeln('              EXPENSE OS EXECUTIVE STATEMENT        ');
    sb.writeln('====================================================');
    sb.writeln('Generated: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour}:${now.minute}');
    sb.writeln('Total Transactions Logged: ${expenses.length}');
    sb.writeln('----------------------------------------------------');
    sb.writeln('Total Income:   $symbol${totalIncome.toStringAsFixed(2)}');
    sb.writeln('Total Expenses: $symbol${totalExpense.toStringAsFixed(2)}');
    sb.writeln('Net Balance:    $symbol${netSavings.toStringAsFixed(2)}');
    sb.writeln('----------------------------------------------------');
    sb.writeln('DETAILED LEDGER:');
    sb.writeln('----------------------------------------------------');

    for (var e in expenses) {
      final sign = e.type.toLowerCase() == 'income' ? '+' : '-';
      final dateStr = e.date.toIso8601String().split('T').first;
      sb.writeln('[$dateStr] ${e.title.padRight(20)} | ${e.category.padRight(12)} | $sign$symbol${e.amount.toStringAsFixed(2)}');
    }

    sb.writeln('====================================================');
    sb.writeln('            END OF FINANCIAL STATEMENT              ');
    sb.writeln('====================================================');

    return sb.toString();
  }
}
