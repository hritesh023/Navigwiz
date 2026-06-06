class ResearchSource {
  final String title;
  final String url;
  final String snippet;
  final double relevanceScore;

  ResearchSource({required this.title, required this.url, required this.snippet, this.relevanceScore = 0});

  Map<String, dynamic> toJson() => {
    'title': title, 'url': url, 'snippet': snippet, 'relevance_score': relevanceScore,
  };

  factory ResearchSource.fromJson(Map<String, dynamic> json) => ResearchSource(
    title: json['title'] ?? '', url: json['url'] ?? '',
    snippet: json['snippet'] ?? '', relevanceScore: (json['relevance_score'] ?? 0).toDouble(),
  );
}

class ResearchFinding {
  final String id;
  final String finding;
  final String source;
  final double confidence;

  ResearchFinding({required this.id, required this.finding, required this.source, this.confidence = 0.8});

  Map<String, dynamic> toJson() => {
    'id': id, 'finding': finding, 'source': source, 'confidence': confidence,
  };

  factory ResearchFinding.fromJson(Map<String, dynamic> json) => ResearchFinding(
    id: json['id'] ?? '', finding: json['finding'] ?? '',
    source: json['source'] ?? '', confidence: (json['confidence'] ?? 0).toDouble(),
  );
}

class ResearchComparison {
  final String aspect;
  final Map<String, String> values;
  final String? insight;

  ResearchComparison({required this.aspect, required this.values, this.insight});

  Map<String, dynamic> toJson() => {
    'aspect': aspect, 'values': values, 'insight': insight,
  };

  factory ResearchComparison.fromJson(Map<String, dynamic> json) => ResearchComparison(
    aspect: json['aspect'] ?? '', values: Map<String, String>.from(json['values'] ?? {}), insight: json['insight'],
  );
}

class ResearchReport {
  final String id;
  final String query;
  final String executiveSummary;
  final List<ResearchFinding> keyFindings;
  final List<ResearchComparison> comparisons;
  final List<String> recommendations;
  final List<ResearchSource> references;
  final DateTime createdAt;

  ResearchReport({
    required this.id,
    required this.query,
    this.executiveSummary = '',
    this.keyFindings = const [],
    this.comparisons = const [],
    this.recommendations = const [],
    this.references = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id, 'query': query, 'executive_summary': executiveSummary,
    'key_findings': keyFindings.map((f) => f.toJson()).toList(),
    'comparisons': comparisons.map((c) => c.toJson()).toList(),
    'recommendations': recommendations,
    'references': references.map((r) => r.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
  };

  factory ResearchReport.fromJson(Map<String, dynamic> json) => ResearchReport(
    id: json['id'] ?? '', query: json['query'] ?? '',
    executiveSummary: json['executive_summary'] ?? '',
    keyFindings: (json['key_findings'] as List?)?.map((f) => ResearchFinding.fromJson(f)).toList() ?? [],
    comparisons: (json['comparisons'] as List?)?.map((c) => ResearchComparison.fromJson(c)).toList() ?? [],
    recommendations: List<String>.from(json['recommendations'] ?? []),
    references: (json['references'] as List?)?.map((r) => ResearchSource.fromJson(r)).toList() ?? [],
    createdAt: DateTime.tryParse(json['created_at'] ?? ''),
  );
}

class TaskObjective {
  final String id;
  final String objective;
  final String category;
  final String status;
  final ResearchReport? report;
  final DateTime createdAt;

  TaskObjective({
    required this.id,
    required this.objective,
    this.category = 'general',
    this.status = 'pending',
    this.report,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id, 'objective': objective, 'category': category,
    'status': status, 'report': report?.toJson(), 'created_at': createdAt.toIso8601String(),
  };

  factory TaskObjective.fromJson(Map<String, dynamic> json) => TaskObjective(
    id: json['id'] ?? '', objective: json['objective'] ?? '',
    category: json['category'] ?? 'general', status: json['status'] ?? 'pending',
    report: json['report'] != null ? ResearchReport.fromJson(json['report']) : null,
    createdAt: DateTime.tryParse(json['created_at'] ?? ''),
  );
}
