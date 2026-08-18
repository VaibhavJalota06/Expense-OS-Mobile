import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptLineItem {
  String name;
  double price;
  String category;
  bool isSelected;

  ReceiptLineItem({
    required this.name,
    required this.price,
    this.category = 'General',
    this.isSelected = true,
  });
}

class ReceiptParseResult {
  final double? amount;
  final String? merchant;
  final String category;
  final DateTime? date;
  final String rawText;
  final List<ReceiptLineItem> lineItems;

  ReceiptParseResult({
    this.amount,
    this.merchant,
    required this.category,
    this.date,
    required this.rawText,
    this.lineItems = const [],
  });
}

class ReceiptOCRService {
  static final ReceiptOCRService _instance = ReceiptOCRService._internal();
  factory ReceiptOCRService() => _instance;
  ReceiptOCRService._internal();

  /// Processes receipt image using on-device Google ML Kit Text Recognition
  Future<ReceiptParseResult> processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final String fullText = recognizedText.text.trim();
      debugPrint('--- OCR Raw Text Extracted (${fullText.length} chars) ---');
      debugPrint(fullText);

      if (fullText.isNotEmpty) {
        return parseRawText(fullText);
      }
    } catch (e) {
      debugPrint('Google ML Kit OCR error: $e. Using smart fallback parser.');
    }

    // Fallback if camera capture image has zero text or on desktop simulator
    return _generateSmartFallback(imageFile);
  }

  /// Parses raw extracted OCR text into merchant, line items, total amount and category
  ReceiptParseResult parseRawText(String text) {
    double? detectedAmount;
    String? detectedMerchant;
    String category = 'General';
    DateTime? detectedDate;
    final List<ReceiptLineItem> items = [];

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Merchant Detection: Look in first 5 lines for a clean brand or store name
    final nonMerchantWords = [
      'RECEIPT', 'TAX INVOICE', 'INVOICE', 'BILL', 'WELCOME', 'THANK YOU',
      'CUSTOMER COPY', 'TEL', 'PHONE', 'DATE', 'TIME', 'CASHIER', 'ORDER #',
      'REGISTER', 'STORE #', 'GSTIN', 'VAT', 'PAN', 'TERMINAL', 'SALE'
    ];

    for (int i = 0; i < lines.length && i < 6; i++) {
      final line = lines[i];
      final upper = line.toUpperCase();

      if (line.length >= 3 &&
          !nonMerchantWords.any((w) => upper.startsWith(w) || upper == w) &&
          !RegExp(r'^\d+[\s\-/:\.]*\d+').hasMatch(line)) {
        detectedMerchant = _cleanMerchantName(line);
        break;
      }
    }

    // 2. Line Item Extraction: Matches lines containing <description> <price>
    // e.g., "1x Latte $4.50", "Chicken Burger 8.99", "Milk 1L  2.49"
    final lineItemPattern = RegExp(
      r'^(?:(?:\d+\s*[xX*]\s*)?)(.+?)\s+[\$₹€£]?\s*(\d{1,4}[.,]\d{2})\s*$',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = lineItemPattern.firstMatch(line);
      if (match != null) {
        final desc = match.group(1)?.trim();
        final priceStr = match.group(2)?.replaceAll(',', '.');

        if (desc != null && priceStr != null) {
          final price = double.tryParse(priceStr);
          final upperDesc = desc.toUpperCase();

          final isSummaryWord = upperDesc.contains('TOTAL') ||
              upperDesc.contains('SUBTOTAL') ||
              upperDesc.contains('TAX') ||
              upperDesc.contains('CASH') ||
              upperDesc.contains('CHANGE') ||
              upperDesc.contains('BALANCE') ||
              upperDesc.contains('AMOUNT PAID') ||
              upperDesc.contains('CARD') ||
              upperDesc.contains('DISCOUNT');

          if (price != null && price > 0 && !isSummaryWord && desc.length >= 2) {
            items.add(ReceiptLineItem(
              name: desc,
              price: price,
              category: 'General',
            ));
          }
        }
      }
    }

    // 3. High-Accuracy Total Amount Detection
    // Checks keywords like TOTAL, GRAND TOTAL, AMOUNT, DUE, NET
    final totalPatterns = [
      RegExp(r'(?:GRAND\s*TOTAL|TOTAL\s*AMOUNT|TOTAL\s*DUE|AMOUNT\s*DUE|TOTAL)[\s:]*[\$₹€£]?\s*(\d{1,6}[.,]\d{2})', caseSensitive: false),
      RegExp(r'(?:NET\s*AMOUNT|FINAL\s*TOTAL|BALANCE\s*DUE|PAID)[\s:]*[\$₹€£]?\s*(\d{1,6}[.,]\d{2})', caseSensitive: false),
      RegExp(r'[\$₹€£]\s*(\d{1,6}[.,]\d{2})'),
    ];

    for (final pattern in totalPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final rawVal = match.group(1)?.replaceAll(',', '.');
        if (rawVal != null) {
          final val = double.tryParse(rawVal);
          if (val != null && val > 0) {
            detectedAmount = val;
            break;
          }
        }
      }
    }

    // Fallback total = sum of itemized items or highest parsed number
    if (detectedAmount == null && items.isNotEmpty) {
      detectedAmount = items.fold<double>(0.0, (sum, it) => sum + it.price);
    } else if (detectedAmount == null) {
      final allPrices = RegExp(r'\b\d{1,5}[.,]\d{2}\b')
          .allMatches(text)
          .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '.')) ?? 0.0)
          .where((v) => v > 0)
          .toList();
      if (allPrices.isNotEmpty) {
        allPrices.sort();
        detectedAmount = allPrices.last;
      }
    }

    // 4. Date Extraction (e.g. 2026-08-18, 18/08/2026, Aug 18 2026)
    final datePattern = RegExp(r'(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})');
    final dateMatch = datePattern.firstMatch(text);
    if (dateMatch != null) {
      try {
        final p1 = int.parse(dateMatch.group(1)!);
        final p2 = int.parse(dateMatch.group(2)!);
        var p3 = int.parse(dateMatch.group(3)!);
        if (p3 < 100) p3 += 2000;

        if (p1 > 12) {
          detectedDate = DateTime(p3, p2, p1);
        } else {
          detectedDate = DateTime(p3, p1, p2);
        }
      } catch (_) {
        detectedDate = DateTime.now();
      }
    }

    // 5. Smart Category Auto-Classification
    final lower = text.toLowerCase();
    if (lower.contains('restaurant') || lower.contains('coffee') || lower.contains('starbucks') ||
        lower.contains('cafe') || lower.contains('burger') || lower.contains('pizza') ||
        lower.contains('food') || lower.contains('diner') || lower.contains('bakery') ||
        lower.contains('mcdonald') || lower.contains('kfc') || lower.contains('subway')) {
      category = 'Food & Dining';
      detectedMerchant ??= 'Restaurant & Dining';
    } else if (lower.contains('supermarket') || lower.contains('grocery') || lower.contains('walmart') ||
        lower.contains('market') || lower.contains('whole foods') || lower.contains('trader joe') ||
        lower.contains('target') || lower.contains('milk') || lower.contains('produce')) {
      category = 'Groceries';
      detectedMerchant ??= 'Supermarket Grocery';
    } else if (lower.contains('uber') || lower.contains('lyft') || lower.contains('taxi') ||
        lower.contains('fuel') || lower.contains('petrol') || lower.contains('gas station') ||
        lower.contains('shell') || lower.contains('chevron') || lower.contains('parking')) {
      category = 'Transportation';
      detectedMerchant ??= 'Transport & Fuel';
    } else if (lower.contains('amazon') || lower.contains('store') || lower.contains('mall') ||
        lower.contains('zara') || lower.contains('h&m') || lower.contains('clothing') ||
        lower.contains('apparel') || lower.contains('nike') || lower.contains('retail')) {
      category = 'Shopping';
      detectedMerchant ??= 'Retail Store';
    } else if (lower.contains('pharmacy') || lower.contains('medical') || lower.contains('clinic') ||
        lower.contains('health') || lower.contains('hospital') || lower.contains('walgreens') ||
        lower.contains('cvs') || lower.contains('drugs') || lower.contains('medicine')) {
      category = 'Health & Medical';
      detectedMerchant ??= 'Pharmacy / Health';
    } else if (lower.contains('cinema') || lower.contains('movie') || lower.contains('theatre') ||
        lower.contains('ticket') || lower.contains('game') || lower.contains('entertainment')) {
      category = 'Entertainment';
      detectedMerchant ??= 'Entertainment';
    } else if (lower.contains('electric') || lower.contains('water') || lower.contains('utility') ||
        lower.contains('internet') || lower.contains('wifi') || lower.contains('broadband')) {
      category = 'Bills & Utilities';
      detectedMerchant ??= 'Utility Service';
    }

    // Apply category to extracted line items
    for (var item in items) {
      item.category = category;
    }

    return ReceiptParseResult(
      amount: detectedAmount ?? (items.isNotEmpty ? items.fold<double>(0.0, (double s, ReceiptLineItem i) => s + i.price) : 0.0),
      merchant: detectedMerchant ?? 'Scanned Store Receipt',
      category: category,
      date: detectedDate ?? DateTime.now(),
      rawText: text,
      lineItems: items,
    );
  }

  String _cleanMerchantName(String line) {
    var clean = line.replaceAll(RegExp(r'[#*_\-~|]'), '').trim();
    if (clean.length > 30) {
      clean = clean.substring(0, 30);
    }
    return clean;
  }

  ReceiptParseResult _generateSmartFallback(File imageFile) {
    return ReceiptParseResult(
      amount: 0.0,
      merchant: 'Receipt Scan',
      category: 'General',
      date: DateTime.now(),
      rawText: 'No readable text detected. You can enter or edit the items below manually.',
      lineItems: [
        ReceiptLineItem(name: 'Scanned Item', price: 0.0, category: 'General'),
      ],
    );
  }
}
