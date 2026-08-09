import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

web.FileSystemDirectoryHandle? _cachedHandle;

Future<web.FileSystemDirectoryHandle?> _directory() async {
  if (_cachedHandle != null) return _cachedHandle;
  try {
    final handle = await _showDirectoryPicker().toDart;
    _cachedHandle = handle;
    return handle;
  } catch (_) {
    return null;
  }
}

Future<String> saveText(
    String workspaceName, String fileName, String content) async {
  final root = await _directory();
  if (root == null) {
    return 'Permission needed: choose a folder to save workspace files.';
  }
  try {
    final dir = await _workspaceDir(root, workspaceName);
    final file = await dir
        .getFileHandle(fileName, web.FileSystemGetFileOptions(create: true))
        .toDart;
    final writable = await file.createWritable().toDart;
    await writable.write(content.toJS).toDart;
    await writable.close().toDart;
    return '$workspaceName/$fileName';
  } catch (_) {
    return 'Could not write $fileName to the chosen folder.';
  }
}

Future<String> saveBytes(
    String workspaceName, String fileName, Uint8List bytes) async {
  final root = await _directory();
  if (root == null) {
    return 'Permission needed: choose a folder to save workspace files.';
  }
  try {
    final dir = await _workspaceDir(root, workspaceName);
    final file = await dir
        .getFileHandle(fileName, web.FileSystemGetFileOptions(create: true))
        .toDart;
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/octet-stream'),
    );
    final writable = await file.createWritable().toDart;
    await writable.write(blob).toDart;
    await writable.close().toDart;
    return '$workspaceName/$fileName';
  } catch (_) {
    return 'Could not write $fileName to the chosen folder.';
  }
}

Future<web.FileSystemDirectoryHandle> _workspaceDir(
    web.FileSystemDirectoryHandle root, String name) async {
  return root
      .getDirectoryHandle(name, web.FileSystemGetDirectoryOptions(create: true))
      .toDart;
}

@JS('window.showDirectoryPicker')
external JSPromise<web.FileSystemDirectoryHandle> _showDirectoryPicker();
