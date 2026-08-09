import 'dart:io';
import '../models/agent_response.dart';
import 'zip_download_stub.dart'
    if (dart.library.js_interop) 'zip_download_web.dart' as impl;

/// Persists AI-generated projects as real files on the user's device.
///
/// On desktop/mobile this writes directly into a folder under the project
/// root (default `~/NavigwizProjects`). On web it asks the user for folder
/// permission via the browser File System Access API, then writes each file
/// into the chosen folder. No zip/download involved — files are created for
/// real, just like a local coding agent would.
class ProjectArchiveService {
  static Future<String> saveToDisk(String rootDir, AgentProject project) async {
    final safeName = _sanitize(project.name.isEmpty ? 'project' : project.name);
    final projectDir = Directory('$rootDir/$safeName');
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }

    for (final file in project.files) {
      final segments = file.path
          .split('/')
          .map(_sanitize)
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.isEmpty) continue;

      if (segments.length > 1) {
        final dir = Directory([
          projectDir.path,
          ...segments.sublist(0, segments.length - 1),
        ].join(Platform.pathSeparator));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      final target = File(
          [projectDir.path, ...segments].join(Platform.pathSeparator));
      await target.writeAsString(file.content);
    }
    return projectDir.path;
  }

  static Future<String> saveToDevice(AgentProject project) =>
      impl.saveToDevice(project);

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^\w.\- ]'), '').trim();
}
