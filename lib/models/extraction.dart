class ExtractedField {
  final String name;
  final String value;
  final double confidence;

  ExtractedField({required this.name, required this.value, this.confidence = 1.0});

  Map<String, dynamic> toJson() => {'name': name, 'value': value, 'confidence': confidence};

  factory ExtractedField.fromJson(Map<String, dynamic> json) => ExtractedField(
    name: json['name'] ?? '', value: json['value'] ?? '',
    confidence: (json['confidence'] ?? 1.0).toDouble(),
  );
}

class ExtractedRecord {
  final Map<String, String> fields;
  final String? sourceUrl;

  ExtractedRecord({required this.fields, this.sourceUrl});

  Map<String, dynamic> toJson() => {'fields': fields, 'source_url': sourceUrl};

  factory ExtractedRecord.fromJson(Map<String, dynamic> json) => ExtractedRecord(
    fields: Map<String, String>.from(json['fields'] ?? {}),
    sourceUrl: json['source_url'],
  );
}

class ExtractionTemplate {
  final String id;
  final String name;
  final String description;
  final List<String> fields;
  final String category;

  ExtractionTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.fields = const [],
    this.category = 'custom',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description,
    'fields': fields, 'category': category,
  };

  factory ExtractionTemplate.fromJson(Map<String, dynamic> json) => ExtractionTemplate(
    id: json['id'] ?? '', name: json['name'] ?? '', description: json['description'] ?? '',
    fields: List<String>.from(json['fields'] ?? []), category: json['category'] ?? 'custom',
  );
}

enum ExportFormat { csv, excel, json, pdf }
