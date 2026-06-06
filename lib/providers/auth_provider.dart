import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabase;

  AuthProvider({SupabaseService? supabase}) : _supabase = supabase ?? SupabaseService();

  bool _isLoading = false;
  String? _error;
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get currentUser => _supabase.currentUser;
  bool get isSignedIn => _supabase.isSignedIn;

  Future<bool> initialize() async {
    try {
      await _supabase.initialize();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Auth init error: $e');
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.signIn(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({required String email, required String password, String? displayName}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.signUp(email: email, password: password, displayName: displayName);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _supabase.signOut();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
