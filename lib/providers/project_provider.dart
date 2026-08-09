import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent_response.dart';
import '../models/project.dart';
import '../services/project_archive.dart';

class ProjectProvider extends ChangeNotifier {
  List<ProjectFile> _files = [];
  bool _isLoading = false;
  String _projectRoot = '';

  List<ProjectFile> get files => _files;
  bool get isLoading => _isLoading;
  String get projectRoot => _projectRoot;

  void setProjectRoot(String path) {
    _projectRoot = path;
    notifyListeners();
  }

  Future<void> refreshFiles(String directory) async {
    _isLoading = true;
    notifyListeners();
    _files.clear();
    try {
      final dir = Directory(directory);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          final stat = await entity.stat();
          _files.add(ProjectFile(
            id: 'proj_${DateTime.now().millisecondsSinceEpoch}_${_files.length}',
            name: entity.path.split(Platform.pathSeparator).last,
            type: entity is Directory ? 'folder' : entity.path.split('.').last,
            path: entity.path,
            size: stat.size,
          ));
        }
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('project_files');
    if (saved != null) {
      final list = jsonDecode(saved) as List;
      _files = list.map((f) => ProjectFile.fromJson(f)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createFile(String directory, String name, String type, {String content = ''}) async {
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final filePath = '$directory/$name';
      final file = File(filePath);
      await file.writeAsString(content);

      final projectFile = ProjectFile(
        id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        type: type,
        path: filePath,
        size: await file.length(),
      );

      _files.add(projectFile);
      await _save();
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating file: $e');
    }
  }

  Future<void> createFolder(String directory, String name) async {
    try {
      final dir = Directory('$directory/$name');
      await dir.create(recursive: true);

      final projectFile = ProjectFile(
        id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        type: 'folder',
        path: dir.path,
      );

      _files.add(projectFile);
      await _save();
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating folder: $e');
    }
  }

  Future<void> deleteFile(String id) async {
    final index = _files.indexWhere((f) => f.id == id);
    if (index != -1) {
      final file = _files[index];
      try {
        final f = File(file.path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
      _files.removeAt(index);
      await _save();
      notifyListeners();
    }
  }

  Future<void> openFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        if (Platform.isWindows) {
          await Process.run('explorer', [path]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [path]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [path]);
        }
      }
    } catch (_) {}
  }

  List<ProjectFile> getFilesByType(String type) {
    return _files.where((f) => f.type == type).toList();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_files.map((f) => f.toJson()).toList());
    await prefs.setString('project_files', data);
  }

  String _defaultProjectRoot() {
    try {
      if (Platform.isWindows) {
        return '${Platform.environment['USERPROFILE']}\\NavigwizProjects';
      }
      return '${Platform.environment['HOME']}/NavigwizProjects';
    } catch (_) {
      return '${Directory.systemTemp.path}/NavigwizProjects';
    }
  }

  String get defaultProjectRoot => _defaultProjectRoot();

  Future<String> saveAgentProject(AgentProject project) async {
    if (kIsWeb) {
      return ProjectArchiveService.saveToDevice(project);
    }

    final root = _projectRoot.isNotEmpty ? _projectRoot : _defaultProjectRoot();
    final path = await ProjectArchiveService.saveToDisk(root, project);
    await refreshFiles(root);
    return path;
  }
}
