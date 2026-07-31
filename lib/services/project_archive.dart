import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../models/agent_response.dart';
import 'zip_download_stub.dart'
    if (dart.library.js_interop) 'zip_download_web.dart' as impl;

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

  static Future<Uint8List> buildZip(AgentProject project) async {
    final archive = Archive();
    for (final file in project.files) {
      final contentBytes = utf8.encode(file.content);
      archive.addFile(
          ArchiveFile(file.path, contentBytes.length, contentBytes));
    }
    final data = ZipEncoder().encode(archive);
    if (data == null) return Uint8List(0);
    return Uint8List.fromList(data);
  }

  static void downloadZip(Uint8List bytes, String filename) {
    impl.zipDownload(bytes, filename);
  }

  static Future<String> saveToDevice(AgentProject project) =>
      impl.saveToDevice(project);

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^\w.\- ]'), '').trim();
}
