enum AttachmentType { file, folder, image, video, audio, link, document, other }

class Attachment {
  final String id;
  final String name;
  final String path;
  final AttachmentType type;
  final int size;
  final String? url;
  final String? analysisResult;
  final DateTime createdAt;

  Attachment({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    this.size = 0,
    this.url,
    this.analysisResult,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Attachment copyWith({String? analysisResult}) {
    return Attachment(
      id: id,
      name: name,
      path: path,
      type: type,
      size: size,
      url: url,
      analysisResult: analysisResult ?? this.analysisResult,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'path': path, 'type': type.name,
    'size': size, 'url': url, 'analysis_result': analysisResult,
    'created_at': createdAt.toIso8601String(),
  };

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    path: json['path'] ?? '',
    type: AttachmentType.values.firstWhere(
      (e) => e.name == json['type'], orElse: () => AttachmentType.other
    ),
    size: json['size'] ?? 0,
    url: json['url'],
    analysisResult: json['analysis_result'],
    createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
  );

  static AttachmentType typeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': case 'doc': case 'docx': case 'txt':
      case 'md': case 'json': case 'csv': case 'xlsx':
        return AttachmentType.document;
      case 'jpg': case 'jpeg': case 'png': case 'gif':
      case 'bmp': case 'webp': case 'svg':
        return AttachmentType.image;
      case 'mp4': case 'mov': case 'avi': case 'mkv':
      case 'webm': case 'flv':
        return AttachmentType.video;
      case 'mp3': case 'wav': case 'ogg': case 'flac':
      case 'aac': case 'm4a':
        return AttachmentType.audio;
      default:
        return AttachmentType.file;
    }
  }
}
