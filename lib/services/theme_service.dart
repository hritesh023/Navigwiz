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

  /// Max stored background size. SharedPreferences on web uses localStorage
  /// (~5MB quota), so base64-encoded media must stay well under that limit
  /// or the save silently fails and the background "does not show up".
  static const int maxBackgroundBytes = 2500000;
  static const int maxBackgroundDimension = 1920;

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
      try {
        _backgroundImageBytes = base64.decode(encodedMedia);
      } catch (_) {
        _backgroundImageBytes = null;
        _backgroundMediaType = 'none';
        await prefs.remove(_backgroundBytesKey);
      }
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
    if (imageBytes.isEmpty) {
      throw ArgumentError('Selected file is empty.');
    }
    final isGif = _isGifBytes(imageBytes);
    final Uint8List prepared =
        isGif ? imageBytes : await _compressStaticImage(imageBytes);
    if (prepared.lengthInBytes > maxBackgroundBytes) {
      throw StateError(
          'That file is too large (${(prepared.lengthInBytes / 1048576).toStringAsFixed(1)} MB). Please pick an image/GIF under 2 MB.');
    }

    _backgroundImageBytes = prepared;
    _backgroundImagePath = path;
    // Preserve the gif type so the UI can render it animated.
    _backgroundMediaType = isGif ? 'gif' : 'image';

    if (!isGif) {
      // Extract dominant color only for static images. Decoding an animated
      // GIF here is expensive and can fail, which previously left the
      // background unset with no error shown to the user.
      final dominantColor = _extractDominantColor(prepared);
      if (dominantColor != null) {
        _primaryColor = dominantColor;
      }
    }

    await _saveThemeSettings();
    _updateTheme();
  }

  /// GIF magic bytes: GIF87a or GIF89a.
  bool _isGifBytes(Uint8List bytes) {
    if (bytes.lengthInBytes < 6) return false;
    return bytes[0] == 0x47 && // G
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x38 && // 8
        (bytes[4] == 0x37 || bytes[4] == 0x39) && // 7 or 9
        bytes[5] == 0x61; // a
  }

  /// Downscales large static images and re-encodes as JPEG so the stored
  /// base64 string fits in SharedPreferences/localStorage on every platform.
  /// GIFs are never passed through here (animation must be preserved).
  Future<Uint8List> _compressStaticImage(Uint8List bytes) async {
    try {
      // Small enough already — store as-is.
      if (bytes.lengthInBytes <= maxBackgroundBytes) {
        final probe = img.decodeImage(bytes);
        if (probe == null ||
            (probe.width <= maxBackgroundDimension &&
                probe.height <= maxBackgroundDimension)) {
          return bytes;
        }
      }
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;
      img.Image resized = image;
      if (image.width > maxBackgroundDimension ||
          image.height > maxBackgroundDimension) {
        resized = img.copyResize(
          image,
          width: image.width >= image.height ? maxBackgroundDimension : null,
          height: image.height > image.width ? maxBackgroundDimension : null,
        );
      }
      final encoded = img.encodeJpg(resized, quality: 85);
      final out = Uint8List.fromList(encoded);
      // If JPEG encoding somehow grew the file, keep the original.
      return out.lengthInBytes < bytes.lengthInBytes ? out : bytes;
    } catch (e) {
      debugPrint('Background compress failed, storing original: $e');
      return bytes;
    }
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
      // May throw on web when localStorage quota is exceeded — callers
      // surface this to the user instead of failing silently.
      final ok = await prefs.setString(
          _backgroundBytesKey, base64.encode(_backgroundImageBytes!));
      if (!ok) {
        throw StateError(
            'Could not save background (storage full). Try a smaller image.');
      }
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
