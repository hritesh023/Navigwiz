class AgentSource {
  final String title;
  final String url;
  final String snippet;

  const AgentSource({required this.title, required this.url, this.snippet = ''});

  factory AgentSource.fromJson(Map<String, dynamic> json) => AgentSource(
        title: json['title']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        snippet: json['snippet']?.toString() ?? json['content']?.toString() ?? '',
      );
}

class AgentProjectFile {
  final String path;
  final String content;

  const AgentProjectFile({required this.path, required this.content});

  String get name {
    final segments = path.split('/');
    return segments.isNotEmpty ? segments.last : path;
  }

  factory AgentProjectFile.fromJson(Map<String, dynamic> json) => AgentProjectFile(
        path: json['path']?.toString() ?? json['name']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
      );
}

class AgentProject {
  final String name;
  final String language;
  final String summary;
  final List<AgentProjectFile> files;

  const AgentProject({
    this.name = '',
    this.language = '',
    this.summary = '',
    this.files = const [],
  });

  factory AgentProject.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    final files = <AgentProjectFile>[];
    if (rawFiles is List) {
      for (final f in rawFiles) {
        if (f is Map) {
          files.add(AgentProjectFile.fromJson(Map<String, dynamic>.from(f)));
        }
      }
    } else if (rawFiles is Map) {
      rawFiles.forEach((path, content) {
        files.add(AgentProjectFile(
          path: path.toString(),
          content: content?.toString() ?? '',
        ));
      });
    }
    return AgentProject(
      name: json['project_name']?.toString() ?? json['name']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      summary: json['summary']?.toString() ?? json['description']?.toString() ?? '',
      files: files,
    );
  }
}

class AgentResearchFinding {
  final String title;
  final String finding;
  final List<String> sources;

  const AgentResearchFinding({
    this.title = '',
    this.finding = '',
    this.sources = const [],
  });

  factory AgentResearchFinding.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    return AgentResearchFinding(
      title: json['title']?.toString() ?? '',
      finding: json['finding']?.toString() ??
          json['content']?.toString() ??
          json['snippet']?.toString() ??
          '',
      sources: rawSources is List
          ? rawSources.map((s) => s.toString()).where((s) => s.isNotEmpty).toList()
          : const [],
    );
  }
}

class AgentResearch {
  final String executiveSummary;
  final List<AgentResearchFinding> keyFindings;
  final List<String> recommendations;
  final List<AgentSource> references;
  final String markdown;

  const AgentResearch({
    this.executiveSummary = '',
    this.keyFindings = const [],
    this.recommendations = const [],
    this.references = const [],
    this.markdown = '',
  });

  factory AgentResearch.fromJson(Map<String, dynamic> json) {
    List<String> toStringList(dynamic value) {
      if (value is List) return value.map((e) => e.toString()).toList();
      if (value is Map) return value.values.map((e) => e.toString()).toList();
      return const [];
    }

    final findings = <AgentResearchFinding>[];
    final rawFindings = json['key_findings'] ?? json['findings'];
    if (rawFindings is List) {
      for (final f in rawFindings) {
        if (f is Map) {
          findings.add(AgentResearchFinding.fromJson(Map<String, dynamic>.from(f)));
        } else {
          final text = f.toString();
          if (text.trim().isNotEmpty) {
            findings.add(AgentResearchFinding(finding: text));
          }
        }
      }
    }

    final refs = <AgentSource>[];
    final rawRefs = json['references'] ?? json['sources'];
    if (rawRefs is List) {
      for (final r in rawRefs) {
        if (r is Map) {
          refs.add(AgentSource.fromJson(Map<String, dynamic>.from(r)));
        } else {
          refs.add(AgentSource(title: r.toString(), url: r.toString()));
        }
      }
    }

    return AgentResearch(
      executiveSummary: json['executive_summary']?.toString() ?? json['summary']?.toString() ?? '',
      keyFindings: findings,
      recommendations: toStringList(json['recommendations']),
      references: refs,
      markdown: json['markdown']?.toString() ?? json['response']?.toString() ?? '',
    );
  }
}

class AgentResponse {
  final String response;
  final String sessionId;
  final String mode;
  final bool isSimple;
  final List<AgentSource> sources;
  final List<String> suggestions;
  final AgentResearch? research;
  final AgentProject? project;
  final String? imageData;

  const AgentResponse({
    this.response = '',
    this.sessionId = '',
    this.mode = 'chat',
    this.isSimple = false,
    this.sources = const [],
    this.suggestions = const [],
    this.research,
    this.project,
    this.imageData,
  });

  factory AgentResponse.fromJson(Map<String, dynamic> json) {
    final sources = <AgentSource>[];
    final rawSources = json['sources'];
    if (rawSources is List) {
      for (final s in rawSources) {
        if (s is Map) {
          sources.add(AgentSource.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }

    final suggestions = <String>[];
    final rawSuggestions = json['suggestions'];
    if (rawSuggestions is List) {
      suggestions.addAll(rawSuggestions.whereType<String>());
    }

    AgentResearch? research;
    final rawResearch = json['research'];
    if (rawResearch is Map) {
      research = AgentResearch.fromJson(Map<String, dynamic>.from(rawResearch));
    }

    AgentProject? project;
    final rawProject = json['project'];
    if (rawProject is Map) {
      project = AgentProject.fromJson(Map<String, dynamic>.from(rawProject));
    }

    return AgentResponse(
      response: json['response']?.toString() ?? json['answer']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      mode: json['mode']?.toString() ?? json['type']?.toString() ?? 'chat',
      isSimple: json['is_simple'] == true,
      sources: sources,
      suggestions: suggestions,
      research: research,
      project: project,
      imageData: json['image_data']?.toString(),
    );
  }
}

class AgentChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final AgentResponse? agentResponse;
  final bool isError;

  const AgentChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.agentResponse,
    this.isError = false,
  });
}
