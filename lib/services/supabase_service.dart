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
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_localExpenses.map((e) => e.toJson()).toList());
      await prefs.setString('local_offline_expenses', encoded);
    } catch (_) {}
  }

  Future<void> _loadLocalExpenses() async {
    if (_localExpenses.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_offline_expenses');
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        _localExpenses.clear();
        _localExpenses.addAll(decoded.map((e) => Expense.fromJson(e)).toList());
      }
    } catch (_) {}
  }

  // Fetch expenses with seamless bidirectional cloud sync
  Future<List<Expense>> getExpenses() async {
    await _loadLocalExpenses();
    try {
      final response = await client
          .from('expenses')
          .select()
          .order('date', ascending: false);
      
      final List<dynamic> data = response as List<dynamic>;
      final cloudList = data.map((json) => Expense.fromJson(json)).toList();

      final Map<String, Expense> mergedMap = {};
      for (var exp in cloudList) {
        if (exp.id != null) mergedMap[exp.id!] = exp;
      }

      // Sync any unsynced local expenses to Supabase cloud
      for (var local in _localExpenses) {
        if (local.id != null && !mergedMap.containsKey(local.id)) {
          mergedMap[local.id!] = local;
          try {
            final json = local.toJson();
            if (currentUser != null) json['user_id'] = currentUser!.id;
            await client.from('expenses').upsert(json);
          } catch (_) {}
        }
      }

      _localExpenses.clear();
      _localExpenses.addAll(mergedMap.values);
      _localExpenses.sort((a, b) => b.date.compareTo(a.date));
      await _persistLocalExpenses();
      return List.unmodifiable(_localExpenses);
    } catch (e) {
      return List.unmodifiable(_localExpenses);
    }
  }

  List<Expense> get localExpenses => List.unmodifiable(_localExpenses);

  // Static global refresh notifier for real-time automatic screen updates
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  // Add new expense with graceful fallback
  Future<Expense> addExpense(Expense expense) async {
    await _loadLocalExpenses();
    final Map<String, dynamic> json = expense.toJson();
    if (currentUser != null) {
      json['user_id'] = currentUser!.id;
    }

    try {
      final response = await client
          .from('expenses')
          .insert(json)
          .select()
          .single();
      
      final result = Expense.fromJson(response);
      _localExpenses.insert(0, result);
      await _persistLocalExpenses();
      refreshNotifier.value++;
      return result;
    } catch (e) {
      // Fallback to local persistent storage
      final localItem = expense.copyWith(
        id: expense.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      );
      _localExpenses.insert(0, localItem);
      await _persistLocalExpenses();
      refreshNotifier.value++;
      return localItem;
    }
  }

  // Update existing expense
  Future<Expense> updateExpense(Expense expense) async {
    if (expense.id == null) throw Exception("Expense ID cannot be null for update");

    try {
      final response = await client
          .from('expenses')
          .update(expense.toJson())
          .eq('id', expense.id!)
          .select()
          .single();

      final result = Expense.fromJson(response);
      final index = _localExpenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _localExpenses[index] = result;
      }
      await _persistLocalExpenses();
      refreshNotifier.value++;
      return result;
    } catch (e) {
      final index = _localExpenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _localExpenses[index] = expense;
      }
      await _persistLocalExpenses();
      refreshNotifier.value++;
      return expense;
    }
  }

  // Delete expense by ID
  Future<void> deleteExpense(String id) async {
    try {
      await client.from('expenses').delete().eq('id', id);
    } catch (e) {
      // ignore
    } finally {
      _localExpenses.removeWhere((e) => e.id == id);
      await _persistLocalExpenses();
      refreshNotifier.value++;
    }
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
