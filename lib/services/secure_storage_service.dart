import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final _storage = const FlutterSecureStorage();

  // API Key Management
  Future<void> storeApiKey(String service, String apiKey) async {
    final encryptedKey = _encryptData(apiKey);
    await _storage.write(key: 'api_key_$service', value: encryptedKey);
  }

  Future<String?> getApiKey(String service) async {
    final encryptedKey = await _storage.read(key: 'api_key_$service');
    if (encryptedKey == null) return null;
    return _decryptData(encryptedKey);
  }

  Future<void> removeApiKey(String service) async {
    await _storage.delete(key: 'api_key_$service');
  }

  // User Preferences
  Future<void> storeUserPreference(String key, String value) async {
    final encryptedValue = _encryptData(value);
    await _storage.write(key: 'pref_$key', value: encryptedValue);
  }

  Future<String?> getUserPreference(String key) async {
    final encryptedValue = await _storage.read(key: 'pref_$key');
    if (encryptedValue == null) return null;
    return _decryptData(encryptedValue);
  }

  // Session Management
  Future<void> storeSessionToken(String token) async {
    final encryptedToken = _encryptData(token);
    await _storage.write(key: 'session_token', value: encryptedToken);
  }

  Future<String?> getSessionToken() async {
    final encryptedToken = await _storage.read(key: 'session_token');
    if (encryptedToken == null) return null;
    return _decryptData(encryptedToken);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: 'session_token');
  }

  // Security Utilities
  String _encryptData(String data) {
    final key = _generateEncryptionKey();
    final bytes = utf8.encode(data);
    final encrypted = _xorEncrypt(bytes, key);
    return base64.encode(encrypted);
  }

  String _decryptData(String encryptedData) {
    final key = _generateEncryptionKey();
    final bytes = base64.decode(encryptedData);
    final decrypted = _xorEncrypt(bytes, key);
    return utf8.decode(decrypted);
  }

  List<int> _generateEncryptionKey() {
    final seed = 'navigwiz_secure_${DateTime.now().year}';
    final bytes = utf8.encode(seed);
    final digest = sha256.convert(bytes);
    return digest.bytes;
  }

  List<int> _xorEncrypt(List<int> data, List<int> key) {
    final result = <int>[];
    for (int i = 0; i < data.length; i++) {
      result.add(data[i] ^ key[i % key.length]);
    }
    return result;
  }

  // Security Validation
  Future<bool> validateApiKey(String service, String apiKey) async {
    // Basic validation for API key format
    switch (service.toLowerCase()) {
      case 'openai':
        return apiKey.startsWith('sk-') && apiKey.length > 40;
      case 'weather':
        return apiKey.length > 10;
      default:
        return apiKey.isNotEmpty;
    }
  }

  // Security Cleanup
  Future<void> clearAllSensitiveData() async {
    await _storage.deleteAll();
  }

  // Security Audit
  Future<Map<String, dynamic>> getSecurityStatus() async {
    final keys = await _storage.readAll();
    final apiKeys =
        keys.keys.where((key) => key.startsWith('api_key_')).toList();
    final preferences =
        keys.keys.where((key) => key.startsWith('pref_')).toList();

    return {
      'totalStoredKeys': keys.length,
      'apiKeysCount': apiKeys.length,
      'preferencesCount': preferences.length,
      'hasSessionToken': keys.containsKey('session_token'),
      'lastSecurityCheck': DateTime.now().toIso8601String(),
    };
  }

  // Rate Limiting for API Calls
  final Map<String, List<DateTime>> _rateLimitCache = {};

  bool isRateLimited(String service,
      {int maxRequests = 10, Duration window = const Duration(minutes: 1)}) {
    final now = DateTime.now();
    final requests = _rateLimitCache[service] ?? [];

    // Remove old requests outside the window
    requests.removeWhere((time) => now.difference(time) > window);

    if (requests.length >= maxRequests) {
      return true;
    }

    requests.add(now);
    _rateLimitCache[service] = requests;
    return false;
  }

  // Token Refresh Management
  Future<String?> refreshApiKey(String service) async {
    // In production, this would call your secure backend
    // For now, return the existing key
    return await getApiKey(service);
  }
}
