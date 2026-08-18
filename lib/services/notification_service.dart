import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/subscription_model.dart';

enum NotificationChannelType {
  budget,
  bills,
  streaks,
  rewards,
  anomalies,
  general,
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Distinct Android Notification Channels
  static const AndroidNotificationChannel _budgetChannel = AndroidNotificationChannel(
    'expense_os_budget',
    'Budget & Spending Alerts',
    description: 'Alerts when approaching or exceeding monthly spending limits',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _billsChannel = AndroidNotificationChannel(
    'expense_os_bills',
    'Bills & Subscription Due Dates',
    description: 'Upcoming recurring bill reminders and subscription due alerts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _streaksChannel = AndroidNotificationChannel(
    'expense_os_streaks',
    'Daily Streak & Logging Reminders',
    description: 'Reminders to log daily expenses and maintain logging streaks',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  static const AndroidNotificationChannel _rewardsChannel = AndroidNotificationChannel(
    'expense_os_rewards',
    'Rewards & Quest Milestones',
    description: 'Level up achievements, badges unlocked, and Emerald rewards',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _anomaliesChannel = AndroidNotificationChannel(
    'expense_os_anomalies',
    'Fraud & Anomaly Alerts',
    description: 'Duplicate charge warnings and unusual spending spike detection',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _generalChannel = AndroidNotificationChannel(
    'expense_os_general',
    'General Expense OS Notifications',
    description: 'General updates and system alerts',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false,
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

      // Create Android Notification Channels
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(_budgetChannel);
          await androidImpl.createNotificationChannel(_billsChannel);
          await androidImpl.createNotificationChannel(_streaksChannel);
          await androidImpl.createNotificationChannel(_rewardsChannel);
          await androidImpl.createNotificationChannel(_anomaliesChannel);
          await androidImpl.createNotificationChannel(_generalChannel);
          await androidImpl.requestNotificationsPermission();
        }
      }

      // Request iOS Permissions
      if (Platform.isIOS) {
        final iosImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully on ${Platform.operatingSystem}');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Request permissions on-demand (e.g. from Settings UI)
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidImpl?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS) {
        final iosImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return true;
  }

  /// Base method to show notification on Android & iOS
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    NotificationChannelType channelType = NotificationChannelType.general,
    String? payload,
  }) async {
    final channel = _getChannel(channelType);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: channel.importance == Importance.max ? Priority.high : Priority.defaultPriority,
      showWhen: true,
      enableVibration: channel.enableVibration,
      playSound: channel.playSound,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
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

  AndroidNotificationChannel _getChannel(NotificationChannelType type) {
    switch (type) {
      case NotificationChannelType.budget:
        return _budgetChannel;
      case NotificationChannelType.bills:
        return _billsChannel;
      case NotificationChannelType.streaks:
        return _streaksChannel;
      case NotificationChannelType.rewards:
        return _rewardsChannel;
      case NotificationChannelType.anomalies:
        return _anomaliesChannel;
      case NotificationChannelType.general:
        return _generalChannel;
    }
  }

  /// 1. Budget Cap Alerts
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
        channelType: NotificationChannelType.budget,
      );
    } else if (ratio >= 0.8) {
      await showNotification(
        id: 102,
        title: '🔔 80% Budget Threshold Reached',
        body: 'You have used ${(ratio * 100).toInt()}% of your monthly limit ($currencySymbol${totalSpent.toStringAsFixed(0)} / $currencySymbol${budgetCap.toStringAsFixed(0)}).',
        channelType: NotificationChannelType.budget,
      );
    }
  }

  /// 2. Upcoming Subscription & Recurring Bill Alerts
  Future<void> checkUpcomingBills(
    List<SubscriptionItem> subscriptions, {
    String currencySymbol = '\$',
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var bill in subscriptions) {
      if (bill.remindOnDueDate && !bill.isPaid) {
        final due = DateTime(bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);
        final diffDays = due.difference(today).inDays;

        if (diffDays == 0) {
          await showNotification(
            id: (bill.id.hashCode.abs() % 90000) + 1000,
            title: '⏰ Due Today: ${bill.title}',
            body: 'Your recurring bill of $currencySymbol${bill.amount.toStringAsFixed(2)} is due today.',
            channelType: NotificationChannelType.bills,
          );
        } else if (diffDays == 1) {
          await showNotification(
            id: (bill.id.hashCode.abs() % 90000) + 2000,
            title: '📅 Due Tomorrow: ${bill.title}',
            body: 'Upcoming payment of $currencySymbol${bill.amount.toStringAsFixed(2)} due tomorrow.',
            channelType: NotificationChannelType.bills,
          );
        }
      }
    }
  }

  /// 3. Daily Logging Streak Reminder
  Future<void> showDailyStreakReminder({required int streakDays}) async {
    final streakText = streakDays > 0 ? '🔥 $streakDays-Day Streak Active!' : '🚀 Start Your Streak Today!';
    await showNotification(
      id: 301,
      title: streakText,
      body: 'Keep your financial goals on track! Take 15 seconds to log your daily expenses.',
      channelType: NotificationChannelType.streaks,
    );
  }

  /// 4. Gamification Level Stage Upgrade
  Future<void> showStageUpgradeNotification({
    required String stageTitle,
    required int emeraldBonus,
  }) async {
    await showNotification(
      id: 401,
      title: '🎉 Stage Upgrade: $stageTitle!',
      body: 'Congratulations! You leveled up and earned +$emeraldBonus Emeralds 💎.',
      channelType: NotificationChannelType.rewards,
    );
  }

  /// 5. Fraud & Duplicate Anomaly Alert
  Future<void> showAnomalyAlert({
    required String title,
    required String message,
  }) async {
    await showNotification(
      id: 501,
      title: '🚨 $title',
      body: message,
      channelType: NotificationChannelType.anomalies,
    );
  }

  /// 6. Test Notification (Used in Settings / Tools Hub)
  Future<void> showTestNotification() async {
    await showNotification(
      id: 999,
      title: '✨ Expense OS Notifications Active!',
      body: 'Smart budget alerts, bill reminders, and streak notifications are ready on your device.',
      channelType: NotificationChannelType.general,
    );
  }

  /// Cancel specific notification by ID
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
