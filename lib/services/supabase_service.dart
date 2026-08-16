import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';

class SupabaseService {
  static const String supabaseUrl = "https://gtwirhvswhslljbfvnoe.supabase.co";
  static const String supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd0d2lyaHZzd2hzbGxqYmZ2bm9lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3NjQyOTAsImV4cCI6MjEwMTM0MDI5MH0.b9oppdNo7S6RYizvaC5ZgRWuSjceqZMFXT63mXid1tQ";

  // Singleton instance
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  SupabaseClient? get safeClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isInitialized => safeClient != null;

  // Initialize Supabase Flutter Client
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  // --- AUTHENTICATION ---
  User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }
  bool get isAuthenticated => currentUser != null;

  // Helper to persist user details in SharedPreferences
  static Future<void> cacheUserData(User? user) async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('persistent_user_logged_in', true);
    if (user.id.isNotEmpty) {
      await prefs.setString('supabase_user_id', user.id);
    }
    if (user.email != null && user.email!.isNotEmpty) {
      await prefs.setString('google_user_email', user.email!);
    }
    final meta = user.userMetadata;
    if (meta != null) {
      final String? name = meta['full_name'] ?? meta['name'] ?? meta['display_name'];
      if (name != null && name.isNotEmpty) {
        await prefs.setString('custom_user_name', name);
      }
      final String? avatar = meta['avatar_url'] ?? meta['picture'] ?? meta['avatar'];
      if (avatar != null && avatar.isNotEmpty) {
        await prefs.setString('google_user_avatar', avatar);
      }
    }
  }

  Future<AuthResponse> signUp({required String email, required String password}) async {
    final res = await client.auth.signUp(email: email, password: password);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('persistent_user_logged_in', true);
    if (res.user != null) {
      await cacheUserData(res.user);
    }
    return res;
  }

  Future<AuthResponse> signIn({required String email, required String password}) async {
    final res = await client.auth.signInWithPassword(email: email, password: password);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('persistent_user_logged_in', true);
    if (res.user != null) {
      await cacheUserData(res.user);
    }
    return res;
  }

  Future<bool> signInWithGoogle() async {
    try {
      final String redirectUrl = kIsWeb 
          ? Uri.base.origin 
          : 'com.expensecalculator.expenseosmobile://login-callback';

      final success = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: {'prompt': 'select_account'},
      );
      return success;
    } catch (e) {
      debugPrint('Google OAuth Sign-In Exception: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('persistent_user_logged_in');
    await prefs.remove('google_user_email');
    await prefs.remove('custom_user_name');
    await prefs.remove('google_user_avatar');
    await prefs.remove('custom_avatar_path');
    await prefs.remove('supabase_user_id');
    try {
      await client.auth.signOut();
    } catch (_) {}
  }

  // --- EXPENSE CRUD OPERATIONS ---
  
  // Memory and disk fallback list
  final List<Expense> _localExpenses = [];

  Future<void> _persistLocalExpenses() async {
    try {
      _localExpenses.removeWhere((e) => e.id == 'initial_account_balance' || e.title == 'Total Account Money' || e.title == 'Initial Account Balance');
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_localExpenses.map((e) => e.toJson()).toList());
      await prefs.setString('local_offline_expenses', encoded);
    } catch (_) {}
  }

  Future<void> _loadLocalExpenses() async {
    if (_localExpenses.isNotEmpty) {
      _localExpenses.removeWhere((e) => e.id == 'initial_account_balance' || e.title == 'Total Account Money' || e.title == 'Initial Account Balance');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_offline_expenses');
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        _localExpenses.clear();
        _localExpenses.addAll(decoded.map((e) => Expense.fromJson(e)).toList());
        _localExpenses.removeWhere((e) => e.id == 'initial_account_balance' || e.title == 'Total Account Money' || e.title == 'Initial Account Balance');
      }
    } catch (_) {}
  }

  Future<String> _getEffectiveUserId() async {
    if (currentUser != null && currentUser!.id.isNotEmpty) {
      return currentUser!.id;
    }
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('supabase_user_id');
    if (cached != null && cached.isNotEmpty) return cached;
    return 'local_device_user';
  }

  Future<void> _pushUserDataToCloud() async {
    try {
      final userId = await _getEffectiveUserId();
      final prefs = await SharedPreferences.getInstance();
      final budget = prefs.getDouble('monthly_budget_cap') ?? 0.0;
      final balance = prefs.getDouble('user_starting_balance') ?? 0.0;
      final currency = prefs.getString('app_currency_symbol') == '\$' ? 'USD' : 'INR';

      final webExpenses = _localExpenses
          .where((e) => e.type == 'expense')
          .map((e) => e.toJson())
          .toList();

      final webIncomes = _localExpenses
          .where((e) => e.type == 'income' && e.id != 'initial_account_balance' && e.title != 'Total Account Money')
          .map((e) => e.toIncomeJson())
          .toList();

      final List<Map<String, dynamic>> bundledSubs = [];

      // Subscriptions / Recurring Bills
      final rawSubs = prefs.getString('user_saved_subscriptions');
      if (rawSubs != null && rawSubs.isNotEmpty) {
        try {
          final List decoded = jsonDecode(rawSubs);
          for (var item in decoded) {
            if (item is Map) {
              final m = Map<String, dynamic>.from(item);
              m['type'] = 'subscription';
              m['name'] = m['title'] ?? m['name'] ?? 'Subscription';
              m['dueDay'] = m['dueDay'] ?? (m['due_date'] != null ? DateTime.tryParse(m['due_date'].toString())?.day : 15) ?? 15;
              bundledSubs.add(m);
            }
          }
        } catch (_) {}
      }

      // Savings Goals
      final rawGoals = prefs.getString('monex_goals');
      if (rawGoals != null && rawGoals.isNotEmpty) {
        try {
          final List decoded = jsonDecode(rawGoals);
          for (var item in decoded) {
            if (item is Map) {
              final m = Map<String, dynamic>.from(item);
              m['type'] = 'savings_goal';
              m['name'] = m['title'] ?? m['name'] ?? 'Goal';
              bundledSubs.add(m);
            }
          }
        } catch (_) {}
      }

      // Group Expenses / Split Bills
      final rawGroup = prefs.getString('saved_group_expenses');
      if (rawGroup != null && rawGroup.isNotEmpty) {
        try {
          final List decoded = jsonDecode(rawGroup);
          for (var item in decoded) {
            if (item is Map) {
              final m = Map<String, dynamic>.from(item);
              m['type'] = 'split_bill';
              bundledSubs.add(m);
            }
          }
        } catch (_) {}
      }

      // System Financial Meta (Starting Balance / Total Money)
      bundledSubs.add({
        'id': 'system_financial_meta',
        'type': 'system_financial_meta',
        'starting_balance': balance,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await client.from('user_data').upsert({
        'user_id': userId,
        'budget': budget,
        'expenses': webExpenses,
        'incomes': webIncomes,
        'subscriptions': bundledSubs,
        'currency': currency,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {}
  }

  Future<void> pushAllDataToCloud() async {
    await _pushUserDataToCloud();
  }

  // Fetch expenses with seamless bidirectional cloud sync with Web App user_data
  Future<List<Expense>> getExpenses() async {
    await _loadLocalExpenses();
    try {
      final userId = await _getEffectiveUserId();
      final response = await client
          .from('user_data')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        final prefs = await SharedPreferences.getInstance();
        
        if (response['budget'] != null) {
          final cloudBudget = (response['budget'] as num).toDouble();
          await prefs.setDouble('monthly_budget_cap', cloudBudget);
        }

        final List<Expense> cloudItems = [];
        if (response['expenses'] is List) {
          for (var exp in response['expenses']) {
            if (exp is Map) {
              cloudItems.add(Expense.fromJson(Map<String, dynamic>.from(exp)));
            }
          }
        }

        if (response['incomes'] is List) {
          for (var inc in response['incomes']) {
            if (inc is Map) {
              if (inc['id'] != 'initial_account_balance' && inc['is_system_balance'] != true) {
                cloudItems.add(Expense.fromJson(Map<String, dynamic>.from(inc)));
              }
            }
          }
        }

        if (response['subscriptions'] is List) {
          final List<Map<String, dynamic>> cloudSubs = [];
          final List<Map<String, dynamic>> cloudGoals = [];
          final List<Map<String, dynamic>> cloudGroup = [];
          bool foundMeta = false;

          for (var item in response['subscriptions']) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final type = map['type']?.toString();
              if (type == 'savings_goal') {
                cloudGoals.add(map);
              } else if (type == 'split_bill') {
                cloudGroup.add(map);
              } else if (type == 'system_financial_meta') {
                foundMeta = true;
                final b = (map['starting_balance'] as num?)?.toDouble() ?? 0.0;
                await prefs.setDouble('user_starting_balance', b);
              } else {
                cloudSubs.add(map);
              }
            }
          }

          if (!foundMeta) {
            await prefs.setDouble('user_starting_balance', 0.0);
          }

          await prefs.setString('user_saved_subscriptions', jsonEncode(cloudSubs));
          await prefs.setString('monex_goals', jsonEncode(cloudGoals));
          if (cloudGroup.isNotEmpty) {
            await prefs.setString('saved_group_expenses', jsonEncode(cloudGroup));
          } else {
            await prefs.remove('saved_group_expenses');
          }
        } else {
          await prefs.setDouble('user_starting_balance', 0.0);
          await prefs.remove('user_saved_subscriptions');
          await prefs.remove('monex_goals');
          await prefs.remove('saved_group_expenses');
        }

        _localExpenses.clear();
        _localExpenses.addAll(cloudItems);
        _localExpenses.removeWhere((e) => e.id == 'initial_account_balance' || e.title == 'Total Account Money' || e.title == 'Initial Account Balance');
        _localExpenses.sort((a, b) => b.date.compareTo(a.date));
        await _persistLocalExpenses();
        await cleanOrphanedExpenses();

        return List.unmodifiable(_localExpenses);
      }
    } catch (e) {
      debugPrint('Error syncing with user_data: $e');
    }
    return List.unmodifiable(_localExpenses);
  }

  List<Expense> get localExpenses => List.unmodifiable(_localExpenses);

  // Static global refresh notifier for real-time automatic screen updates
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);
  static RealtimeChannel? _userDataChannel;

  Future<void> startRealtimeSync() async {
    final userId = await _getEffectiveUserId();
    if (_userDataChannel != null) {
      client.removeChannel(_userDataChannel!);
    }
    _userDataChannel = client
        .channel('public:user_data:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_data',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            await getExpenses();
            refreshNotifier.value++;
          },
        )
        .subscribe();
  }

  // Add new expense with instant cloud sync to Web App
  Future<Expense> addExpense(Expense expense) async {
    await _loadLocalExpenses();
    final localItem = expense.copyWith(
      id: expense.id ?? 'exp_${DateTime.now().millisecondsSinceEpoch}',
    );
    _localExpenses.insert(0, localItem);
    await _persistLocalExpenses();
    await _pushUserDataToCloud();
    refreshNotifier.value++;
    return localItem;
  }

  // Update existing expense with instant cloud sync to Web App
  Future<Expense> updateExpense(Expense expense) async {
    if (expense.id == null) throw Exception("Expense ID cannot be null for update");
    final index = _localExpenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _localExpenses[index] = expense;
    }
    await _persistLocalExpenses();
    await _pushUserDataToCloud();
    refreshNotifier.value++;
    return expense;
  }

  // Delete expense by ID with instant cloud sync to Web App & unmarking subscription if needed
  Future<void> deleteExpense(String id) async {
    await _loadLocalExpenses();
    final index = _localExpenses.indexWhere((e) => e.id == id);
    if (index != -1) {
      final deleted = _localExpenses.removeAt(index);
      await _persistLocalExpenses();

      // If this was a bill payment expense, unmark the recurring bill as paid
      final cleanTitle = deleted.title.trim();
      if (cleanTitle.toLowerCase().startsWith('bill payment: ')) {
        final billName = cleanTitle.substring(14).trim().toLowerCase();
        final prefs = await SharedPreferences.getInstance();
        final rawSubs = prefs.getString('user_saved_subscriptions');
        if (rawSubs != null && rawSubs.isNotEmpty) {
          try {
            final List decoded = jsonDecode(rawSubs);
            bool updated = false;
            for (var item in decoded) {
              if (item is Map) {
                final t = (item['title'] ?? item['name'])?.toString().trim().toLowerCase();
                if (t == billName) {
                  item['is_paid'] = false;
                  item['isPaid'] = false;
                  item['lastPaidMonth'] = null;
                  item['last_paid_date'] = null;
                  item['lastPaidDate'] = null;
                  updated = true;
                }
              }
            }
            if (updated) {
              await prefs.setString('user_saved_subscriptions', jsonEncode(decoded));
            }
          } catch (_) {}
        }
      }

      await _pushUserDataToCloud();
      refreshNotifier.value++;
    }
  }

  // Cascade delete all expense entries associated with a deleted subscription
  Future<void> cascadeDeleteSubscriptionExpenses(String subscriptionId, String title) async {
    await _loadLocalExpenses();
    final cleanTitle = title.trim().toLowerCase();
    _localExpenses.removeWhere((e) {
      if (e.id != null && e.id!.startsWith('bill_pay_$subscriptionId')) return true;
      final t = e.title.trim().toLowerCase();
      if (t == 'bill payment: $cleanTitle' || t == '$cleanTitle (subscription)' || t == '$cleanTitle (recurring bill)') {
        return true;
      }
      return false;
    });
    await _persistLocalExpenses();
    await _pushUserDataToCloud();
    refreshNotifier.value++;
  }

  // Cascade delete all expense and income entries associated with a deleted group/split bill
  Future<void> cascadeDeleteGroupExpense(String groupId, String title, String paidBy) async {
    await _loadLocalExpenses();
    final cleanTitle = title.trim().toLowerCase();
    _localExpenses.removeWhere((e) {
      final t = e.title.trim().toLowerCase();
      if (t == '$cleanTitle (my split share)') return true;
      if (t.startsWith('paid ') && t.contains('for $cleanTitle (settled share)')) return true;
      if (t.startsWith('reimbursement from ') && t.contains('($cleanTitle)')) return true;
      return false;
    });
    await _persistLocalExpenses();
    await removeGroupExpense(groupId);
    await _pushUserDataToCloud();
    refreshNotifier.value++;
  }

  // Clean any orphaned expenses whose parent subscription or split bill was deleted
  Future<void> cleanOrphanedExpenses() async {
    await _loadLocalExpenses();
    final prefs = await SharedPreferences.getInstance();
    final rawSubs = prefs.getString('user_saved_subscriptions');
    final List<String> validSubTitles = [];
    if (rawSubs != null && rawSubs.isNotEmpty) {
      try {
        final List decoded = jsonDecode(rawSubs);
        for (var item in decoded) {
          if (item is Map) {
            final t = (item['title'] ?? item['name'])?.toString().trim().toLowerCase();
            if (t != null && t.isNotEmpty) validSubTitles.add(t);
          }
        }
      } catch (_) {}
    }

    final rawGroup = prefs.getString('saved_group_expenses');
    final List<String> validGroupTitles = [];
    if (rawGroup != null && rawGroup.isNotEmpty) {
      try {
        final List decoded = jsonDecode(rawGroup);
        for (var item in decoded) {
          if (item is Map) {
            final t = (item['title'] ?? item['name'])?.toString().trim().toLowerCase();
            if (t != null && t.isNotEmpty) validGroupTitles.add(t);
          }
        }
      } catch (_) {}
    }

    bool removedAny = false;
    _localExpenses.removeWhere((e) {
      final t = e.title.trim().toLowerCase();
      if (t.startsWith('bill payment: ')) {
        final billName = t.replaceFirst('bill payment: ', '').trim();
        if (!validSubTitles.contains(billName)) {
          removedAny = true;
          return true;
        }
      }
      if (t.endsWith(' (my split share)')) {
        final groupName = t.replaceFirst(' (my split share)', '').trim();
        if (!validGroupTitles.contains(groupName)) {
          removedAny = true;
          return true;
        }
      }
      if (t.startsWith('reimbursement from ') && t.endsWith(')')) {
        final groupName = t.substring(t.lastIndexOf('(') + 1, t.lastIndexOf(')')).trim();
        if (!validGroupTitles.contains(groupName)) {
          removedAny = true;
          return true;
        }
      }
      return false;
    });

    if (removedAny) {
      await _persistLocalExpenses();
      await _pushUserDataToCloud();
      refreshNotifier.value++;
    }
  }

  // Complete clean reset of local and Supabase cloud financial data
  Future<void> resetAllFinancialData() async {
    _localExpenses.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_offline_expenses');
    await prefs.remove('user_saved_subscriptions');
    await prefs.remove('monex_goals');
    await prefs.remove('monthly_budget_cap');
    await prefs.remove('user_starting_balance');
    await prefs.remove('saved_group_expenses');
    
    try {
      final userId = await _getEffectiveUserId();
      await client.from('user_data').upsert({
        'user_id': userId,
        'budget': 0.0,
        'expenses': [],
        'incomes': [],
        'subscriptions': [],
        'currency': 'INR',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {}

    refreshNotifier.value++;
  }

  // --- CROSS-PLATFORM (MOBILE, WEB, DESKTOP) GROUP EXPENSES CLOUD SYNC ---

  Future<List<Map<String, dynamic>>> getGroupExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_group_expenses');
    List<Map<String, dynamic>> localList = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final List decoded = jsonDecode(raw);
        localList = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    try {
      final response = await client
          .from('group_expenses')
          .select()
          .order('date', ascending: false);
      final List<dynamic> data = response as List<dynamic>;
      final cloudList = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (cloudList.isNotEmpty) {
        // Cache to local storage
        await prefs.setString('saved_group_expenses', jsonEncode(cloudList));
        return cloudList;
      }
      return localList;
    } catch (_) {
      return localList;
    }
  }

  Future<void> saveGroupExpense(Map<String, dynamic> itemJson) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_group_expenses');
    List<Map<String, dynamic>> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final List decoded = jsonDecode(raw);
        list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final id = itemJson['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    itemJson['id'] = id;
    if (currentUser != null) {
      itemJson['user_id'] = currentUser!.id;
    }

    final existingIndex = list.indexWhere((e) => e['id'] == id);
    if (existingIndex != -1) {
      list[existingIndex] = itemJson;
    } else {
      list.insert(0, itemJson);
    }
    await prefs.setString('saved_group_expenses', jsonEncode(list));

    try {
      await client.from('group_expenses').upsert(itemJson);
    } catch (_) {}
  }

  Future<void> removeGroupExpense(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_group_expenses');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List decoded = jsonDecode(raw);
        final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        list.removeWhere((e) => e['id'] == id);
        await prefs.setString('saved_group_expenses', jsonEncode(list));
      } catch (_) {}
    }

    try {
      await client.from('group_expenses').delete().eq('id', id);
    } catch (_) {}
  }

  // --- CROSS-PLATFORM USER PROFILE & FINANCIAL SETTINGS CLOUD SYNC ---

  static Future<void> syncFinancialProfileToCloud({
    double? budgetCap,
    double? startingBalance,
    String? currencySymbol,
    String? customName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (budgetCap != null) await prefs.setDouble('monthly_budget_cap', budgetCap);
    if (startingBalance != null) await prefs.setDouble('user_starting_balance', startingBalance);
    if (currencySymbol != null) await prefs.setString('app_currency_symbol', currencySymbol);
    if (customName != null) await prefs.setString('custom_user_name', customName);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final Map<String, dynamic> meta = Map.from(user.userMetadata ?? {});
        if (budgetCap != null) meta['monthly_budget_cap'] = budgetCap;
        if (startingBalance != null) meta['user_starting_balance'] = startingBalance;
        if (currencySymbol != null) meta['app_currency_symbol'] = currencySymbol;
        if (customName != null) meta['custom_user_name'] = customName;

        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: meta),
        );
      }
    } catch (_) {}

    try {
      await SupabaseService()._pushUserDataToCloud();
      refreshNotifier.value++;
    } catch (_) {}
  }

  static Future<void> loadFinancialProfileFromCloud() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        final meta = user.userMetadata!;
        final prefs = await SharedPreferences.getInstance();

        if (meta['app_currency_symbol'] != null) {
          await prefs.setString('app_currency_symbol', meta['app_currency_symbol'].toString());
        }
        if (meta['custom_user_name'] != null) {
          await prefs.setString('custom_user_name', meta['custom_user_name'].toString());
        }
      }
    } catch (_) {}
  }
}
