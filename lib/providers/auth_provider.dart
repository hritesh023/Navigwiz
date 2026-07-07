import 'package:flutter/material.dart';
import '../services/central_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final CentralAuthService _auth;

  AuthProvider({CentralAuthService? auth}) : _auth = auth ?? CentralAuthService();

  bool _isLoading = false;
  String? _error;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSignedIn => _auth.isSignedIn;

  Future<bool> initialize() async {
    try {
      await _auth.initialize();
      final authenticated = await _auth.checkAuth();
      notifyListeners();
      return authenticated;
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
      final success = await _auth.signIn(email, password);
      _isLoading = false;
      if (!success) {
        _error = 'Invalid email or password';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({required String email, required String password, String? name}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _auth.signUp(email, password, name: name);
      _isLoading = false;
      if (!success) {
        _error = 'Sign up failed';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  void redirectToLogin() {
    _auth.redirectToLogin();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
