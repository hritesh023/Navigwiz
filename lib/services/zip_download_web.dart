import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import '../models/agent_response.dart';

void zipDownload(Uint8List bytes, String filename) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/zip'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

Future<String> saveToDevice(AgentProject project) async {
  final root = await _pickDirectory();
  if (root == null) {
    return _downloadProjectFiles(project);
  }

  final safeName = _sanitize(project.name.isEmpty ? 'project' : project.name);
  var written = 0;
  try {
    final projectDir = await root
        .getDirectoryHandle(
          safeName,
          web.FileSystemGetDirectoryOptions(create: true),
        )
        .toDart;

    for (final file in project.files) {
      final segments = file.path
          .split('/')
          .map(_sanitize)
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.isEmpty) continue;

      var dir = projectDir;
      for (final segment in segments.sublist(0, segments.length - 1)) {
        dir = await dir
            .getDirectoryHandle(
              segment,
              web.FileSystemGetDirectoryOptions(create: true),
            )
            .toDart;
      }

      final handle = await dir
          .getFileHandle(
            segments.last,
            web.FileSystemGetFileOptions(create: true),
          )
          .toDart;
      final writable = await handle.createWritable().toDart;
      await writable.write(file.content.toJS).toDart;
      await writable.close().toDart;
      written++;
    }
  } catch (_) {
    return 'Could not write files to the chosen folder.';
  }

  return written == 0
      ? 'No files were saved.'
      : 'Saved $written file${written == 1 ? '' : 's'} to $safeName';
}

String _downloadProjectFiles(AgentProject project) {
  for (final file in project.files) {
    final name = file.path.split('/').where((s) => s.isNotEmpty).lastOrNull;
    if (name == null) continue;
    final blob = web.Blob(
      [file.content.toJS].toJS,
      web.BlobPropertyBag(type: 'text/plain;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = name;
    anchor.click();
    web.URL.revokeObjectURL(url);
  }
  return project.files.isEmpty
      ? 'No files were saved.'
      : 'Downloaded ${project.files.length} file${project.files.length == 1 ? '' : 's'} to your Downloads folder';
}

Future<web.FileSystemDirectoryHandle?> _pickDirectory() async {
  try {
    return await _showDirectoryPicker().toDart;
  } catch (_) {
    return null;
  }
}

@JS('window.showDirectoryPicker')
external JSPromise<web.FileSystemDirectoryHandle> _showDirectoryPicker();

String _sanitize(String s) =>
    s.replaceAll(RegExp(r'[^\w.\- ]'), '').trim();
