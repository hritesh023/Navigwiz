import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'workspace_file_stub.dart'
    if (dart.library.js_interop) 'workspace_file_web.dart' as impl;

/// Saves workspace outputs (documents, images, etc.) as real files on the
/// user's device.
///
/// Desktop/mobile: writes directly under `~/NavigwizWorkspaces/<workspace>`.
/// Web: asks the user for folder permission (File System Access API) once per
/// session, then creates the files for real in the chosen folder.
class WorkspaceFileService {
  static String defaultWorkspaceRoot() {
    try {
      if (Platform.isWindows) {
        return '${Platform.environment['USERPROFILE']}\\NavigwizWorkspaces';
      }
      return '${Platform.environment['HOME']}/NavigwizWorkspaces';
    } catch (_) {
      return '${Directory.systemTemp.path}/NavigwizWorkspaces';
    }
  }

  static Future<String> saveText(
      String workspaceName, String fileName, String content) async {
    if (kIsWeb) return impl.saveText(workspaceName, fileName, content);
    final dir = Directory(
        '${defaultWorkspaceRoot()}/${_sanitize(workspaceName)}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/${_sanitize(fileName)}');
    await file.writeAsString(content);
    return file.path;
  }

  static Future<String> saveBytes(
      String workspaceName, String fileName, Uint8List bytes) async {
    if (kIsWeb) return impl.saveBytes(workspaceName, fileName, bytes);
    final dir = Directory(
        '${defaultWorkspaceRoot()}/${_sanitize(workspaceName)}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/${_sanitize(fileName)}');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^\w.\- ]'), '').trim();
}
