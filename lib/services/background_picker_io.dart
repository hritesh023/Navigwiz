import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'background_picker_types.dart';
import 'theme_service.dart';

/// Native (desktop/mobile) background picker via `file_picker`.
///
/// Never compiled on web, so `PlatformFile.path` is always safe here.
/// `withData: true` gives bytes directly; the filesystem read is a fallback
/// for large files where the plugin returns only a path.
Future<PickedBackground?> pickBackgroundImage({bool gifOnly = false}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: gifOnly
        ? const ['gif']
        : ThemeService.supportedImageExtensions,
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;

  Uint8List? bytes = file.bytes;
  if ((bytes == null || bytes.isEmpty)) {
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      try {
        final read = await File(path).readAsBytes();
        if (read.isNotEmpty) bytes = Uint8List.fromList(read);
      } catch (_) {}
    }
  }
  if (bytes == null || bytes.isEmpty) {
    throw StateError(
      gifOnly
          ? 'Could not read that GIF. It may be locked or too large — try a smaller GIF.'
          : 'Could not read that file. It may be locked or too large — try a smaller image.',
    );
  }
  return PickedBackground(
    name: file.name.isNotEmpty ? file.name : 'background',
    bytes: bytes,
    size: file.size,
  );
}
