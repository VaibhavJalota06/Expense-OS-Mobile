import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    if (user.email != null && user.email!.isNotEmpty) {
      await prefs.setString('google_user_email', user.email!);
    }
    final meta = user.userMetadata;
    if (meta != null) {
      final String? name = meta['full_name'] ?? meta['name'] ?? meta['display_name'];
      if (name != null && name.isNotEmpty) {
        await prefs.setString('custom_user_name', name);
      }
      final String? avatar = meta['avatar_url'] ?? meta['picture'];
      if (avatar != null && avatar.isNotEmpty) {
        await prefs.setString('google_user_avatar', avatar);
      }
    }
  }

  Future<AuthResponse> signUp({required String email, required String password}) async {
    final res = await client.auth.signUp(email: email, password: password);
    if (res.user != null) {
      await cacheUserData(res.user);
    }
    return res;
  }

  Future<AuthResponse> signIn({required String email, required String password}) async {
    final res = await client.auth.signInWithPassword(email: email, password: password);
    if (res.user != null) {
      await cacheUserData(res.user);
    }
    return res;
  }

  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('persistent_user_logged_in', true);
      if (googleUser.displayName != null && googleUser.displayName!.isNotEmpty) {
        await prefs.setString('custom_user_name', googleUser.displayName!);
      }
      await prefs.setString('google_user_email', googleUser.email);
      if (googleUser.photoUrl != null && googleUser.photoUrl!.isNotEmpty) {
        await prefs.setString('google_user_avatar', googleUser.photoUrl!);
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      final String redirectUrl = kIsWeb 
          ? Uri.base.origin 
          : 'com.expensecalculator.expenseosmobile://login-callback';

      if (idToken != null) {
        final response = await client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        return response.user != null;
      } else {
        await client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUrl,
          queryParams: {'prompt': 'select_account'},
        );
        return true;
      }
    } catch (e) {
      debugPrint('Google Native Sign-In Exception: $e');
      final String redirectUrl = kIsWeb 
          ? Uri.base.origin 
          : 'com.expensecalculator.expenseosmobile://login-callback';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('persistent_user_logged_in', true);

      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        queryParams: {'prompt': 'select_account'},
      );
      return true;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('persistent_user_logged_in', false);
    await client.auth.signOut();
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
    return 'b9290592-fbb4-4c33-b0bb-f35e2d8226d4';
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

          for (var item in response['subscriptions']) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final type = map['type']?.toString();
              if (type == 'savings_goal') {
                cloudGoals.add(map);
              } else if (type == 'split_bill') {
                cloudGroup.add(map);
              } else if (type == 'system_financial_meta') {
                if (map['starting_balance'] != null) {
                  final b = (map['starting_balance'] as num).toDouble();
                  await prefs.setDouble('user_starting_balance', b);
                }
              } else {
                cloudSubs.add(map);
              }
            }
          }

          await prefs.setString('user_saved_subscriptions', jsonEncode(cloudSubs));
          await prefs.setString('monex_goals', jsonEncode(cloudGoals));
          if (cloudGroup.isNotEmpty) {
            await prefs.setString('saved_group_expenses', jsonEncode(cloudGroup));
          }
        }

        _localExpenses.clear();
        _localExpenses.addAll(cloudItems);
        _localExpenses.removeWhere((e) => e.id == 'initial_account_balance' || e.title == 'Total Account Money' || e.title == 'Initial Account Balance');
        _localExpenses.sort((a, b) => b.date.compareTo(a.date));
        await _persistLocalExpenses();

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

  // Delete expense by ID with instant cloud sync to Web App
  Future<void> deleteExpense(String id) async {
    _localExpenses.removeWhere((e) => e.id == id);
    await _persistLocalExpenses();
    await _pushUserDataToCloud();
    refreshNotifier.value++;
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

        if (meta['monthly_budget_cap'] != null) {
          final cap = (meta['monthly_budget_cap'] as num).toDouble();
          await prefs.setDouble('monthly_budget_cap', cap);
        }
        if (meta['user_starting_balance'] != null) {
          final bal = (meta['user_starting_balance'] as num).toDouble();
          await prefs.setDouble('user_starting_balance', bal);
        }
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
