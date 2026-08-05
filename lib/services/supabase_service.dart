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

  // Initialize Supabase Flutter Client
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // --- AUTHENTICATION ---
  User? get currentUser => client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Future<AuthResponse> signUp({required String email, required String password}) async {
    return await client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({required String email, required String password}) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // --- EXPENSE CRUD OPERATIONS ---
  
  // Fetch expenses from Supabase table 'expenses'
  Future<List<Expense>> getExpenses() async {
    final response = await client
        .from('expenses')
        .select()
        .order('date', ascending: false);
    
    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => Expense.fromJson(json)).toList();
  }

  // Add new expense
  Future<Expense> addExpense(Expense expense) async {
    final Map<String, dynamic> json = expense.toJson();
    if (currentUser != null) {
      json['user_id'] = currentUser!.id;
    }

    final response = await client
        .from('expenses')
        .insert(json)
        .select()
        .single();
    
    return Expense.fromJson(response);
  }

  // Update existing expense
  Future<Expense> updateExpense(Expense expense) async {
    if (expense.id == null) throw Exception("Expense ID cannot be null for update");

    final response = await client
        .from('expenses')
        .update(expense.toJson())
        .eq('id', expense.id!)
        .select()
        .single();

    return Expense.fromJson(response);
  }

  // Delete expense by ID
  Future<void> deleteExpense(String id) async {
    await client.from('expenses').delete().eq('id', id);
  }
}
