import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  String _aiAssistantName = 'Navigwiz';
  String _userDisplayName = '';
  String _userEmail = '';
  List<Map<String, String>> _extensions = [];
  String _searchEngine = 'navigwiz';
  bool _adBlockEnabled = false;
  String _homepageUrl = '';

  bool get isDarkMode => _isDarkMode;
  String get aiAssistantName => _aiAssistantName;
  String get userDisplayName => _userDisplayName;
  String get userEmail => _userEmail;
  List<Map<String, String>> get extensions => _extensions;
  String get searchEngine => _searchEngine;
  bool get adBlockEnabled => _adBlockEnabled;
  String get homepageUrl => _homepageUrl;
  bool get useGoogleSearch => _searchEngine == 'google';

  static String sanitizeEngine(String? engine) {
    final normalized = (engine ?? '').trim().toLowerCase();
    if (normalized == 'google') return 'google';
    return 'navigwiz';
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    _aiAssistantName = prefs.getString('ai_assistant_name') ?? 'Navigwiz';
    _userDisplayName = prefs.getString('user_display_name') ?? '';
    _userEmail = prefs.getString('user_email') ?? '';
    // Default is always Navigwiz. A stale 'google' value from an old install
    // or a corrupted pref must never hijack searches: only keep 'google'
    // when it was explicitly stored as such.
    _searchEngine = sanitizeEngine(prefs.getString('search_engine'));
    // Self-heal: persist the sanitized value so a bad pref can't linger.
    final stored = prefs.getString('search_engine');
    if (stored != _searchEngine) {
      await prefs.setString('search_engine', _searchEngine);
    }
    _adBlockEnabled = prefs.getBool('ad_block_enabled') ?? false;
    _homepageUrl = prefs.getString('homepage_url') ?? '';

    final extJson = prefs.getString('extensions');
    if (extJson != null) {
      final list = jsonDecode(extJson) as List;
      _extensions = list.map((e) => Map<String, String>.from(e)).toList();
    }

    notifyListeners();
  }

  Future<void> setSearchEngine(String engine) async {
    _searchEngine = sanitizeEngine(engine);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('search_engine', _searchEngine);
    notifyListeners();
  }

  Future<void> setAdBlockEnabled(bool value) async {
    _adBlockEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ad_block_enabled', value);
    notifyListeners();
  }

  Future<void> setHomepageUrl(String value) async {
    _homepageUrl = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('homepage_url', value);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    notifyListeners();
  }

  Future<void> setAiAssistantName(String name) async {
    _aiAssistantName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_assistant_name', name);
    notifyListeners();
  }

  Future<void> setUserDisplayName(String name) async {
    _userDisplayName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_display_name', name);
    notifyListeners();
  }

  Future<void> setUserEmail(String email) async {
    _userEmail = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    notifyListeners();
  }

  Future<void> addExtension(String name, String path) async {
    _extensions.add({'name': name, 'path': path});
    await _saveExtensions();
    notifyListeners();
  }

  Future<void> removeExtension(int index) async {
    if (index >= 0 && index < _extensions.length) {
      _extensions.removeAt(index);
      await _saveExtensions();
      notifyListeners();
    }
  }

  Future<void> _saveExtensions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('extensions', jsonEncode(_extensions));
  }

  Future<void> signOut() async {
    _userDisplayName = '';
    _userEmail = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_display_name');
    await prefs.remove('user_email');
    notifyListeners();
  }
}
