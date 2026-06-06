class KnowledgeNode {
  final String id;
  final String label;
  final String type;
  final String description;
  final Map<String, dynamic> properties;
  final DateTime createdAt;

  KnowledgeNode({
    required this.id,
    required this.label,
    required this.type,
    this.description = '',
    this.properties = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id, 'label': label, 'type': type, 'description': description,
    'properties': properties, 'created_at': createdAt.toIso8601String(),
  };

  factory KnowledgeNode.fromJson(Map<String, dynamic> json) => KnowledgeNode(
    id: json['id'] ?? '', label: json['label'] ?? '',
    type: json['type'] ?? '', description: json['description'] ?? '',
    properties: Map<String, dynamic>.from(json['properties'] ?? {}),
    createdAt: DateTime.tryParse(json['created_at'] ?? ''),
  );
}

class KnowledgeEdge {
  final String sourceId;
  final String targetId;
  final String relationship;
  final double weight;

  KnowledgeEdge({required this.sourceId, required this.targetId, required this.relationship, this.weight = 1.0});

  Map<String, dynamic> toJson() => {
    'source_id': sourceId, 'target_id': targetId,
    'relationship': relationship, 'weight': weight,
  };

  factory KnowledgeEdge.fromJson(Map<String, dynamic> json) => KnowledgeEdge(
    sourceId: json['source_id'] ?? '', targetId: json['target_id'] ?? '',
    relationship: json['relationship'] ?? '', weight: (json['weight'] ?? 1.0).toDouble(),
  );
}

class KnowledgeGraph {
  final List<KnowledgeNode> nodes;
  final List<KnowledgeEdge> edges;

  KnowledgeGraph({List<KnowledgeNode>? nodes, List<KnowledgeEdge>? edges})
      : nodes = nodes ?? [],
        edges = edges ?? [];

  void addNode(KnowledgeNode node) {
    nodes.add(node);
  }

  void addEdge(KnowledgeEdge edge) {
    edges.add(edge);
  }

  List<KnowledgeNode> getRelated(String nodeId) {
    final relatedIds = edges
      .where((e) => e.sourceId == nodeId || e.targetId == nodeId)
      .map((e) => e.sourceId == nodeId ? e.targetId : e.sourceId)
      .toSet();
    return nodes.where((n) => relatedIds.contains(n.id)).toList();
  }

  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
  };

  factory KnowledgeGraph.fromJson(Map<String, dynamic> json) => KnowledgeGraph(
    nodes: (json['nodes'] as List?)?.map((n) => KnowledgeNode.fromJson(n)).toList() ?? [],
    edges: (json['edges'] as List?)?.map((e) => KnowledgeEdge.fromJson(e)).toList() ?? [],
  );
}

class MemoryEntry {
  final String id;
  final String type;
  final String content;
  final String? url;
  final String? workspaceId;
  final List<String> tags;
  final DateTime timestamp;

  MemoryEntry({
    required this.id,
    required this.type,
    required this.content,
    this.url,
    this.workspaceId,
    this.tags = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'content': content, 'url': url,
    'workspace_id': workspaceId, 'tags': tags,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) => MemoryEntry(
    id: json['id'] ?? '', type: json['type'] ?? '', content: json['content'] ?? '',
    url: json['url'], workspaceId: json['workspace_id'],
    tags: List<String>.from(json['tags'] ?? []),
    timestamp: DateTime.tryParse(json['timestamp'] ?? ''),
  );
}
