import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/expense_model.dart';
import 'currency_service.dart';
import 'notification_service.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Formats transactions into clean CSV text
  String generateCSV(List<Expense> expenses) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('ID,Date,Title,Amount,Type,Category,PaymentMethod,Notes');

    for (var e in expenses) {
      final dateStr = e.date.toIso8601String().split('T').first;
      final cleanTitle = e.title.replaceAll('"', '""').replaceAll('\n', ' ');
      final cleanCat = e.category.replaceAll('"', '""');
      final cleanPay = e.paymentMethod.replaceAll('"', '""');
      final cleanNotes = (e.notes ?? '').replaceAll('"', '""').replaceAll('\n', ' ');
      buffer.writeln('${e.id ?? ""},$dateStr,"$cleanTitle",${e.amount},${e.type},"$cleanCat","$cleanPay","$cleanNotes"');
    }

    return buffer.toString();
  }

  /// Writes CSV data to device file and returns the saved File
  Future<File?> saveCsvFile(List<Expense> expenses) async {
    try {
      final csvContent = generateCSV(expenses);
      final now = DateTime.now();
      final dateTag = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final filename = 'Expense_OS_Report_$dateTag.csv';

      final List<String> candidatePaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/sdcard/Download',
      ];

      for (var path in candidatePaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          final file = File('${dir.path}/$filename');
          await file.writeAsString(csvContent);
          
          // Trigger notification
          await NotificationService().showNotification(
            id: 888,
            title: '📁 CSV Report Exported!',
            body: 'Saved $filename (${expenses.length} records) to Downloads.',
            channelType: NotificationChannelType.general,
          );
          
          return file;
        }
      }

      // Fallback to system temp directory
      final fallbackDir = Directory.systemTemp;
      final file = File('${fallbackDir.path}/$filename');
      await file.writeAsString(csvContent);

      await NotificationService().showNotification(
        id: 888,
        title: '📁 CSV Report Exported!',
        body: 'Saved $filename (${expenses.length} records).',
        channelType: NotificationChannelType.general,
      );

      return file;
    } catch (e) {
      debugPrint('ExportService saveCsvFile error: $e');
      return null;
    }
  }

  /// Formats transactions into executive text report for sharing
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
    sb.writeln('Generated: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
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
      sb.writeln('[$dateStr] ${e.title.padRight(20)} | ${e.category.padRight(14)} | $sign$symbol${e.amount.toStringAsFixed(2)}');
    }

    sb.writeln('====================================================');
    sb.writeln('            END OF FINANCIAL STATEMENT              ');
    sb.writeln('====================================================');

    return sb.toString();
  }
}
