import 'dart:io';
import 'dart:typed_data';

// Native (desktop/mobile) implementation: FilePicker sometimes returns only
// a path (large files, platform quirks), so read the file directly.
Future<Uint8List?> readBackgroundFileBytes(String? path) async {
  if (path == null || path.isEmpty) return null;
  try {
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) return bytes;
    }
  } catch (_) {}
  return null;
}
