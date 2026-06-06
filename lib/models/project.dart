class ProjectFile {
  final String id;
  final String name;
  final String type;
  final String path;
  final int size;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  ProjectFile({
    required this.id,
    required this.name,
    required this.type,
    required this.path,
    this.size = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.metadata = const {},
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  ProjectFile copyWith({String? name, String? path, Map<String, dynamic>? metadata}) {
    return ProjectFile(
      id: id,
      name: name ?? this.name,
      type: type,
      path: path ?? this.path,
      size: size,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'type': type, 'path': path,
    'size': size, 'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(), 'metadata': metadata,
  };

  factory ProjectFile.fromJson(Map<String, dynamic> json) => ProjectFile(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    type: json['type'] ?? '',
    path: json['path'] ?? '',
    size: json['size'] ?? 0,
    createdAt: DateTime.tryParse(json['created_at'] ?? ''),
    updatedAt: DateTime.tryParse(json['updated_at'] ?? ''),
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}
