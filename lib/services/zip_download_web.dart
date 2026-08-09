import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../models/agent_response.dart';

/// Web implementation: writes a generated project as real files into a folder
/// the user chooses through the browser's File System Access API (this is the
/// permission gate — the browser asks the user for access to that folder).
///
/// If the user cancels the permission dialog, nothing is downloaded and no
/// files are written.
Future<String> saveToDevice(AgentProject project) async {
  final root = await _pickDirectory();
  if (root == null) {
    return 'You cancelled the folder permission. The project files were not saved. '
        'Tap Save Project again and choose a folder to create the files.';
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
      : 'Created $written file${written == 1 ? '' : 's'} in $safeName';
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
