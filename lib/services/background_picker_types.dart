import 'dart:typed_data';

/// Result of picking a background image/GIF.
///
/// Platform-agnostic: produced from a browser data-URL on web (Equyvo-style)
/// or from `file_picker` bytes on native. Callers never touch
/// `PlatformFile.path`, so the web "use bytes instead" crash is impossible.
class PickedBackground {
  /// Original file name (e.g. `sunset.png`). Metadata only.
  final String name;

  /// Raw file bytes, ready for [ThemeService.prepareBackgroundBytes].
  final Uint8List bytes;

  /// File size in bytes as reported by the picker.
  final int size;

  /// MIME type when known (e.g. `image/gif`). May be null on native.
  final String? mimeType;

  const PickedBackground({
    required this.name,
    required this.bytes,
    required this.size,
    this.mimeType,
  });
}
