import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _token;
  String? _tagKey;
  String? _tagValue;

  bool get isSignedIn => _token != null;
  String? get token => _token;
  String? get tagKey => _tagKey;
  String? get tagValue => _tagValue;

  String get _baseUrl {
    if (AppConfig.workerUrl.isNotEmpty) {
      return AppConfig.workerUrl;
    }
    return 'http://localhost:8000/api/v1';
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _tagKey = prefs.getString('auth_tag_key');
    _tagValue = prefs.getString('auth_tag_value');
    debugPrint('Auth initialized: ${isSignedIn ? "signed in" : "not signed in"}');
  }

  Future<bool> signIn({required String tagKey, required String tagValue}) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/signin');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'tag_key': tagKey, 'tag_value': tagValue},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'] as String?;
        _tagKey = tagKey;
        _tagValue = tagValue;

        if (_token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', _token!);
          await prefs.setString('auth_tag_key', tagKey);
          await prefs.setString('auth_tag_value', tagValue);
          debugPrint('Auth sign in successful');
          return true;
        }
      }
      debugPrint('Auth sign in failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Auth sign in error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    _token = null;
    _tagKey = null;
    _tagValue = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_tag_key');
    await prefs.remove('auth_tag_value');
    debugPrint('Auth signed out');
  }
}
