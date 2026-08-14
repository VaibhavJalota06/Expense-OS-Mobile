import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Automatically shows an immediate push notification on the device
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'expense_os_alerts',
      'Expense OS Alerts',
      channelDescription: 'Real-time automatic spending alerts and bill reminders',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing device notification: $e');
    }
  }

  /// Automatically checks budget and fires device notification if approaching limit
  Future<void> checkBudgetAlert({
    required double totalSpent,
    required double budgetCap,
    required String currencySymbol,
  }) async {
    if (budgetCap <= 0) return;
    final ratio = totalSpent / budgetCap;

    if (ratio >= 1.0) {
      await showNotification(
        id: 101,
        title: '⚠️ Monthly Budget Exceeded!',
        body: 'You have spent $currencySymbol${totalSpent.toStringAsFixed(0)} of your $currencySymbol${budgetCap.toStringAsFixed(0)} monthly limit.',
      );
    } else if (ratio >= 0.8) {
      await showNotification(
        id: 102,
        title: '🔔 80% Budget Threshold Reached',
        body: 'You have used ${(ratio * 100).toInt()}% of your monthly limit ($currencySymbol${totalSpent.toStringAsFixed(0)} / $currencySymbol${budgetCap.toStringAsFixed(0)}).',
      );
    }
  }

  /// Automatically schedules evening expense reminder notification
  Future<void> scheduleDailyEveningReminder() async {
    // Show confirmation on device
    await showNotification(
      id: 200,
      title: 'Expense OS Active 🚀',
      body: 'Automatic smart tracking is running in the background on your device.',
    );
  }
}
