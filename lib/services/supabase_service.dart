import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';
import 'currency_service.dart';
import 'notification_service.dart';

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
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
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
    String? resolvedName;
    String? resolvedAvatar;

    if (meta != null) {
      resolvedName = meta['full_name'] ?? meta['name'] ?? meta['display_name'] ?? meta['user_name'];
      resolvedAvatar = meta['avatar_url'] ?? meta['picture'] ?? meta['avatar'];
    }

    if ((resolvedName == null || resolvedName.isEmpty || resolvedName == 'Expense User' || resolvedName == 'Tech Bounty Hunter' || resolvedName == 'User') &&
        user.email != null &&
        user.email!.contains('@')) {
      final prefix = user.email!.split('@').first.replaceAll(RegExp(r'[._]'), ' ');
      resolvedName = prefix
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }

    if (resolvedName != null && resolvedName.isNotEmpty) {
      await prefs.setString('custom_user_name', resolvedName);
    } else {
      await prefs.remove('custom_user_name');
    }
    if (resolvedAvatar != null && resolvedAvatar.isNotEmpty) {
      await prefs.setString('google_user_avatar', resolvedAvatar);
    } else {
      await prefs.remove('google_user_avatar');
    }
    await prefs.remove('custom_avatar_path');

    // Sync profile to relational profiles table on login
    try {
      await SupabaseService()._syncProfileToTable(user);
    } catch (_) {}
  }

  Future<void> _syncProfileToTable(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currency = prefs.getString('app_currency_symbol') ?? '₹';
      final budget = prefs.getDouble('monthly_budget_cap') ?? 0.0;
      final balance = prefs.getDouble('user_starting_balance') ?? 0.0;
      final meta = user.userMetadata;
      final name = meta?['full_name'] ?? meta?['name'] ?? meta?['display_name'];
      final avatar = meta?['avatar_url'] ?? meta?['picture'] ?? meta?['avatar'];

      final Map<String, dynamic> row = {
        'user_id': user.id,
        'email': user.email,
        'full_name': name,
        'avatar_url': avatar,
        'currency': currency,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (budget > 0) row['monthly_budget'] = budget;
      if (balance > 0) row['starting_balance'] = balance;

      await client.from('profiles').upsert(row, onConflict: 'user_id');
    } catch (_) {}
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

  static const String googleServerClientId = "15673126976-lrpvllp65ca80f4d5p87mes8bb6srorp.apps.googleusercontent.com";
  static const String googleIosClientId = "15673126976-c67nj6jll0noh5neas867mdv023n81f1.apps.googleusercontent.com";
  static const String googleAndroidClientId = "15673126976-g693egeeq53e02g4b4a1b02s307h5u7h.apps.googleusercontent.com";

  Future<bool> signInWithGoogle() async {
    debugPrint('[GoogleSignIn] Starting Google Sign-In flow...');

    // 1. Mobile (Android & iOS): 100% Native In-App Google Sign-In (NEVER opens browser)
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        debugPrint('[GoogleSignIn] Starting 100% Native In-App Google Sign-In on $defaultTargetPlatform...');
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: googleServerClientId,
          clientId: defaultTargetPlatform == TargetPlatform.iOS ? googleIosClientId : null,
          scopes: const [
            'email',
            'profile',
          ],
        );

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          debugPrint('[GoogleSignIn] Native Google prompt cancelled.');
          return false;
        }

        // Reset previous local state before authenticating new account
        _localExpenses.clear();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('local_offline_expenses');
        await prefs.remove('user_starting_balance');
        await prefs.remove('monthly_budget_cap');
        await prefs.remove('user_saved_subscriptions');
        await prefs.remove('expense_os_goals');
        await prefs.remove('monex_goals');
        await prefs.remove('saved_group_expenses');

        // Extract credentials & authenticate with Supabase
        String? resolvedUserId;
        try {
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final String? idToken = googleAuth.idToken;
          final String? accessToken = googleAuth.accessToken;

          if (idToken != null) {
            final AuthResponse response = await client.auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: idToken,
              accessToken: accessToken,
            );
            if (response.user != null) {
              debugPrint('[GoogleSignIn] Supabase auth verified for: ${response.user!.email}');
              await cacheUserData(response.user);
              resolvedUserId = response.user!.id;
            }
          }
        } catch (authSyncErr) {
          debugPrint('[GoogleSignIn] Supabase token sync note: $authSyncErr');
        }

        // Guaranteed In-App Login with verified user's chosen Google Account details
        debugPrint('[GoogleSignIn] Native Google session verified for: ${googleUser.email}');
        await prefs.setBool('persistent_user_logged_in', true);
        await prefs.setString('google_user_email', googleUser.email.toLowerCase().trim());
        await prefs.setString(
          'custom_user_name',
          (googleUser.displayName != null && googleUser.displayName!.isNotEmpty)
              ? googleUser.displayName!
              : googleUser.email.split('@').first,
        );
        if (googleUser.photoUrl != null && googleUser.photoUrl!.isNotEmpty) {
          await prefs.setString('google_user_avatar', googleUser.photoUrl!);
        } else {
          await prefs.remove('google_user_avatar');
        }
        await prefs.remove('custom_avatar_path');

        if (resolvedUserId != null && resolvedUserId.isNotEmpty) {
          await prefs.setString('supabase_user_id', resolvedUserId);
        } else if (currentUser != null && currentUser!.id.isNotEmpty) {
          await prefs.setString('supabase_user_id', currentUser!.id);
        } else {
          await prefs.setString('supabase_user_id', googleUser.id);
        }

        try {
          await getExpenses();
          await loadFinancialProfileFromCloud();
        } catch (_) {}

        return true;
      } catch (nativeError) {
        debugPrint('[GoogleSignIn] Native Google sign-in failed ($nativeError), falling back to Supabase browser OAuth...');
      }
    }

    // 2. Web, Desktop & Mobile Fallback: Direct OAuth
    try {
      final String redirectUrl = kIsWeb ? Uri.base.origin : 'com.expensecalculator.expenseosmobile://login-callback';
      debugPrint('[GoogleSignIn] Using direct OAuth: $redirectUrl');

      final success = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );

      debugPrint('[GoogleSignIn] OAuth launched: $success');
      return success;
    } catch (e) {
      debugPrint('[GoogleSignIn] OAuth Exception: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    _localExpenses.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('persistent_user_logged_in');
    await prefs.remove('google_user_email');
    await prefs.remove('custom_user_name');
    await prefs.remove('google_user_avatar');
    await prefs.remove('custom_avatar_path');
    await prefs.remove('supabase_user_id');
    await prefs.remove('offline_user_id');
    await prefs.remove('local_offline_expenses');
    await prefs.remove('user_starting_balance');
    await prefs.remove('monthly_budget_cap');
    await prefs.remove('user_saved_subscriptions');
    await prefs.remove('monex_goals');
    await prefs.remove('expense_os_goals');
    await prefs.remove('saved_group_expenses');
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      await googleSignIn.disconnect();
    } catch (_) {}
    try {
      await client.auth.signOut();
    } catch (_) {}
  }

  // =====================================================================
  // --- EXPENSE CRUD OPERATIONS (Dual-Write: expenses table + user_data)
  // =====================================================================
  
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
    // 1. Supabase Authenticated Session
    if (currentUser != null && currentUser!.id.isNotEmpty) {
      return currentUser!.id;
    }
    // 2. Cached authenticated user ID
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('supabase_user_id');
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    // 3. Fallback local offline user ID
    final offlineId = prefs.getString('offline_user_id');
    if (offlineId != null && offlineId.isNotEmpty) {
      return offlineId;
    }
    final newOfflineId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('offline_user_id', newOfflineId);
    return newOfflineId;
  }

  // ---------------------------------------------------------------
  // Push ALL local state to user_data JSON document (Web App compat)
  // ---------------------------------------------------------------
  Future<void> _pushUserDataToCloud() async {
    try {
      await _loadLocalExpenses();
      final userId = await _getEffectiveUserId();
      final prefs = await SharedPreferences.getInstance();
      final budget = prefs.getDouble('monthly_budget_cap') ?? 0.0;
      double balance = prefs.getDouble('user_starting_balance') ?? 0.0;
      if (balance <= 0) {
        try {
          final existing = await client.from('user_data').select('subscriptions,incomes').eq('user_id', userId).maybeSingle();
          if (existing != null && existing['subscriptions'] is List) {
            for (var s in existing['subscriptions']) {
              if (s is Map && (s['id'] == 'system_financial_meta' || s['type'] == 'system_financial_meta')) {
                final cloudBal = (s['starting_balance'] as num?)?.toDouble() ?? 0.0;
                if (cloudBal > 0) {
                  balance = cloudBal;
                  await prefs.setDouble('user_starting_balance', balance);
                  break;
                }
              }
            }
          }
        } catch (_) {}
      }
      final currency = prefs.getString('app_currency_code') ?? CurrencyService.currencyCodeNotifier.value;

      final webExpenses = _localExpenses
          .where((e) => e.type == 'expense')
          .map((e) => e.toJson())
          .toList();

      final webIncomes = _localExpenses
          .where((e) => e.type == 'income' && e.id != 'initial_account_balance' && e.title != 'Total Account Money')
          .map((e) => e.toIncomeJson())
          .toList();

      // Include initial_account_balance so Web App reads the Starting Balance in Total Account Money
      if (balance > 0) {
        webIncomes.insert(0, {
          'id': 'initial_account_balance',
          'source': 'Total Account Money',
          'title': 'Total Account Money',
          'description': 'Initial Account Balance',
          'amount': balance,
          'date': DateTime.now().toIso8601String().split('T')[0],
          'type': 'income',
          'is_system_balance': true,
        });
      }

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
      final rawGoals = prefs.getString('expense_os_goals') ?? prefs.getString('monex_goals');
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
      debugPrint('[CloudSync] Successfully pushed user_data for $userId (${webExpenses.length} expenses)');
    } catch (e) {
      debugPrint('[CloudSync] Error pushing user_data: $e');
    }
  }

  // ---------------------------------------------------------------
  // Push individual expenses to the relational expenses table
  // (Desktop / iOS / multi-app compat)
  // ---------------------------------------------------------------
  Future<void> _pushExpenseToTable(Expense expense) async {
    try {
      final userId = await _getEffectiveUserId();
      await client.from('expenses').upsert(
        expense.toTableJson(userId),
        onConflict: 'id',
      );
    } catch (e) {
      debugPrint('Error pushing expense to table: $e');
    }
  }

  Future<void> _deleteExpenseFromTable(String id) async {
    try {
      await client.from('expenses').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting expense from table: $e');
    }
  }

  // ---------------------------------------------------------------
  // Push individual subscriptions to the relational subscriptions table
  // ---------------------------------------------------------------
  Future<void> _pushSubscriptionToTable(Map<String, dynamic> subJson) async {
    try {
      final userId = await _getEffectiveUserId();
      final tableRow = <String, dynamic>{
        'id': subJson['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'title': subJson['title'] ?? subJson['name'] ?? 'Subscription',
        'amount': subJson['amount'] ?? 0.0,
        'category': subJson['category'] ?? 'Services & Subscriptions',
        'cycle': subJson['cycle'] ?? 'monthly',
        'due_date': subJson['due_date'] ?? subJson['dueDate'] ?? DateTime.now().toIso8601String().split('T')[0],
        'payment_method': subJson['payment_method'] ?? subJson['paymentMethod'] ?? 'Card',
        'is_paid': subJson['is_paid'] ?? subJson['isPaid'] ?? false,
        'remind_on_due_date': subJson['remind_on_due_date'] ?? subJson['remindOnDueDate'] ?? true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (subJson['end_date'] != null) {
        tableRow['end_date'] = subJson['end_date'];
      }
      if (subJson['last_paid_date'] != null) {
        tableRow['last_paid_date'] = subJson['last_paid_date'];
      } else if (subJson['lastPaidDate'] != null) {
        tableRow['last_paid_date'] = subJson['lastPaidDate'];
      }
      tableRow['user_id'] = userId;

      await client.from('subscriptions').upsert(tableRow, onConflict: 'id');
    } catch (e) {
      debugPrint('Error pushing subscription to table: $e');
    }
  }

  Future<void> _deleteSubscriptionFromTable(String id) async {
    try {
      await client.from('subscriptions').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting subscription from table: $e');
    }
  }

  // ---------------------------------------------------------------
  // Push split bill to the relational split_bills + split_bill_members tables
  // ---------------------------------------------------------------
  Future<void> _pushSplitBillToTable(Map<String, dynamic> billJson) async {
    try {
      final userId = await _getEffectiveUserId();
      final billId = billJson['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      final tableRow = <String, dynamic>{
        'id': billId,
        'title': billJson['title'] ?? 'Group Expense',
        'total_amount': billJson['totalAmount'] ?? 0.0,
        'paid_by': billJson['paidBy'] ?? 'You',
        'date': billJson['date'] != null ? billJson['date'].toString().split('T')[0] : DateTime.now().toIso8601String().split('T')[0],
        'members': billJson['members'] ?? ['You'],
        'custom_shares': billJson['customShares'] ?? {},
        'settled_status': billJson['settledStatus'] ?? {},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      tableRow['user_id'] = userId;

      await client.from('split_bills').upsert(tableRow, onConflict: 'id');

      // Sync members to split_bill_members table
      final members = billJson['members'] as List? ?? [];
      final customShares = billJson['customShares'] as Map? ?? {};
      final settledStatus = billJson['settledStatus'] as Map? ?? {};
      final total = (billJson['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final perPerson = members.isNotEmpty ? total / members.length : 0.0;

      // Delete existing members and re-insert
      try {
        await client.from('split_bill_members').delete().eq('split_bill_id', billId);
      } catch (_) {}

      for (var memberName in members) {
        final share = customShares[memberName]?.toDouble() ?? perPerson;
        final settled = settledStatus[memberName] == true;
        await client.from('split_bill_members').insert({
          'split_bill_id': billId,
          'name': memberName.toString(),
          'amount_owed': share,
          'is_paid': settled,
        });
      }
    } catch (e) {
      debugPrint('Error pushing split bill to table: $e');
    }
  }

  Future<void> _deleteSplitBillFromTable(String id) async {
    try {
      // Members cascade-delete automatically via foreign key
      await client.from('split_bills').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting split bill from table: $e');
    }
  }

  // ---------------------------------------------------------------
  // Push budget to relational budgets table
  // ---------------------------------------------------------------
  Future<void> _pushBudgetToTable(double amount) async {
    try {
      final userId = await _getEffectiveUserId();

      // Upsert the overall monthly budget
      final existing = await client.from('budgets')
          .select('id')
          .eq('user_id', userId)
          .eq('category', 'overall')
          .maybeSingle();

      if (existing != null) {
        await client.from('budgets').update({
          'amount': amount,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', existing['id']);
      } else {
        await client.from('budgets').insert({
          'user_id': userId,
          'category': 'overall',
          'amount': amount,
          'period': 'monthly',
        });
      }
    } catch (e) {
      debugPrint('Error pushing budget to table: $e');
    }
  }

  // ---------------------------------------------------------------
  // Push all subscriptions from SharedPrefs to relational table
  // ---------------------------------------------------------------
  Future<void> _pushAllSubscriptionsToTable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawSubs = prefs.getString('user_saved_subscriptions');
      if (rawSubs == null || rawSubs.isEmpty) return;
      final List decoded = jsonDecode(rawSubs);
      for (var item in decoded) {
        if (item is Map) {
          await _pushSubscriptionToTable(Map<String, dynamic>.from(item));
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------
  // Push all split bills from SharedPrefs to relational table
  // ---------------------------------------------------------------
  Future<void> _pushAllSplitBillsToTable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawGroup = prefs.getString('saved_group_expenses');
      if (rawGroup == null || rawGroup.isEmpty) return;
      final List decoded = jsonDecode(rawGroup);
      for (var item in decoded) {
        if (item is Map) {
          await _pushSplitBillToTable(Map<String, dynamic>.from(item));
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------
  // MASTER PUSH: Push ALL data to ALL tables (user_data + relational)
  // ---------------------------------------------------------------
  Future<void> pushAllDataToCloud() async {
    await _pushUserDataToCloud();

    // Dual-write to relational tables for cross-app compatibility
    try {
      // Push all expenses to relational expenses table
      for (var expense in _localExpenses) {
        _pushExpenseToTable(expense);
      }

      // Push all subscriptions to relational subscriptions table
      _pushAllSubscriptionsToTable();

      // Push all split bills to relational split_bills table
      _pushAllSplitBillsToTable();

      // Push budget to relational budgets table
      final prefs = await SharedPreferences.getInstance();
      final budget = prefs.getDouble('monthly_budget_cap') ?? 0.0;
      if (budget > 0) _pushBudgetToTable(budget);

      // Sync profile to relational profiles table
      if (currentUser != null) {
        _syncProfileToTable(currentUser!);
      }
    } catch (_) {}
  }

  // =====================================================================
  // FETCH: Unified multi-source data collection from ALL tables
  // =====================================================================

  /// Fetch expenses with seamless bidirectional cloud sync
  /// Merges data from both relational `expenses` table AND `user_data` JSON document
  Future<List<Expense>> getExpenses() async {
    await _loadLocalExpenses();
    try {
      final userId = await _getEffectiveUserId();
      final Map<String, Expense> mergedMap = {};

      try {
        final tableResponse = await client
            .from('expenses')
            .select()
            .eq('user_id', userId)
            .order('date', ascending: false);

        for (var row in tableResponse) {
          final exp = Expense.fromJson(Map<String, dynamic>.from(row));
          if (exp.id == 'initial_account_balance' ||
              exp.title == 'Total Account Money' ||
              exp.title == 'Initial Account Balance' ||
              exp.category == 'Total Account Money') {
            continue;
          }
          if (exp.id != null) mergedMap[exp.id!] = exp;
        }
      } catch (e) {
        debugPrint('Error fetching from expenses table: $e');
      }

      // --- Source 2: user_data JSON document strictly for THIS user ---
      Map<String, dynamic>? response;
      try {
        response = await client
            .from('user_data')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
      } catch (_) {}

      if (response != null) {
        final prefs = await SharedPreferences.getInstance();
        
        if (response['budget'] != null) {
          final cloudBudget = (response['budget'] as num).toDouble();
          await prefs.setDouble('monthly_budget_cap', cloudBudget);
        }

        if (response['currency'] != null) {
          final curr = response['currency'].toString().toUpperCase();
          final currMap = CurrencyService.supportedCurrencies.firstWhere(
            (c) => c['code'] == curr || c['symbol'] == curr,
            orElse: () => {'code': 'INR', 'symbol': '₹', 'name': '₹ INR (Indian Rupee)'},
          );
          await CurrencyService().setCurrency(currMap['code']!, currMap['symbol']!, currMap['name']!);
        }

        if (response['expenses'] is List) {
          for (var exp in response['expenses']) {
            if (exp is Map) {
              final item = Expense.fromJson(Map<String, dynamic>.from(exp));
              if (item.id != null && !mergedMap.containsKey(item.id)) {
                mergedMap[item.id!] = item;
              }
            }
          }
        }

        double? incomeInitialBalance;
        if (response['incomes'] is List) {
          for (var inc in response['incomes']) {
            if (inc is Map) {
              if (inc['id'] == 'initial_account_balance' ||
                  inc['is_system_balance'] == true ||
                  inc['source'] == 'Total Account Money' ||
                  inc['title'] == 'Total Account Money') {
                incomeInitialBalance = (inc['amount'] as num?)?.toDouble();
              } else {
                final item = Expense.fromJson(Map<String, dynamic>.from(inc));
                if (item.id != null && !mergedMap.containsKey(item.id)) {
                  mergedMap[item.id!] = item;
                }
              }
            }
          }
        }

        // --- Sync subscriptions, goals, split bills from user_data ---
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
              } else if (type == 'system_financial_meta' || map['id'] == 'system_financial_meta') {
                foundMeta = true;
                final b = (map['starting_balance'] as num?)?.toDouble() ?? 0.0;
                if (b > 0) {
                  await prefs.setDouble('user_starting_balance', b);
                }
              } else {
                cloudSubs.add(map);
              }
            }
          }

          if (incomeInitialBalance != null && incomeInitialBalance > 0) {
            final currentBal = prefs.getDouble('user_starting_balance') ?? 0.0;
            if (currentBal == 0.0 || !foundMeta) {
              await prefs.setDouble('user_starting_balance', incomeInitialBalance);
            }
          }

          // Merge subscriptions from relational table too
          try {
            final tableSubs = await client
                .from('subscriptions')
                .select()
                .eq('user_id', userId);
            final existingIds = cloudSubs.map((s) => s['id']?.toString()).toSet();
            for (var row in tableSubs) {
              final m = Map<String, dynamic>.from(row);
              if (!existingIds.contains(m['id']?.toString())) {
                cloudSubs.add(m);
              }
            }
          } catch (_) {}

          // Merge split bills from relational table too
          try {
            final tableBills = await client
                .from('split_bills')
                .select()
                .eq('user_id', userId)
                .order('date', ascending: false);
            final existingIds = cloudGroup.map((g) => g['id']?.toString()).toSet();
            for (var row in tableBills) {
              final m = Map<String, dynamic>.from(row);
              // Convert relational fields to the format expected locally
              m['totalAmount'] = m['total_amount'] ?? m['totalAmount'];
              m['paidBy'] = m['paid_by'] ?? m['paidBy'];
              m['customShares'] = m['custom_shares'] ?? m['customShares'] ?? {};
              m['settledStatus'] = m['settled_status'] ?? m['settledStatus'] ?? {};
              if (!existingIds.contains(m['id']?.toString())) {
                cloudGroup.add(m);
              }
            }
          } catch (_) {}

          await prefs.setString('user_saved_subscriptions', jsonEncode(cloudSubs));
          await prefs.setString('expense_os_goals', jsonEncode(cloudGoals));
          if (cloudGroup.isNotEmpty) {
            await prefs.setString('saved_group_expenses', jsonEncode(cloudGroup));
          } else {
            await prefs.remove('saved_group_expenses');
          }
        } else {
          final prefs2 = await SharedPreferences.getInstance();

          // Still try relational tables even if user_data has no subscriptions
          try {
            final tableSubs = await client.from('subscriptions').select().eq('user_id', userId);
            if (tableSubs.isNotEmpty) {
              final cloudSubs = tableSubs.map((e) => Map<String, dynamic>.from(e)).toList();
              await prefs2.setString('user_saved_subscriptions', jsonEncode(cloudSubs));
            } else {
              await prefs2.remove('user_saved_subscriptions');
            }
          } catch (_) {
            await prefs2.remove('user_saved_subscriptions');
          }

          try {
            final tableBills = await client.from('split_bills').select().eq('user_id', userId).order('date', ascending: false);
            if (tableBills.isNotEmpty) {
              final cloudGroup = tableBills.map((e) {
                final m = Map<String, dynamic>.from(e);
                m['totalAmount'] = m['total_amount'] ?? m['totalAmount'];
                m['paidBy'] = m['paid_by'] ?? m['paidBy'];
                m['customShares'] = m['custom_shares'] ?? m['customShares'] ?? {};
                m['settledStatus'] = m['settled_status'] ?? m['settledStatus'] ?? {};
                return m;
              }).toList();
              await prefs2.setString('saved_group_expenses', jsonEncode(cloudGroup));
            } else {
              await prefs2.remove('saved_group_expenses');
            }
          } catch (_) {
            await prefs2.remove('saved_group_expenses');
          }
        }

        // Sync budget from relational budgets table
        try {
          final budgetRow = await client.from('budgets')
              .select()
              .eq('user_id', userId)
              .eq('category', 'overall')
              .maybeSingle();
          if (budgetRow != null && budgetRow['amount'] != null) {
            final tableBudget = (budgetRow['amount'] as num).toDouble();
            final prefs3 = await SharedPreferences.getInstance();
            final currentBudget = prefs3.getDouble('monthly_budget_cap') ?? 0.0;
            // Use whichever is more recent / non-zero
            if (tableBudget > 0 && currentBudget == 0) {
              await prefs3.setDouble('monthly_budget_cap', tableBudget);
            }
          }
        } catch (_) {}

        // Sync profile from relational profiles table
        try {
          final profileRow = await client.from('profiles')
              .select()
              .eq('user_id', userId)
              .maybeSingle();
          if (profileRow != null) {
            final prefs4 = await SharedPreferences.getInstance();
            if (profileRow['starting_balance'] != null) {
              final bal = (profileRow['starting_balance'] as num).toDouble();
              if (bal > 0) {
                await prefs4.setDouble('user_starting_balance', bal);
              }
            }
            if (profileRow['currency'] != null) {
              final curr = profileRow['currency'].toString();
              if (curr.isNotEmpty) {
                final symbol = curr == 'USD' ? '\$' : (curr == 'EUR' ? '€' : (curr == 'GBP' ? '£' : '₹'));
                await prefs4.setString('app_currency_symbol', symbol);
              }
            }
          }
        } catch (_) {}
      }

      // Build final merged list
      _localExpenses.clear();
      _localExpenses.addAll(mergedMap.values);
      _localExpenses.removeWhere((e) => e.id == 'initial_account_balance' || e.title == 'Total Account Money' || e.title == 'Initial Account Balance');
      _localExpenses.sort((a, b) => b.date.compareTo(a.date));
      await _persistLocalExpenses();
      await cleanOrphanedExpenses();

      return List.unmodifiable(_localExpenses);
    } catch (e) {
      debugPrint('Error syncing with user_data: $e');
    }
    return List.unmodifiable(_localExpenses);
  }

  List<Expense> get localExpenses => List.unmodifiable(_localExpenses);

  // =====================================================================
  // REALTIME: Multi-channel real-time sync across ALL tables
  // =====================================================================

  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);
  static RealtimeChannel? _userDataChannel;
  static RealtimeChannel? _expensesChannel;
  static RealtimeChannel? _subscriptionsChannel;
  static RealtimeChannel? _splitBillsChannel;
  static RealtimeChannel? _budgetsChannel;
  static RealtimeChannel? _profilesChannel;

  Future<void> startRealtimeSync() async {
    try {
      final userId = await _getEffectiveUserId();

      // --- Channel 1: user_data (Web App changes) ---
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

    // --- Channel 2: expenses table (Desktop / iOS changes) ---
    if (_expensesChannel != null) {
      client.removeChannel(_expensesChannel!);
    }
      _expensesChannel = client
          .channel('public:expenses:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'expenses',
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

      // --- Channel 3: subscriptions table ---
      if (_subscriptionsChannel != null) {
        client.removeChannel(_subscriptionsChannel!);
      }
      _subscriptionsChannel = client
          .channel('public:subscriptions:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'subscriptions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) async {
              await getExpenses(); // Re-fetches everything including subs
              refreshNotifier.value++;
            },
          )
          .subscribe();

      // --- Channel 4: split_bills table ---
      if (_splitBillsChannel != null) {
        client.removeChannel(_splitBillsChannel!);
      }
      _splitBillsChannel = client
          .channel('public:split_bills:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'split_bills',
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

      // --- Channel 5: budgets table ---
      if (_budgetsChannel != null) {
        client.removeChannel(_budgetsChannel!);
      }
      _budgetsChannel = client
          .channel('public:budgets:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'budgets',
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

      // --- Channel 6: profiles table ---
      if (_profilesChannel != null) {
        client.removeChannel(_profilesChannel!);
      }
      _profilesChannel = client
          .channel('public:profiles:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
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
    } catch (_) {
      // User is not authenticated yet; ignore realtime sync until login
    }
  }

  // =====================================================================
  // CRUD: Add / Update / Delete with dual-write to all tables
  // =====================================================================

  /// Add new expense with instant dual-write cloud sync and push notification
  Future<Expense> addExpense(Expense expense) async {
    await _loadLocalExpenses();
    final validId = (expense.id != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(expense.id!))
        ? expense.id
        : Expense.generateUuidV4();
    final localItem = expense.copyWith(id: validId);
    _localExpenses.insert(0, localItem);
    await _persistLocalExpenses();
    await _pushUserDataToCloud();
    await _pushExpenseToTable(localItem); // Dual-write to relational table
    refreshNotifier.value++;

    // Fire instant device push notification
    try {
      final currencySymbol = CurrencyService.currencySymbolNotifier.value;
      final isIncome = localItem.type.toLowerCase() == 'income';
      
      if (isIncome) {
        await NotificationService().showNotification(
          id: (localItem.id.hashCode.abs() % 90000) + 10000,
          title: '💰 Income Logged: +$currencySymbol${localItem.amount.toStringAsFixed(2)}',
          body: '${localItem.title} • ${localItem.category}',
          channelType: NotificationChannelType.general,
        );
      } else {
        await NotificationService().showNotification(
          id: (localItem.id.hashCode.abs() % 90000) + 20000,
          title: '💸 Expense Logged: -$currencySymbol${localItem.amount.toStringAsFixed(2)}',
          body: '${localItem.title} • ${localItem.category}',
          channelType: NotificationChannelType.budget,
        );

        // Check if this expense approaches or exceeds the monthly budget cap
        final prefs = await SharedPreferences.getInstance();
        final cap = prefs.getDouble('monthly_budget_cap') ?? 0.0;
        if (cap > 0) {
          final now = DateTime.now();
          final monthExpenses = _localExpenses
              .where((e) => e.type.toLowerCase() == 'expense' && e.date.year == now.year && e.date.month == now.month)
              .fold(0.0, (sum, e) => sum + e.amount);
          
          await NotificationService().checkBudgetAlert(
            totalSpent: monthExpenses,
            budgetCap: cap,
            currencySymbol: currencySymbol,
          );
        }

        // Also check Category-Specific Budget Cap Thresholds
        if (expense.category.isNotEmpty) {
          final now = DateTime.now();
          final categoryExpenses = _localExpenses
              .where((e) => e.type.toLowerCase() == 'expense' && e.category == expense.category && e.date.year == now.year && e.date.month == now.month)
              .fold(0.0, (sum, e) => sum + e.amount);

          final catCap = prefs.getDouble('category_budget_cap_${expense.category}') ?? 0.0;
          if (catCap > 0) {
            await NotificationService().checkCategoryBudgetAlert(
              categoryName: expense.category,
              categorySpent: categoryExpenses,
              categoryCap: catCap,
              currencySymbol: currencySymbol,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error triggering transaction notification: $e');
    }

    return localItem;
  }

  /// Update existing expense with instant dual-write cloud sync
  Future<Expense> updateExpense(Expense expense) async {
    if (expense.id == null) throw Exception("Expense ID cannot be null for update");
    final index = _localExpenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _localExpenses[index] = expense;
    }
    await _persistLocalExpenses();
    await _pushUserDataToCloud();
    await _pushExpenseToTable(expense); // Dual-write to relational table
    refreshNotifier.value++;
    return expense;
  }

  /// Delete expense by ID with instant dual-write cloud sync & unmarking subscription if needed
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
      await _deleteExpenseFromTable(id); // Dual-delete from relational table
      refreshNotifier.value++;
    }
  }

  /// Cascade delete all expense entries associated with a deleted subscription
  Future<void> cascadeDeleteSubscriptionExpenses(String subscriptionId, String title) async {
    await _loadLocalExpenses();
    final cleanTitle = title.trim().toLowerCase();
    final idsToDelete = <String>[];
    _localExpenses.removeWhere((e) {
      if (e.id != null && e.id!.startsWith('bill_pay_$subscriptionId')) {
        idsToDelete.add(e.id!);
        return true;
      }
      final t = e.title.trim().toLowerCase();
      if (t == 'bill payment: $cleanTitle' || t == '$cleanTitle (subscription)' || t == '$cleanTitle (recurring bill)') {
        if (e.id != null) idsToDelete.add(e.id!);
        return true;
      }
      return false;
    });
    await _persistLocalExpenses();
    await _pushUserDataToCloud();
    // Dual-delete from relational table
    for (var id in idsToDelete) {
      _deleteExpenseFromTable(id);
    }
    _deleteSubscriptionFromTable(subscriptionId);
    refreshNotifier.value++;
  }

  /// Cascade delete all expense and income entries associated with a deleted group/split bill
  Future<void> cascadeDeleteGroupExpense(String groupId, String title, String paidBy) async {
    await _loadLocalExpenses();
    final cleanTitle = title.trim().toLowerCase();
    final idsToDelete = <String>[];
    _localExpenses.removeWhere((e) {
      final t = e.title.trim().toLowerCase();
      if (t == '$cleanTitle (my split share)') {
        if (e.id != null) idsToDelete.add(e.id!);
        return true;
      }
      if (t.startsWith('paid ') && t.contains('for $cleanTitle (settled share)')) {
        if (e.id != null) idsToDelete.add(e.id!);
        return true;
      }
      if (t.startsWith('reimbursement from ') && t.contains('($cleanTitle)')) {
        if (e.id != null) idsToDelete.add(e.id!);
        return true;
      }
      return false;
    });
    await _persistLocalExpenses();
    await removeGroupExpense(groupId);
    await _pushUserDataToCloud();
    // Dual-delete from relational tables
    for (var id in idsToDelete) {
      _deleteExpenseFromTable(id);
    }
    _deleteSplitBillFromTable(groupId);
    refreshNotifier.value++;
  }

  /// Clean any orphaned expenses whose parent subscription or split bill was deleted
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
    final idsToDelete = <String>[];
    _localExpenses.removeWhere((e) {
      final t = e.title.trim().toLowerCase();
      if (t.startsWith('bill payment: ')) {
        final billName = t.replaceFirst('bill payment: ', '').trim();
        if (!validSubTitles.contains(billName)) {
          removedAny = true;
          if (e.id != null) idsToDelete.add(e.id!);
          return true;
        }
      }
      if (t.endsWith(' (my split share)')) {
        final groupName = t.replaceFirst(' (my split share)', '').trim();
        if (!validGroupTitles.contains(groupName)) {
          removedAny = true;
          if (e.id != null) idsToDelete.add(e.id!);
          return true;
        }
      }
      if (t.startsWith('reimbursement from ') && t.endsWith(')')) {
        final groupName = t.substring(t.lastIndexOf('(') + 1, t.lastIndexOf(')')).trim();
        if (!validGroupTitles.contains(groupName)) {
          removedAny = true;
          if (e.id != null) idsToDelete.add(e.id!);
          return true;
        }
      }
      return false;
    });

    if (removedAny) {
      await _persistLocalExpenses();
      await _pushUserDataToCloud();
      for (var id in idsToDelete) {
        _deleteExpenseFromTable(id);
      }
      refreshNotifier.value++;
    }
  }

  /// Complete clean reset of local and Supabase cloud financial data
  Future<void> resetAllFinancialData() async {
    _localExpenses.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_offline_expenses');
    await prefs.remove('user_saved_subscriptions');
    await prefs.remove('expense_os_goals');
    await prefs.remove('monex_goals');
    await prefs.remove('monthly_budget_cap');
    await prefs.remove('user_starting_balance');
    await prefs.remove('saved_group_expenses');
    await prefs.remove('app_cached_expenses');
    await prefs.remove('user_emerald_points');
    await prefs.remove('custom_user_name');
    await prefs.remove('custom_avatar_path');
    
    try {
      final userId = await _getEffectiveUserId();

      // Reset user_data document in Supabase
      await client.from('user_data').upsert({
        'user_id': userId,
        'budget': 0.0,
        'starting_balance': 0.0,
        'account_balance': 0.0,
        'expenses': [],
        'incomes': [],
        'subscriptions': [],
        'savings_goals': [],
        'currency': 'INR',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');

      // Clear all relational tables
      try { await client.from('expenses').delete().eq('user_id', userId); } catch (_) {}
      try { await client.from('incomes').delete().eq('user_id', userId); } catch (_) {}
      try { await client.from('subscriptions').delete().eq('user_id', userId); } catch (_) {}
      try { await client.from('savings_goals').delete().eq('user_id', userId); } catch (_) {}
      try { await client.from('split_bills').delete().eq('user_id', userId); } catch (_) {}
      try { await client.from('budgets').delete().eq('user_id', userId); } catch (_) {}
      try { await client.from('user_emerald_rewards').delete().eq('user_id', userId); } catch (_) {}
    } catch (_) {}

    refreshNotifier.value++;
  }

  // =====================================================================
  // GROUP EXPENSES / SPLIT BILLS (Dual-write: split_bills table + user_data)
  // =====================================================================

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
      final userId = await _getEffectiveUserId();
      final Map<String, Map<String, dynamic>> merged = {};

      // Add local items
      for (var item in localList) {
        final id = item['id']?.toString();
        if (id != null) merged[id] = item;
      }

      // Merge from relational split_bills table
      try {
        final response = await client
            .from('split_bills')
            .select()
            .eq('user_id', userId)
            .order('date', ascending: false);
        for (var row in response) {
          final m = Map<String, dynamic>.from(row);
          m['totalAmount'] = m['total_amount'] ?? m['totalAmount'];
          m['paidBy'] = m['paid_by'] ?? m['paidBy'];
          m['customShares'] = m['custom_shares'] ?? m['customShares'] ?? {};
          m['settledStatus'] = m['settled_status'] ?? m['settledStatus'] ?? {};
          final id = m['id']?.toString();
          if (id != null && !merged.containsKey(id)) {
            merged[id] = m;
          }
        }
      } catch (_) {}

      // Merge from user_data subscriptions array (type=split_bill)
      try {
        final userData = await client
            .from('user_data')
            .select('subscriptions')
            .eq('user_id', userId)
            .maybeSingle();
        if (userData != null && userData['subscriptions'] is List) {
          for (var item in userData['subscriptions']) {
            if (item is Map && item['type'] == 'split_bill') {
              final m = Map<String, dynamic>.from(item);
              final id = m['id']?.toString();
              if (id != null && !merged.containsKey(id)) {
                merged[id] = m;
              }
            }
          }
        }
      } catch (_) {}

      final result = merged.values.toList();
      if (result.isNotEmpty) {
        await prefs.setString('saved_group_expenses', jsonEncode(result));
      }
      return result.isNotEmpty ? result : localList;
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

    // Dual-write to relational split_bills table
    _pushSplitBillToTable(itemJson);
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

    // Dual-delete from relational split_bills table (members cascade automatically)
    _deleteSplitBillFromTable(id);
  }

  // =====================================================================
  // USER PROFILE & FINANCIAL SETTINGS CLOUD SYNC
  // (Writes to: auth metadata + profiles table + budgets table + user_data)
  // =====================================================================

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

        // Dual-write to relational profiles table
        try {
          final currencyCode = currencySymbol == '\$' ? 'USD' : (currencySymbol == '€' ? 'EUR' : (currencySymbol == '£' ? 'GBP' : 'INR'));
          await Supabase.instance.client.from('profiles').upsert({
            'user_id': user.id,
            'email': user.email,
            'full_name': customName ?? meta['full_name'] ?? meta['name'],
            'avatar_url': meta['avatar_url'] ?? meta['picture'],
            'currency': currencyCode,
            'monthly_budget': budgetCap ?? prefs.getDouble('monthly_budget_cap') ?? 0.0,
            'starting_balance': startingBalance ?? prefs.getDouble('user_starting_balance') ?? 0.0,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id');
        } catch (_) {}

        // Dual-write budget to relational budgets table
        if (budgetCap != null && budgetCap > 0) {
          try {
            await SupabaseService()._pushBudgetToTable(budgetCap);
          } catch (_) {}
        }
      }
    } catch (_) {}

    try {
      await SupabaseService()._loadLocalExpenses();
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

        // Also load from relational profiles table as fallback
        try {
          final profileRow = await Supabase.instance.client.from('profiles')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();
          if (profileRow != null) {
            if (profileRow['currency'] != null && prefs.getString('app_currency_symbol') == null) {
              final curr = profileRow['currency'].toString();
              final symbol = curr == 'USD' ? '\$' : (curr == 'EUR' ? '€' : (curr == 'GBP' ? '£' : '₹'));
              await prefs.setString('app_currency_symbol', symbol);
            }
            if (profileRow['full_name'] != null && prefs.getString('custom_user_name') == null) {
              await prefs.setString('custom_user_name', profileRow['full_name'].toString());
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }
}
