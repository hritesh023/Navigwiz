import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/workspace.dart';

class WorkspaceProvider extends ChangeNotifier {
  List<Workspace> _workspaces = [];
  Workspace? _activeWorkspace;
  bool _isLoading = false;

  List<Workspace> get workspaces => _workspaces;
  Workspace? get activeWorkspace => _activeWorkspace;
  bool get isLoading => _isLoading;
  List<String> get workspaceIds => _workspaces.map((w) => w.id).toList();

  static const List<Map<String, String>> _defaultWorkspaces = [
    {'name': 'Startup', 'description': 'Competitor research, pricing analysis, ideas, notes', 'icon': 'rocket_launch'},
    {'name': 'Study', 'description': 'Assignments, lecture notes, research papers', 'icon': 'school'},
    {'name': 'Personal', 'description': 'Travel plans, shopping research, projects', 'icon': 'person'},
  ];

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('workspaces');
    if (saved != null) {
      final list = jsonDecode(saved) as List;
      _workspaces = list.map((w) => Workspace.fromJson(w)).toList();
    } else {
      int i = 0;
      _workspaces = _defaultWorkspaces.map((w) => Workspace(
        id: 'ws_${DateTime.now().millisecondsSinceEpoch}_$i',
        name: w['name']!,
        description: w['description']!,
        icon: w['icon']!,
      )).toList();
      await _save();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_workspaces.map((w) => w.toJson()).toList());
    await prefs.setString('workspaces', data);
  }

  void setActiveWorkspace(String id) {
    final index = _workspaces.indexWhere((w) => w.id == id);
    if (index == -1) return;
    _activeWorkspace = _workspaces[index];
    notifyListeners();
  }

  Future<void> addWorkspace(String name, {String description = '', String icon = 'workspaces'}) async {
    final ws = Workspace(
      id: 'ws_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      icon: icon,
    );
    _workspaces.add(ws);
    await _save();
    notifyListeners();
  }

  Future<void> updateWorkspace(String id, {String? name, String? description, String? icon}) async {
    final index = _workspaces.indexWhere((w) => w.id == id);
    if (index != -1) {
      final ws = _workspaces[index];
      _workspaces[index] = ws.copyWith(
        name: name,
        description: description,
        icon: icon,
      );
      if (_activeWorkspace?.id == id) _activeWorkspace = _workspaces[index];
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteWorkspace(String id) async {
    _workspaces.removeWhere((w) => w.id == id);
    if (_activeWorkspace?.id == id) _activeWorkspace = null;
    await _save();
    notifyListeners();
  }

  Future<void> addItemToWorkspace(String workspaceId, WorkspaceItem item) async {
    final index = _workspaces.indexWhere((w) => w.id == workspaceId);
    if (index != -1) {
      final ws = _workspaces[index];
      _workspaces[index] = ws.copyWith(items: [...ws.items, item]);
      await _save();
      notifyListeners();
    }
  }

  Future<void> removeItemFromWorkspace(String workspaceId, String itemId) async {
    final index = _workspaces.indexWhere((w) => w.id == workspaceId);
    if (index != -1) {
      final ws = _workspaces[index];
      _workspaces[index] = ws.copyWith(items: ws.items.where((i) => i.id != itemId).toList());
      await _save();
      notifyListeners();
    }
  }

  Future<void> updateItem(String workspaceId, String itemId, {String? title, String? content, String? url}) async {
    final wsIndex = _workspaces.indexWhere((w) => w.id == workspaceId);
    if (wsIndex != -1) {
      final ws = _workspaces[wsIndex];
      final itemIndex = ws.items.indexWhere((i) => i.id == itemId);
      if (itemIndex != -1) {
        final updatedItems = [...ws.items];
        updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(title: title, content: content, url: url);
        _workspaces[wsIndex] = ws.copyWith(items: updatedItems);
        await _save();
        notifyListeners();
      }
    }
  }

  List<WorkspaceItem> searchItems(String query) {
    final q = query.toLowerCase();
    final results = <WorkspaceItem>[];
    for (final ws in _workspaces) {
      for (final item in ws.items) {
        if (item.title.toLowerCase().contains(q) || item.content.toLowerCase().contains(q)) {
          results.add(item);
        }
      }
    }
    return results;
  }
}
