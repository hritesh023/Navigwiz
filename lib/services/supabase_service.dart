import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String _supabaseUrl = 'https://mqhioluzqomshbzitkkp.supabase.co';
  static const String _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xaGlvbHV6cW9tc2hieml0a2twIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3MzA2NjMsImV4cCI6MjA5NjMwNjY2M30.Ec56nZzuEAW6lo75rx5OBoKuPYUHxMZZx_oKpruNu_U';

  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _initialized = false;
  User? get currentUser => _initialized ? Supabase.instance.client.auth.currentUser : null;
  bool get isSignedIn => _initialized && Supabase.instance.client.auth.currentUser != null;
  String? get userId => currentUser?.id;

  Future<void> initialize() async {
    if (_initialized) return;
    debugPrint('Initializing Supabase...');
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _anonKey,
    );
    _initialized = true;
    debugPrint('Supabase initialized successfully');
  }

  Future<AuthResponse> signUp({required String email, required String password, String? displayName}) async {
    final response = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'display_name': displayName} : null,
    );
    return response;
  }

  Future<AuthResponse> signIn({required String email, required String password}) async {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await Supabase.instance.client.auth.resetPasswordForEmail(email);
  }

  Stream<AuthState> get authStateChanges => Supabase.instance.client.auth.onAuthStateChange;
}
