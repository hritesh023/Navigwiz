class WorkspaceItem {
  final String id;
  final String type;
  final String title;
  final String content;
  final String? url;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  WorkspaceItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.url,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.metadata = const {},
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  WorkspaceItem copyWith({String? title, String? content, String? url, Map<String, dynamic>? metadata}) {
    return WorkspaceItem(
      id: id,
      type: type,
      title: title ?? this.title,
      content: content ?? this.content,
      url: url ?? this.url,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'title': title, 'content': content,
    'url': url, 'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(), 'metadata': metadata,
  };

  factory WorkspaceItem.fromJson(Map<String, dynamic> json) => WorkspaceItem(
    id: json['id'] ?? '', type: json['type'] ?? '', title: json['title'] ?? '',
    content: json['content'] ?? '', url: json['url'],
    createdAt: DateTime.tryParse(json['created_at'] ?? ''),
    updatedAt: DateTime.tryParse(json['updated_at'] ?? ''),
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}

class Workspace {
  final String id;
  final String name;
  final String description;
  final String icon;
  final List<WorkspaceItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  Workspace({
    required this.id,
    required this.name,
    this.description = '',
    this.icon = 'workspaces',
    this.items = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Workspace copyWith({String? name, String? description, String? icon, List<WorkspaceItem>? items}) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description, 'icon': icon,
    'items': items.map((i) => i.toJson()).toList(),
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
  };

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
    id: json['id'] ?? '', name: json['name'] ?? '', description: json['description'] ?? '',
    icon: json['icon'] ?? 'workspaces',
    items: (json['items'] as List?)?.map((i) => WorkspaceItem.fromJson(i)).toList() ?? [],
    createdAt: DateTime.tryParse(json['created_at'] ?? ''),
    updatedAt: DateTime.tryParse(json['updated_at'] ?? ''),
  );
}
