import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  String _aiAssistantName = 'Navigwiz';
  String _userDisplayName = '';
  String _userEmail = '';
  List<Map<String, String>> _extensions = [];

  bool get isDarkMode => _isDarkMode;
  String get aiAssistantName => _aiAssistantName;
  String get userDisplayName => _userDisplayName;
  String get userEmail => _userEmail;
  List<Map<String, String>> get extensions => _extensions;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    _aiAssistantName = prefs.getString('ai_assistant_name') ?? 'Navigwiz';
    _userDisplayName = prefs.getString('user_display_name') ?? '';
    _userEmail = prefs.getString('user_email') ?? '';

    final extJson = prefs.getString('extensions');
    if (extJson != null) {
      final list = jsonDecode(extJson) as List;
      _extensions = list.map((e) => Map<String, String>.from(e)).toList();
    }

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
