import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:typed_data';

class ThemeService extends ChangeNotifier {
  static const String _backgroundImageKey = 'background_image_path';
  static const String _backgroundBytesKey = 'background_media_bytes';
  static const String _backgroundTypeKey = 'background_media_type';
  static const String _primaryColorKey = 'primary_color';
  static const String _isDarkModeKey = 'is_dark_mode';

  ThemeData _lightTheme = _buildDefaultTheme(false);
  ThemeData _darkTheme = _buildDefaultTheme(true);
  Color _primaryColor = Colors.blue;
  bool _isDarkMode = true;
  String? _backgroundImagePath;
  Uint8List? _backgroundImageBytes;
  String _backgroundMediaType = 'none';

  ThemeData get lightTheme => _lightTheme;
  ThemeData get darkTheme => _darkTheme;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  Color get primaryColor => _primaryColor;
  bool get isDarkMode => _isDarkMode;
  String? get backgroundImagePath => _backgroundImagePath;
  Uint8List? get backgroundImageBytes => _backgroundImageBytes;
  String get backgroundMediaType => _backgroundMediaType;
  bool get hasBackgroundMedia => _backgroundImageBytes != null;
  bool get hasVideoBackground => _backgroundMediaType == 'video';

  Future<void> initialize() async {
    await _loadThemeSettings();
  }

  ThemeService();

  static ThemeData _buildDefaultTheme(bool isDark) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );
  }

  static ThemeData _buildTheme(Color primaryColor, bool isDarkMode) {
    final brightness = isDarkMode ? Brightness.dark : Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDarkMode ? Colors.grey[900] : primaryColor,
        foregroundColor: isDarkMode ? Colors.white : Colors.white,
        elevation: 2,
      ),
      scaffoldBackgroundColor: isDarkMode ? Colors.black : Colors.white,
      cardColor: isDarkMode ? Colors.grey[800] : Colors.white,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _primaryColor =
        Color(prefs.getInt(_primaryColorKey) ?? Colors.blue.toARGB32());
    _isDarkMode = prefs.getBool(_isDarkModeKey) ?? true;
    _backgroundImagePath = prefs.getString(_backgroundImageKey);
    _backgroundMediaType = prefs.getString(_backgroundTypeKey) ?? 'none';
    final encodedMedia = prefs.getString(_backgroundBytesKey);
    if (encodedMedia != null && encodedMedia.isNotEmpty) {
      _backgroundImageBytes = base64.decode(encodedMedia);
    }

    _updateTheme();
  }

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    await _saveThemeSettings();
    _updateTheme();
  }

  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    await _saveThemeSettings();
    _updateTheme();
  }

  Future<void> setBackgroundImageBytes(Uint8List imageBytes,
      {String? path}) async {
    _backgroundImageBytes = imageBytes;
    _backgroundImagePath = path;
    _backgroundMediaType = 'image';

    // Extract dominant color from image
    final dominantColor = _extractDominantColor(imageBytes);
    if (dominantColor != null) {
      _primaryColor = dominantColor;
    }

    await _saveThemeSettings();
    _updateTheme();
  }

  Future<void> setBackgroundVideoBytes(Uint8List videoBytes,
      {String? path}) async {
    _backgroundImageBytes = videoBytes;
    _backgroundImagePath = path;
    _backgroundMediaType = 'video';
    _primaryColor = const Color(0xFF8B5CF6);
    await _saveThemeSettings();
    _updateTheme();
  }

  Future<void> removeBackgroundImage() async {
    _backgroundImageBytes = null;
    _backgroundImagePath = null;
    _backgroundMediaType = 'none';
    await _saveThemeSettings();
    _updateTheme();
  }

  Color? _extractDominantColor(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);

      if (image != null) {
        // Simple color extraction - sample pixels from center area
        final centerX = image.width ~/ 2;
        final centerY = image.height ~/ 2;
        const sampleSize = 50;

        int r = 0, g = 0, b = 0;
        int count = 0;

        for (int y = centerY - sampleSize; y < centerY + sampleSize; y++) {
          for (int x = centerX - sampleSize; x < centerX + sampleSize; x++) {
            if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
              final pixel = image.getPixel(x, y);
              r += pixel.r.toInt();
              g += pixel.g.toInt();
              b += pixel.b.toInt();
              count++;
            }
          }
        }

        if (count > 0) {
          return Color.fromARGB(
            255,
            (r ~/ count).toInt(),
            (g ~/ count).toInt(),
            (b ~/ count).toInt(),
          );
        }
      }
    } catch (e) {
      debugPrint('Error extracting dominant color: $e');
    }

    return null;
  }

  void _updateTheme() {
    _lightTheme = _buildTheme(_primaryColor, false);
    _darkTheme = _buildTheme(_primaryColor, true);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemeSettings();
    notifyListeners();
  }

  Future<void> _saveThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_primaryColorKey, _primaryColor.toARGB32());
    await prefs.setBool(_isDarkModeKey, _isDarkMode);
    await prefs.setString(_backgroundImageKey, _backgroundImagePath ?? '');
    await prefs.setString(_backgroundTypeKey, _backgroundMediaType);
    if (_backgroundImageBytes == null) {
      await prefs.remove(_backgroundBytesKey);
    } else {
      await prefs.setString(
          _backgroundBytesKey, base64.encode(_backgroundImageBytes!));
    }
  }

  // Pre-defined color schemes
  static const List<Color> predefinedColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
  ];

  Future<void> applyColorScheme(ColorScheme colorScheme) async {
    await setPrimaryColor(colorScheme.primary);
    await setDarkMode(colorScheme.brightness == Brightness.dark);
  }
}
