import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/message.dart';

class PreferencesService {
  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(AppPrefKeys.themeMode) ?? 'system';
    switch (value) {
      case 'dark': return ThemeMode.dark;
      case 'light': return ThemeMode.light;
      default: return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system';
    await prefs.setString(AppPrefKeys.themeMode, value);
  }

  Future<double> loadTtsSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(AppPrefKeys.ttsSpeed) ?? 0.5;
  }

  Future<void> saveTtsSpeed(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppPrefKeys.ttsSpeed, value);
  }

  Future<double> loadTtsPitch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(AppPrefKeys.ttsPitch) ?? 1.0;
  }

  Future<void> saveTtsPitch(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppPrefKeys.ttsPitch, value);
  }

  Future<bool> loadAutoSendVoice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppPrefKeys.autoSendVoice) ?? false;
  }

  Future<void> saveAutoSendVoice(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppPrefKeys.autoSendVoice, value);
  }

  Future<List<Conversation>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(AppPrefKeys.conversations);
    if (data == null) return [];
    final list = jsonDecode(data) as List<dynamic>;
    return list.map((item) => Conversation.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final data = conversations.map((c) => c.toJson()).toList();
    await prefs.setString(AppPrefKeys.conversations, jsonEncode(data));
  }

  Future<String> loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppPrefKeys.serverUrl) ?? '';
  }

  Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppPrefKeys.serverUrl, url);
  }
}
