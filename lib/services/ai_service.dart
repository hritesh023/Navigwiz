import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/agent_response.dart';
import 'logging_service.dart';
import 'secure_storage_service.dart';

class SearchResult {
  final String title;
  final String url;
  final String description;
  final double relevanceScore;
  final String? imageUrl;
  final String? publishedDate;

  SearchResult({
    required this.title,
    required this.url,
    required this.description,
    required this.relevanceScore,
    this.imageUrl,
    this.publishedDate,
  });
}

class InfoboxAttribute {
  final String label;
  final String value;
  InfoboxAttribute({required this.label, required this.value});
}

class Infobox {
  final String title;
  final String content;
  final String? url;
  final String? imgSrc;
  final List<InfoboxAttribute> attributes;

  Infobox({required this.title, required this.content, this.url, this.imgSrc, this.attributes = const []});
}

class SearchResponse {
  final String aiAnswer;
  final List<SearchResult> results;
  final List<SearchResult> imageResults;
  final List<SearchResult> newsResults;
  final List<SearchResult> videoResults;
  final List<SearchResult> bookResults;
  final List<String> suggestions;
  final List<Infobox> infoboxes;
  final List<String> answers;
  final int? resultCount;
  final String searchTime;

  SearchResponse({
    required this.aiAnswer,
    required this.results,
    this.imageResults = const [],
    this.newsResults = const [],
    this.videoResults = const [],
    this.bookResults = const [],
    this.suggestions = const [],
    this.infoboxes = const [],
    this.answers = const [],
    this.resultCount,
    this.searchTime = '',
  });
}

class _CachedSearchResults {
  final List<SearchResult> results;
  final DateTime storedAt;
  const _CachedSearchResults({required this.results, required this.storedAt});
  bool get isFresh => DateTime.now().difference(storedAt).inMinutes < 15;
  bool get isUsable => DateTime.now().difference(storedAt).inMinutes < 60;
}

class _CachedFullResponse {
  final SearchResponse response;
  final DateTime storedAt;
  const _CachedFullResponse({required this.response, required this.storedAt});
  bool get isFresh => DateTime.now().difference(storedAt).inMinutes < 15;
  bool get isUsable => DateTime.now().difference(storedAt).inMinutes < 60;
}

class AIMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  AIMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.metadata,
  });
}

class AIService extends ChangeNotifier {
  static const int _maxResults = 50;

