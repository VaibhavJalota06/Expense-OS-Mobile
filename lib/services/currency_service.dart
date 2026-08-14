import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  static final ValueNotifier<String> currencySymbolNotifier = ValueNotifier<String>('\$');
  static final ValueNotifier<String> currencyCodeNotifier = ValueNotifier<String>('USD');
  static final ValueNotifier<String> currencyNameNotifier = ValueNotifier<String>('\$ USD (US Dollar)');

  static const List<Map<String, String>> supportedCurrencies = [
    {'code': 'INR', 'symbol': '₹', 'name': '₹ INR (Indian Rupee)'},
    {'code': 'USD', 'symbol': '\$', 'name': '\$ USD (US Dollar)'},
    {'code': 'EUR', 'symbol': '€', 'name': '€ EUR (Euro)'},
    {'code': 'GBP', 'symbol': '£', 'name': '£ GBP (British Pound)'},
    {'code': 'JPY', 'symbol': '¥', 'name': '¥ JPY (Japanese Yen)'},
    {'code': 'CAD', 'symbol': 'CA\$', 'name': 'CA\$ CAD (Canadian Dollar)'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'A\$ AUD (Australian Dollar)'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'S\$ SGD (Singapore Dollar)'},
    {'code': 'AED', 'symbol': 'AED', 'name': 'AED (UAE Dirham)'},
  ];

  String get currentSymbol => currencySymbolNotifier.value;
  String get currentCode => currencyCodeNotifier.value;
  String get currentName => currencyNameNotifier.value;

  /// Automatically detect device locale and initialize currency
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    final savedSymbol = prefs.getString('app_currency_symbol');
    final savedCode = prefs.getString('app_currency_code');
    final savedName = prefs.getString('app_currency_name');

    if (savedSymbol != null && savedCode != null && savedName != null) {
      currencySymbolNotifier.value = savedSymbol;
      currencyCodeNotifier.value = savedCode;
      currencyNameNotifier.value = savedName;
      return;
    }

    // Auto-detect from device system locale
    try {
      final Locale locale = PlatformDispatcher.instance.locale;
      final countryCode = locale.countryCode?.toUpperCase() ?? '';

      Map<String, String>? detected;

      switch (countryCode) {
        case 'IN':
          detected = supportedCurrencies.firstWhere((c) => c['code'] == 'INR');
          break;
        case 'GB':
          detected = supportedCurrencies.firstWhere((c) => c['code'] == 'GBP');
          break;
        case 'DE':
        case 'FR':
        case 'IT':
        case 'ES':
        case 'NL':
          detected = supportedCurrencies.firstWhere((c) => c['code'] == 'EUR');
          break;
        case 'JP':
          detected = supportedCurrencies.firstWhere((c) => c['code'] == 'JPY');
          break;
        case 'CA':
          detected = supportedCurrencies.firstWhere((c) => c['code'] == 'CAD');
          break;
        case 'AU':
          detected = supportedCurrencies.firstWhere((c) => c['code'] == 'AUD');
          break;
        case 'SG':
          detected = supportedCurrencies.firstWhere((c) => c['code'] == 'SGD');
          break;
        case 'AE':
          detected = supportedCurrencies.firstWhere((c) => c['code'] == 'AED');
          break;
        default:
          final format = NumberFormat.simpleCurrency(locale: locale.toString());
          final symbol = format.currencySymbol;
          detected = supportedCurrencies.firstWhere(
            (c) => c['symbol'] == symbol || c['code'] == format.currencyName,
            orElse: () => supportedCurrencies.firstWhere((c) => c['code'] == 'INR', orElse: () => supportedCurrencies[0]),
          );
      }

      final chosen = detected;
      await setCurrency(chosen['code']!, chosen['symbol']!, chosen['name']!);
    } catch (_) {
      // Default to INR if in Indian locale or USD
      final isIndia = PlatformDispatcher.instance.locale.countryCode == 'IN';
      final chosen = isIndia
          ? supportedCurrencies.firstWhere((c) => c['code'] == 'INR')
          : supportedCurrencies.firstWhere((c) => c['code'] == 'USD');
      await setCurrency(chosen['code']!, chosen['symbol']!, chosen['name']!);
    }
  }

  Future<void> setCurrency(String code, String symbol, String name) async {
    currencySymbolNotifier.value = symbol;
    currencyCodeNotifier.value = code;
    currencyNameNotifier.value = name;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_currency_symbol', symbol);
    await prefs.setString('app_currency_code', code);
    await prefs.setString('app_currency_name', name);
  }
}
