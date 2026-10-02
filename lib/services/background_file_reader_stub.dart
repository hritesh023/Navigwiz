import 'dart:typed_data';

// Web/stub implementation: no dart:io available, so path-based reads are
// impossible. The caller must rely on FilePicker bytes (withData: true).
Future<Uint8List?> readBackgroundFileBytes(String? path) async => null;