  final SecureStorageService _secureStorage = SecureStorageService();
  final LoggingService _logger = LoggingService();
  final Map<String, _CachedSearchResults> _searchCache = {};
  final Map<String, _CachedFullResponse> _fullSearchCache = {};
  // Deduplicates concurrent identical searches so every surface
  // (search, research, projects, build, workspace) shares one fast request.
  final Map<String, Future<List<SearchResult>>> _inflightSearches = {};

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    await _logger.initialize();
  }

  Future<List<SearchResult>> searchWeb(
    String query, {
    bool forceRefresh = false,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const <SearchResult>[];
    final cacheKey = normalizedQuery.toLowerCase();
    final cachedResults = _searchCache[cacheKey];
    if (!forceRefresh && cachedResults != null && cachedResults.isFresh) {
      return cachedResults.results;
    }
    // Stale-while-revalidate: show usable (stale) results instantly while a
    // background refresh fetches fresh ones. Makes every page feel instant.
    if (!forceRefresh && cachedResults != null && cachedResults.isUsable) {
      _refreshInBackground(cacheKey, normalizedQuery);
      return cachedResults.results;
    }

    // Share one network request across concurrent callers.
    final inflight = _inflightSearches[cacheKey];
    if (!forceRefresh && inflight != null) return inflight;

    final future = _searchViaWorker(normalizedQuery, 'web').then((fromWorker) {
      if (fromWorker.isNotEmpty) return _cacheSearchResults(cacheKey, fromWorker);
      // Keep stale results rather than flashing empty on transient errors.
      if (cachedResults != null) return cachedResults.results;
      return const <SearchResult>[];
    }).whenComplete(() => _inflightSearches.remove(cacheKey));
    _inflightSearches[cacheKey] = future;
    return future;
  }

  void _refreshInBackground(String cacheKey, String query) {
    if (_inflightSearches.containsKey(cacheKey)) return;
    final future = _searchViaWorker(query, 'web').then((fromWorker) {
      if (fromWorker.isNotEmpty) return _cacheSearchResults(cacheKey, fromWorker);
      return _searchCache[cacheKey]?.results ?? const <SearchResult>[];
    }).whenComplete(() => _inflightSearches.remove(cacheKey));
    _inflightSearches[cacheKey] = future;
  }

  Future<SearchResponse> searchWithOverview(
    String query, {
    bool forceRefresh = false,
    String category = 'all',
    bool waitForAi = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    List<SearchResult> results = [];
    List<SearchResult> imageResults = [];
    List<String> suggestions = [];
    List<Infobox> infoboxes = [];
    List<String> answers = [];
    int? resultCount;

    // Web results + photos fire TOGETHER (not serially): total wait is the
    // slower of the two, not the sum. Best-effort on images.
    final webFuture = _searchFull(query, forceRefresh: forceRefresh);
    final imagesFuture = searchImages(query).timeout(
      const Duration(seconds: 3),
      onTimeout: () => const <SearchResult>[],
    ).catchError((_) => const <SearchResult>[]);

    final fullResponse = await webFuture;
    results = fullResponse.results;
    suggestions = fullResponse.suggestions;
    infoboxes = fullResponse.infoboxes;
    answers = fullResponse.answers;
    resultCount = fullResponse.resultCount;
    try {
      imageResults = await imagesFuture;
    } catch (_) {
      imageResults = const <SearchResult>[];
    }

    String aiAnswer = '';
    if (waitForAi) {
      aiAnswer = await getAiAnswerForSearch(results, query);
    }

    stopwatch.stop();
    final searchTime = '${stopwatch.elapsed.inMilliseconds}ms';

    return SearchResponse(
      aiAnswer: aiAnswer,
      results: results,
      imageResults: imageResults,
      suggestions: suggestions,
      infoboxes: infoboxes,
      answers: answers,
      resultCount: resultCount,
      searchTime: searchTime,
    );
  }

  /// AI Overview: always answers FIRST with the power of AI (latest, correct),
  /// then the caller renders links/photos below it. Even with zero web
  /// results we still ask the AI directly so the user never gets a blank page.
  ///
  /// Uses the LLM-only `/v1/answer` endpoint over the sources we already
  /// fetched — the backend does NOT search again, so the overview costs one
  /// LLM call instead of a second full search + LLM roundtrip.
  Future<String> getAiAnswerForSearch(List<SearchResult> results, String query) async {
    try {
      return await answerWithSources(
        query,
        results
            .take(10)
            .map((r) => {
                  'title': r.title,
                  'url': r.url,
                  'content': r.description,
                })
            .toList(),
      );
    } catch (_) {
      return '';
    }
  }

  /// Single LLM call over caller-provided sources. No backend search runs.
  Future<String> answerWithSources(
    String query,
    List<Map<String, String>> sources,
  ) async {
    if (!AppConfig.hasWorker) return '';
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.workerUrl}/v1/answer'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'query': query,
              'sources': sources,
              'session_id': 'navigwiz',
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        final text = decoded['response']?.toString() ?? '';
        if (text.isNotEmpty) return text;
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  List<SearchResult> _cacheSearchResults(String cacheKey, List<SearchResult> results) {
    _searchCache[cacheKey] = _CachedSearchResults(results: results, storedAt: DateTime.now());
    return results;
  }

  Future<SearchResponse> _searchFull(String query, {bool forceRefresh = false}) async {
    final normalizedQuery = query.trim();
    final cacheKey = 'full_${normalizedQuery.toLowerCase()}';

    if (!forceRefresh) {
      final cached = _fullSearchCache[cacheKey];
      if (cached != null && cached.isFresh) return cached.response;
      if (cached != null && cached.isUsable) {
        // Return stale instantly; refresh behind the scenes.
        unawaited(_refreshFullInBackground(cacheKey, normalizedQuery));
        return cached.response;
      }
    }

    List<SearchResult> results = [];

    try {
      results = await searchWeb(query, forceRefresh: forceRefresh);
    } catch (_) {}

    final searchResponse = SearchResponse(
      aiAnswer: '',
      results: results,
      suggestions: _suggestionsFor(query, results),
      infoboxes: const [],
      answers: const [],
      resultCount: results.length,
    );

    _fullSearchCache[cacheKey] = _CachedFullResponse(response: searchResponse, storedAt: DateTime.now());
    return searchResponse;
  }

  Future<void> _refreshFullInBackground(String cacheKey, String query) async {
    try {
      final results = await searchWeb(query, forceRefresh: true);
      _fullSearchCache[cacheKey] = _CachedFullResponse(
        response: SearchResponse(
          aiAnswer: '',
          results: results,
          suggestions: _suggestionsFor(query, results),
          infoboxes: const [],
          answers: const [],
          resultCount: results.length,
        ),
        storedAt: DateTime.now(),
      );
    } catch (_) {}
  }

  List<String> _suggestionsFor(String query, List<SearchResult> results) {
    final out = <String>[];
    for (final r in results.take(6)) {
      final title = r.title.trim();
      if (title.isNotEmpty && title.toLowerCase() != query.trim().toLowerCase()) {
        out.add(title);
        if (out.length >= 3) break;
      }
    }
    return out;
  }

  Future<List<SearchResult>> _searchViaWorker(String query, String category) async {
    if (!AppConfig.hasWorker) return [];

    // Single fast attempt with a short timeout — the backend search path is
    // now tightly budgeted (~2.5s), so a retry would just add serial latency.
    try {
      final uri = Uri.parse('${AppConfig.workerUrl}/search').replace(queryParameters: {
        'q': query,
        'category': category,
      });
      final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode != 200) return [];

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return [];

      final rawResults = decoded['results'];
      if (rawResults is! List || rawResults.isEmpty) return [];

      return _parseWorkerResults(rawResults);
    } catch (_) {
      return [];
    }
  }

  List<SearchResult> _parseWorkerResults(List rawResults) {
    final results = <SearchResult>[];
    for (final item in rawResults.take(_maxResults)) {
      if (item is! Map) continue;
      final title = item['title']?.toString().trim() ?? '';
      final url = item['url']?.toString().trim() ?? '';
      if (title.isEmpty || url.isEmpty) continue;
      if (!_isAbsoluteHttpUrl(url)) continue;
      results.add(SearchResult(
        title: title,
        url: url,
        description: (item['content']?.toString().trim() ?? item['snippet']?.toString().trim() ?? ''),
        imageUrl: item['img_src']?.toString().trim(),
        publishedDate: item['publishedDate']?.toString().trim(),
        relevanceScore: (1 - (results.length * 0.02)).clamp(0.0, 1.0),
      ));
    }
    return results;
  }

  bool _isAbsoluteHttpUrl(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return false;
    return u.scheme == 'http' || u.scheme == 'https';
  }

  Future<List<SearchResult>> searchByCategory(String query, String category) async {
    if (category == 'images') return searchImages(query);

    final fromWorker = await _searchViaWorker(query, category);
    if (fromWorker.isNotEmpty) return fromWorker;

    return const <SearchResult>[];
  }

  Future<List<SearchResult>> searchImages(String query) async {
    final fromWorker = await _searchViaWorker(query, 'images');
    if (fromWorker.isNotEmpty) return fromWorker;

    return const <SearchResult>[];
  }

  Future<String> askAi(String input, {String? extraInstructions}) async {
    return _askAi(input, extraInstructions: extraInstructions);
  }

  Future<String> _askAi(String input, {String? extraInstructions}) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_secureStorage.isRateLimited('ai')) {
        return 'Too many requests. Please wait a moment.';
      }

      final apiUrl = AppConfig.hasWorker
          ? '${AppConfig.workerUrl}/v1/chat'
          : 'https://acronous.com/v1/chat';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': extraInstructions != null ? '$extraInstructions\n\nUser: $input' : input,
          'session_id': 'navigwiz',
        }),
      ).timeout(AppConfig.aiResponseTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        final text = decoded['response']?.toString() ?? '';
        if (text.isNotEmpty) return text;
      }
      return '';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static const Duration _agentTimeout = Duration(minutes: 5);

  Future<AgentResponse> sendAgentMessage(
    String message, {
    String? mode,
    String? sessionId,
  }) async {
    if (!AppConfig.hasWorker) {
      return const AgentResponse(
        response: 'AI service is not configured. Please set the WORKER_URL.',
        isSimple: true,
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.workerUrl}/v1/chat'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'message': message,
              if (mode != null) 'mode': mode,
              'session_id': sessionId ?? 'navigwiz',
            }),
          )
          .timeout(_agentTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return AgentResponse.fromJson(decoded);
        }
      }
      return AgentResponse(
        response: 'The AI service returned an error (${response.statusCode}). Please try again.',
        isSimple: true,
      );
    } catch (e) {
      return const AgentResponse(
        response: 'Could not reach the AI service. Please check your connection and try again.',
        isSimple: true,
      );
    }
  }

  Future<AgentResponse> runResearchAgent(String query) async {
    if (!AppConfig.hasWorker) {
      return const AgentResponse(
        response: 'AI service is not configured.',
        isSimple: true,
      );
    }
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.workerUrl}/v1/research'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'query': query, 'session_id': 'navigwiz'}),
          )
          .timeout(_agentTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return AgentResponse.fromJson(decoded);
        }
      }
      return AgentResponse(
        response: 'Research service returned an error (${response.statusCode}).',
        isSimple: true,
      );
    } catch (_) {
      return const AgentResponse(
        response: 'Could not reach the AI service. Please check your connection and try again.',
        isSimple: true,
      );
    }
  }

  Future<AgentResponse> generateProjectAgent(
    String description, {
    String? language,
  }) async {
    if (!AppConfig.hasWorker) {
      return const AgentResponse(
        response: 'AI service is not configured.',
        isSimple: true,
      );
    }
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.workerUrl}/v1/project/generate'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'description': description,
              if (language != null) 'language': language,
              'session_id': 'navigwiz',
            }),
          )
          .timeout(_agentTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return AgentResponse.fromJson(decoded);
        }
      }
      return AgentResponse(
        response: 'Project service returned an error (${response.statusCode}).',
        isSimple: true,
      );
    } catch (_) {
      return const AgentResponse(
        response: 'Could not reach the AI service. Please check your connection and try again.',
        isSimple: true,
      );
    }
  }

  /// Agentic build: the AI first searches the web for up-to-date context, then
  /// creates a complete runnable project (real files/folders) for the user.
  Future<AgentResponse> buildProjectAgent(
    String description, {
    String? language,
  }) async {
    if (!AppConfig.hasWorker) {
      return const AgentResponse(
        response: 'AI service is not configured.',
        isSimple: true,
      );
    }
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.workerUrl}/v1/agent/build'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'description': description,
              if (language != null) 'language': language,
              'session_id': 'navigwiz',
            }),
          )
          .timeout(_agentTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return AgentResponse.fromJson(decoded);
        }
      }
      return AgentResponse(
        response: 'Project build returned an error (${response.statusCode}).',
        isSimple: true,
      );
    } catch (_) {
      return const AgentResponse(
        response: 'Could not reach the AI service. Please check your connection and try again.',
        isSimple: true,
      );
    }
  }

  Future<String> generateImage(String prompt) async {
    if (!AppConfig.hasWorker) return '';
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.workerUrl}/v1/image/generate'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'prompt': prompt,
              'session_id': 'navigwiz',
            }),
          )
          .timeout(const Duration(minutes: 3));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          final data = decoded['image_data']?.toString() ?? decoded['base64']?.toString();
          if (data != null && data.isNotEmpty) return data;
          return decoded['url']?.toString() ?? '';
        }
      }
      return '';
    } catch (_) {
      return '';
    }
  }
}