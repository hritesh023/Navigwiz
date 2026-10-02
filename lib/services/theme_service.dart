import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

class ThemeService extends ChangeNotifier {
  static const String _backgroundImageKey = 'background_image_path';
  static const String _backgroundBytesKey = 'background_media_bytes';
  static const String _backgroundTypeKey = 'background_media_type';
  static const String _backgroundZoomKey = 'background_zoom';
  static const String _backgroundOffsetXKey = 'background_offset_x';
  static const String _backgroundOffsetYKey = 'background_offset_y';
  static const String _primaryColorKey = 'primary_color';
  static const String _isDarkModeKey = 'is_dark_mode';

  /// Hard cap on stored background size. SharedPreferences on web uses
  /// localStorage (~5MB quota shared with every other pref) and base64
  /// inflates bytes by ~33%, so anything above this risks quota errors and
  /// the background "does not show up".
  static const int maxBackgroundBytes = 2500000;
  static const int maxBackgroundDimension = 1920;
  /// Quota-safe target: compressed outputs aim well under the hard cap so
  /// the base64 string (~target x 1.37) fits comfortably alongside other
  /// prefs on web localStorage.
  static const int targetBackgroundBytes = 1500000;
  /// Refuse to decode files larger than this (OOM guard on web: decoding
  /// allocates width x height x 4 per frame).
  static const int maxDecodeBytes = 12 * 1024 * 1024;
  static const int maxGifSide = 960;
  static const int maxGifFrames = 48;

