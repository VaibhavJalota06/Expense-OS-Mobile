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

  Future<AuthResponse> signUp({required String email, required String password}) async {
    final res = await client.auth.signUp(email: email, password: password);
    if (res.user != null || res.session != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('persistent_user_logged_in', true);
    }
    return res;
  }

  Future<AuthResponse> signIn({required String email, required String password}) async {
    final res = await client.auth.signInWithPassword(email: email, password: password);
    if (res.user != null || res.session != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('persistent_user_logged_in', true);
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
  
  // Memory fallback list if Supabase table is not yet created
  final List<Expense> _localExpenses = [];

  // Fetch expenses with graceful fallback
  Future<List<Expense>> getExpenses() async {
    try {
      final response = await client
          .from('expenses')
          .select()
          .order('date', ascending: false);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Expense.fromJson(json)).toList();
    } catch (e) {
      // Graceful fallback to local list if table 'expenses' does not exist yet
      return List.unmodifiable(_localExpenses);
    }
  }

  List<Expense> get localExpenses => List.unmodifiable(_localExpenses);

  // Static global refresh notifier for real-time automatic screen updates
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  // Add new expense with graceful fallback
  Future<Expense> addExpense(Expense expense) async {
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
      refreshNotifier.value++;
      return result;
    } catch (e) {
      // Fallback to local memory storage
      final localItem = expense.copyWith(
        id: expense.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      );
      _localExpenses.insert(0, localItem);
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
      refreshNotifier.value++;
      return result;
    } catch (e) {
      final index = _localExpenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _localExpenses[index] = expense;
      }
      refreshNotifier.value++;
      return expense;
    }
  }

  // Delete expense by ID
  Future<void> deleteExpense(String id) async {
    try {
      await client.from('expenses').delete().eq('id', id);
    } catch (e) {
      _localExpenses.removeWhere((e) => e.id == id);
    } finally {
      refreshNotifier.value++;
    }
  }
}
