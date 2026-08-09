import 'dart:typed_data';

Future<String> saveText(
        String workspaceName, String fileName, String content) async =>
    'Saving workspace files to this device is not supported on this platform.';

Future<String> saveBytes(
        String workspaceName, String fileName, Uint8List bytes) async =>
    'Saving workspace files to this device is not supported on this platform.';