  /// Extensions Flutter can actually render via Image.memory (Skia codec).
  /// The picker is restricted to these so users can't select SVG/AVIF/HEIC
  /// files that would decode in Dart but show as broken in Flutter.
  static const List<String> supportedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'wbmp',
  ];

  ThemeData _lightTheme = _buildDefaultTheme(false);
  ThemeData _darkTheme = _buildDefaultTheme(true);
  Color _primaryColor = Colors.blue;
  bool _isDarkMode = true;
  String? _backgroundImagePath;
  Uint8List? _backgroundImageBytes;
  String _backgroundMediaType = 'none';
  double _backgroundZoom = 1.0;
  double _backgroundOffsetX = 0.0; // normalized -1..1
  double _backgroundOffsetY = 0.0; // normalized -1..1

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

  double get backgroundZoom => _backgroundZoom;
  double get backgroundOffsetX => _backgroundOffsetX;
  double get backgroundOffsetY => _backgroundOffsetY;

  Future<void> setBackgroundFraming(
      {required double zoom,
      required double offsetX,
      required double offsetY}) async {
    _backgroundZoom = zoom.clamp(0.5, 4.0);
    _backgroundOffsetX = offsetX.clamp(-1.0, 1.0);
    _backgroundOffsetY = offsetY.clamp(-1.0, 1.0);
    await _saveThemeSettings();
    _updateTheme();
  }

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
    try {
      final prefs = await SharedPreferences.getInstance();

      try {
        _primaryColor =
            Color(prefs.getInt(_primaryColorKey) ?? Colors.blue.toARGB32());
      } catch (_) {
        _primaryColor = Colors.blue;
      }
      try {
        _isDarkMode = prefs.getBool(_isDarkModeKey) ?? true;
      } catch (_) {
        _isDarkMode = true;
      }
      try {
        _backgroundImagePath = prefs.getString(_backgroundImageKey);
        _backgroundMediaType =
            prefs.getString(_backgroundTypeKey) ?? 'none';
        _backgroundZoom = prefs.getDouble(_backgroundZoomKey) ?? 1.0;
        _backgroundOffsetX = prefs.getDouble(_backgroundOffsetXKey) ?? 0.0;
        _backgroundOffsetY = prefs.getDouble(_backgroundOffsetYKey) ?? 0.0;
      } catch (_) {
        _backgroundImagePath = null;
        _backgroundMediaType = 'none';
        _backgroundZoom = 1.0;
        _backgroundOffsetX = 0.0;
        _backgroundOffsetY = 0.0;
      }
      String? encodedMedia;
      try {
        encodedMedia = prefs.getString(_backgroundBytesKey);
      } catch (_) {
        encodedMedia = null;
      }
      if (encodedMedia != null && encodedMedia.isNotEmpty) {
        try {
          final Uint8List full = base64.decode(encodedMedia);
          // Drop corrupt/oversized/unsupported payloads instead of keeping
          // a background that can never render (the old "shows error but
          // no image" failure).
          if (full.isEmpty ||
              full.lengthInBytes > maxBackgroundBytes ||
              !isSupportedImageBytes(full)) {
            throw const FormatException('unsupported stored background');
          }
          _backgroundImageBytes = full;
          // Self-heal a stale media-type flag (e.g. gif saved as image).
          _backgroundMediaType =
              isGifBytes(_backgroundImageBytes!) ? 'gif' : 'image';
        } catch (_) {
          _backgroundImageBytes = null;
          _backgroundMediaType = 'none';
          try {
            await prefs.remove(_backgroundBytesKey);
          } catch (_) {}
        }
      }
    } catch (_) {
      // prefs itself unavailable — keep in-memory defaults, never crash boot.
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

  /// Validates + compresses raw picked bytes into quota-safe storage
  /// bytes. Returns exactly what will be saved. Throws a user-friendly
  /// message when the file cannot be used.
  Future<Uint8List> prepareBackgroundBytes(Uint8List raw,
      {String? fileName}) async {
    if (raw.isEmpty) {
      throw ArgumentError('Selected file is empty.');
    }
    if (raw.lengthInBytes > maxDecodeBytes) {
      throw StateError(
          'That file is too large (${(raw.lengthInBytes / 1048576).toStringAsFixed(1)} MB). Please pick an image/GIF under 12 MB.');
    }
    final unsupported = unsupportedFormatReason(raw, fileName: fileName);
    if (unsupported != null) {
      throw StateError(unsupported);
    }
    final Uint8List prepared = isGifBytes(raw)
        ? await _compressGifImage(raw)
        : await _compressStaticImage(raw);
    if (prepared.lengthInBytes > maxBackgroundBytes) {
      throw StateError(
          'That file is still too large (${(prepared.lengthInBytes / 1048576).toStringAsFixed(1)} MB) even after compression. Please pick a smaller image/GIF.');
    }
    // Final gate: make sure Flutter's own codec can render what we are
    // about to save. The `image` package decodes formats (TIFF/TGA/ICO)
    // that Skia cannot, which used to save successfully and then show a
    // broken-image icon everywhere ("not working showing error").
    final renderable = await flutterCanRender(prepared);
    if (!renderable) {
      throw StateError(
          'That file could not be displayed as a background. Please pick a JPG, PNG, GIF or WebP image.');
    }
    return prepared;
  }

  /// Persists bytes produced by [prepareBackgroundBytes] (no recompression,
  /// so the preview the user approved is exactly what gets saved).
  Future<void> applyPreparedBackground(Uint8List prepared,
      {String? path}) async {
    if (prepared.isEmpty) {
      throw ArgumentError('Selected file is empty.');
    }
    if (prepared.lengthInBytes > maxBackgroundBytes) {
      throw StateError(
          'That file is too large. Please pick a smaller image/GIF.');
    }
    _backgroundImageBytes = prepared;
    _backgroundImagePath = path;
    _backgroundZoom = 1.0;
    _backgroundOffsetX = 0.0;
    _backgroundOffsetY = 0.0;
    // Preserve the gif type so the UI can render it animated.
    _backgroundMediaType = isGifBytes(prepared) ? 'gif' : 'image';
    // NOTE: the user's chosen accent color is intentionally left alone —
    // silently re-tinting the whole browser on every background change
    // surprised users (it looked like the apply "did something wrong").

    await _saveThemeSettings();
    _updateTheme();
  }

  Future<void> setBackgroundImageBytes(Uint8List imageBytes,
      {String? path, String? fileName}) async {
    final prepared =
        await prepareBackgroundBytes(imageBytes, fileName: fileName ?? path);
    await applyPreparedBackground(prepared, path: path);
  }

  /// GIF magic bytes: GIF87a or GIF89a.
  static bool isGifBytes(Uint8List bytes) {
    if (bytes.lengthInBytes < 6) return false;
    return bytes[0] == 0x47 && // G
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x38 && // 8
        (bytes[4] == 0x37 || bytes[4] == 0x39) && // 7 or 9
        bytes[5] == 0x61; // a
  }

  static bool _isJpegBytes(Uint8List bytes) {
    return bytes.lengthInBytes >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }

  static bool _isPngBytes(Uint8List bytes) {
    return bytes.lengthInBytes >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  static bool _isWebPBytes(Uint8List bytes) {
    return bytes.lengthInBytes >= 12 &&
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46 && // F
        bytes[8] == 0x57 && // W
        bytes[9] == 0x45 && // E
        bytes[10] == 0x42 && // B
        bytes[11] == 0x50; // P
  }

  static bool _isBmpBytes(Uint8List bytes) {
    return bytes.lengthInBytes >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D;
  }

  /// True when Flutter's Skia codec can render these bytes (JPEG/PNG/GIF/
  /// WebP/BMP). Anything else (SVG/AVIF/HEIC/TIFF/ICO/raw text) would save
  /// fine but show as a broken-image icon — the classic "not working" report.
  static bool isSupportedImageBytes(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    return isGifBytes(bytes) ||
        _isJpegBytes(bytes) ||
        _isPngBytes(bytes) ||
        _isWebPBytes(bytes) ||
        _isBmpBytes(bytes);
  }

  /// Friendly reason when [bytes] are not a supported raster image, or null
  /// when they look fine. Checks magic bytes first (cheap) so text/SVG never
  /// reaches the expensive decoder.
  static String? unsupportedFormatReason(Uint8List bytes,
      {String? fileName}) {
    if (isSupportedImageBytes(bytes)) return null;
    final name = (fileName ?? '').toLowerCase();
    final head = String.fromCharCodes(
      bytes.take(64).where((b) => b >= 32 && b < 127),
    ).toLowerCase();
    if (head.contains('<svg') || head.contains('<!doctype svg')) {
      return 'SVG files are not supported as backgrounds. Please pick a JPG, PNG, GIF or WebP image.';
    }
    if (head.contains('<html') || head.contains('<!doctype html')) {
      return 'That file is a web page, not an image. Please pick a JPG, PNG, GIF or WebP image.';
    }
    if (name.endsWith('.svg')) {
      return 'SVG files are not supported as backgrounds. Please pick a JPG, PNG, GIF or WebP image.';
    }
    if (name.endsWith('.avif')) {
      return 'AVIF images are not supported on this device yet. Please pick a JPG, PNG, GIF or WebP image.';
    }
    if (name.endsWith('.heic') ||
        name.endsWith('.heif') ||
        name.endsWith('.tiff') ||
        name.endsWith('.tif') ||
        name.endsWith('.ico') ||
        name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.webm') ||
        name.endsWith('.mp3') ||
        name.endsWith('.pdf')) {
      return 'That file type is not supported as a background. Please pick a JPG, PNG, GIF or WebP image.';
    }
    // ftyp box => ISO-BMFF (AVIF/HEIC/MP4/MOV) misnamed as image.
    if (bytes.lengthInBytes >= 12 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      return 'That file is not a supported image (AVIF/HEIC/video). Please pick a JPG, PNG, GIF or WebP image.';
    }
    return 'That file is not a supported image. Please pick a JPG, PNG, GIF or WebP image.';
  }

  /// Asks Flutter's own image codec whether [bytes] render. Used as the
  /// final gate before saving so "saved but shows broken icon" can never
  /// happen. Never throws — returns false on any failure/timeout.
  static Future<bool> flutterCanRender(Uint8List bytes) async {
    if (bytes.isEmpty) return false;
    try {
      await decodeImageFromList(bytes).timeout(
        const Duration(seconds: 10),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reads GIF canvas size straight from the 10-byte header (no full
  /// decode, no frame allocation). Returns null when not a parseable GIF.
  static List<int>? gifDimensions(Uint8List bytes) {
    if (bytes.lengthInBytes < 10 || !isGifBytes(bytes)) return null;
    final w = bytes[6] | (bytes[7] << 8);
    final h = bytes[8] | (bytes[9] << 8);
    if (w <= 0 || h <= 0 || w > 10000 || h > 10000) return null;
    return [w, h];
  }

  /// Downscales large static images so the stored base64 string fits in
  /// SharedPreferences/localStorage on every platform. Two-pass
  /// (1920px/q82, then 1280px/q72) so even noisy phone photos land under
  /// the quota-safe target. EXIF orientation is baked so portrait photos
  /// don't show up sideways. Images with transparency are encoded as PNG
  /// (JPEG has no alpha and would turn transparent areas black). GIFs never
  /// pass through here.
  Future<Uint8List> _compressStaticImage(Uint8List bytes) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      img.Image oriented = decoded;
      try {
        oriented = img.bakeOrientation(decoded);
      } catch (_) {}
      img.Image working = oriented;
      if (working.width > maxBackgroundDimension ||
          working.height > maxBackgroundDimension) {
        final landscape = working.width >= working.height;
        working = img.copyResize(
          working,
          width: landscape ? maxBackgroundDimension : null,
          height: landscape ? null : maxBackgroundDimension,
          interpolation: img.Interpolation.linear,
        );
      }
      final bool keepAlpha = working.hasAlpha;
      Uint8List encodeJpg(img.Image src, int quality) =>
          Uint8List.fromList(img.encodeJpg(src, quality: quality));
      Uint8List encodePng(img.Image src) =>
          Uint8List.fromList(img.encodePng(src));
      var out = keepAlpha ? encodePng(working) : encodeJpg(working, 82);
      if (out.lengthInBytes > targetBackgroundBytes &&
          (working.width > 1280 || working.height > 1280)) {
        final landscape = working.width >= working.height;
        final smaller = img.copyResize(
          working,
          width: landscape ? 1280 : null,
          height: landscape ? null : 1280,
          interpolation: img.Interpolation.linear,
        );
        final retry =
            keepAlpha ? encodePng(smaller) : encodeJpg(smaller, 72);
        if (retry.lengthInBytes < out.lengthInBytes) out = retry;
      }
      // If re-encoding somehow grew the file, keep the original.
      return out.lengthInBytes < bytes.lengthInBytes ? out : bytes;
    } catch (e) {
      debugPrint('Background compress failed, storing original: $e');
      return bytes;
    }
  }

  /// Shrinks oversized GIFs while preserving animation so user-chosen
  /// GIFs fit in SharedPreferences/localStorage. Small GIFs pass through
  /// untouched WITHOUT a full decode (header check only — decoding allocates
  /// width x height x 4 bytes per frame). Long GIFs are evenly sampled
  /// (full story kept) instead of truncated. Returns original bytes on any
  /// decode failure so the caller can report size honestly.
  Future<Uint8List> _compressGifImage(Uint8List bytes) async {
    try {
      final dims = gifDimensions(bytes);
      if (dims != null &&
          bytes.lengthInBytes <= targetBackgroundBytes &&
          dims[0] <= 1280 &&
          dims[1] <= 1280) {
        return bytes;
      }
      final gif = img.decodeGif(bytes);
      if (gif == null || gif.numFrames == 0) return bytes;
      // Iterative shrink: each pass samples fewer frames at a smaller size
      // (from the ORIGINAL decode, never re-compressing a compressed pass).
      // Typical GIFs fit on pass 1; only pathological files loop further.
      // copyResize resizes every frame of an animated image at once and
      // keeps per-frame durations.
      var side = maxGifSide;
      var frameCap = maxGifFrames;
      var sampling = 20;
      Uint8List best = bytes;
      for (var attempt = 0; attempt < 4; attempt++) {
        img.Image working = gif;
        if (working.numFrames > frameCap) {
          working = sampleGifFrames(working, frameCap);
        }
        final maxSide = working.width >= working.height
            ? working.width
            : working.height;
        if (maxSide > side) {
          final landscape = working.width >= working.height;
          working = img.copyResize(
            working,
            width: landscape ? side : null,
            height: landscape ? null : side,
          );
        }
        final encoded =
            img.encodeGif(working, samplingFactor: sampling);
        final out = Uint8List.fromList(encoded);
        if (out.lengthInBytes < best.lengthInBytes) best = out;
        if (best.lengthInBytes <= targetBackgroundBytes) break;
        // Tighten for the next pass (floors keep results usable).
        side = (side * 0.7).round().clamp(320, maxGifSide);
        frameCap = (frameCap * 2 ~/ 3).clamp(12, maxGifFrames);
        sampling = 30;
        if (side <= 320 && frameCap <= 12) break;
      }
      // Never return something bigger than what we were given.
      return best.lengthInBytes < bytes.lengthInBytes ? best : bytes;
    } catch (e) {
      debugPrint('GIF compress failed, storing original: $e');
      return bytes;
    }
  }

  /// Evenly samples [maxFrames] frames from an animated image so long GIFs
  /// keep their full story instead of being cut off after the first N
  /// frames. Frame durations, loop count and type are preserved.
  static img.Image sampleGifFrames(img.Image gif, int maxFrames) {
    final total = gif.numFrames;
    if (total <= maxFrames) return gif;
    img.Image? out;
    final step = total / maxFrames;
    for (var i = 0; i < maxFrames; i++) {
      final idx = (i * step).floor().clamp(0, total - 1);
      final single = img.Image.from(gif.frames[idx], noAnimation: true);
      if (out == null) {
        out = single;
      } else {
        out.addFrame(single);
      }
    }
    out!.frameType = gif.frameType;
    out.loopCount = gif.loopCount;
    return out;
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
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      throw StateError(
          'Could not save settings (storage unavailable). Please try again.');
    }
    try {
      await prefs.setInt(_primaryColorKey, _primaryColor.toARGB32());
      await prefs.setBool(_isDarkModeKey, _isDarkMode);
      await prefs.setString(_backgroundImageKey, _backgroundImagePath ?? '');
      await prefs.setString(_backgroundTypeKey, _backgroundMediaType);
      await prefs.setDouble(_backgroundZoomKey, _backgroundZoom);
      await prefs.setDouble(_backgroundOffsetXKey, _backgroundOffsetX);
      await prefs.setDouble(_backgroundOffsetYKey, _backgroundOffsetY);
    } catch (_) {
      // Non-background prefs failing should never block the UI; the
      // background write below carries its own quota error.
    }
    if (_backgroundImageBytes == null) {
      try {
        await prefs.remove(_backgroundBytesKey);
      } catch (_) {}
    } else {
      // On web this writes to localStorage and throws QuotaExceededError
      // when full (rather than returning false) — translate both into one
      // friendly message instead of leaking the raw platform error.
      try {
        final ok = await prefs.setString(
            _backgroundBytesKey, base64.encode(_backgroundImageBytes!));
        if (!ok) {
          throw StateError(
              'Could not save background (storage full). Try a smaller image or GIF.');
        }
      } catch (e) {
        if (e is StateError) rethrow;
        throw StateError(
            'Could not save background (storage full). Try a smaller image or GIF.');
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
