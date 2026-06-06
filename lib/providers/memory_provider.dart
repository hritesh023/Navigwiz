import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory.dart';

class MemoryProvider extends ChangeNotifier {
  final KnowledgeGraph _graph = KnowledgeGraph();
  List<MemoryEntry> _entries = [];
  bool _isLoading = false;

  KnowledgeGraph get graph => _graph;
  List<MemoryEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final savedGraph = prefs.getString('knowledge_graph');
    if (savedGraph != null) {
      final json = jsonDecode(savedGraph);
      final loaded = KnowledgeGraph.fromJson(json);
      _graph.nodes.addAll(loaded.nodes);
      _graph.edges.addAll(loaded.edges);
    }

    final savedEntries = prefs.getString('memory_entries');
    if (savedEntries != null) {
      final list = jsonDecode(savedEntries) as List;
      _entries = list.map((e) => MemoryEntry.fromJson(e)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('knowledge_graph', jsonEncode(_graph.toJson()));
    await prefs.setString('memory_entries', jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  void remember({
    required String type,
    required String content,
    String? url,
    String? workspaceId,
    List<String> tags = const [],
  }) {
    final entry = MemoryEntry(
      id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      content: content,
      url: url,
      workspaceId: workspaceId,
      tags: tags,
    );
    _entries.insert(0, entry);

    addNode(
      label: content.length > 100 ? '${content.substring(0, 100)}...' : content,
      type: type,
      properties: {'url': url, 'workspace_id': workspaceId},
    );

    if (_entries.length > 500) _entries.removeLast();
    _save();
    notifyListeners();
  }

  void addNode({
    required String label,
    required String type,
    String description = '',
    Map<String, dynamic> properties = const {},
  }) {
    final node = KnowledgeNode(
      id: 'node_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      type: type,
      description: description,
      properties: properties,
    );
    _graph.addNode(node);
    _save();
    notifyListeners();
  }

  void addEdge({
    required String sourceId,
    required String targetId,
    required String relationship,
    double weight = 1.0,
  }) {
    final edge = KnowledgeEdge(
      sourceId: sourceId,
      targetId: targetId,
      relationship: relationship,
      weight: weight,
    );
    _graph.addEdge(edge);
    _save();
    notifyListeners();
  }

  List<MemoryEntry> searchMemory(String query) {
    final q = query.toLowerCase();
    return _entries.where((e) =>
      e.content.toLowerCase().contains(q) ||
      e.tags.any((t) => t.toLowerCase().contains(q))
    ).toList();
  }

  List<MemoryEntry> getByType(String type) {
    return _entries.where((e) => e.type == type).toList();
  }

  List<MemoryEntry> getByWorkspace(String workspaceId) {
    return _entries.where((e) => e.workspaceId == workspaceId).toList();
  }

  void clearMemory() {
    _entries.clear();
    _graph.nodes.clear();
    _graph.edges.clear();
    _save();
    notifyListeners();
  }
}
