import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
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
  bool get isFresh => DateTime.now().difference(storedAt).inMinutes < 5;
}

class _CachedFullResponse {
  final SearchResponse response;
  final DateTime storedAt;
  const _CachedFullResponse({required this.response, required this.storedAt});
  bool get isFresh => DateTime.now().difference(storedAt).inMinutes < 5;
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
  static const Duration _searchTimeout = Duration(seconds: 10);
  static const int _maxResults = 50;

  final SecureStorageService _secureStorage = SecureStorageService();
  final LoggingService _logger = LoggingService();
  final Map<String, _CachedSearchResults> _searchCache = {};
  final Map<String, _CachedFullResponse> _fullSearchCache = {};

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
    final cacheKey = normalizedQuery.toLowerCase();
    final cachedResults = _searchCache[cacheKey];
    if (!forceRefresh && cachedResults != null && cachedResults.isFresh) {
      return cachedResults.results;
    }

    final fromWorker = await _searchViaWorker(normalizedQuery, 'web');
    if (fromWorker.isNotEmpty) {
      return _cacheSearchResults(cacheKey, fromWorker);
    }

    final fromDdg = await _searchDuckDuckGo(normalizedQuery);
    if (fromDdg.isNotEmpty) {
      return _cacheSearchResults(cacheKey, fromDdg);
    }

    return _cacheSearchResults(cacheKey, _fallbackResults(normalizedQuery));
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
    List<SearchResult> newsResults = [];
    List<SearchResult> videoResults = [];
    List<SearchResult> bookResults = [];
    List<String> suggestions = [];
    List<Infobox> infoboxes = [];
    List<String> answers = [];
    int? resultCount;

    if (category == 'all') {
      final fullResponse = await _searchFull(query, forceRefresh: forceRefresh);
      results = fullResponse.results;
      imageResults = fullResponse.imageResults;
      newsResults = fullResponse.newsResults;
      videoResults = fullResponse.videoResults;
      bookResults = fullResponse.bookResults;
      suggestions = fullResponse.suggestions;
      infoboxes = fullResponse.infoboxes;
      answers = fullResponse.answers;
      resultCount = fullResponse.resultCount;
    } else if (category == 'images') {
      imageResults = await searchImages(query);
      results = imageResults;
    } else if (category == 'videos' || category == 'news' || category == 'books') {
      results = await searchByCategory(query, category);
      if (category == 'videos') {
        videoResults = results.where((r) => r.imageUrl != null).toList();
        imageResults = List.from(videoResults);
      }
      if (category == 'books') {
        bookResults = results;
      }
    } else {
      results = await searchWeb(query, forceRefresh: forceRefresh);
      try {
        imageResults = await searchImages(query);
      } catch (_) {}
      try {
        videoResults = await searchByCategory(query, 'videos');
      } catch (_) {}
    }

    String aiAnswer = '';
    if (waitForAi && (category == 'all' || category == 'images')) {
      aiAnswer = await getAiAnswerForSearch(results, query);
    }

    stopwatch.stop();
    final searchTime = '${stopwatch.elapsed.inMilliseconds}ms';

    return SearchResponse(
      aiAnswer: aiAnswer,
      results: results,
      imageResults: imageResults,
      newsResults: newsResults,
      videoResults: videoResults,
      bookResults: bookResults,
      suggestions: suggestions,
      infoboxes: infoboxes,
      answers: answers,
      resultCount: resultCount,
      searchTime: searchTime,
    );
  }

  Future<String> getAiAnswerForSearch(List<SearchResult> results, String query) async {
    if (results.isEmpty) return '';
    try {
      final sourceText = results.take(10).map((r) => '- ${r.title}\n  URL: ${r.url}\n  Snippet: ${r.description}').join('\n');
      return await _askAi(
        'Query: $query\n\nSearch results:\n$sourceText',
        extraInstructions: 'Provide a concise answer to the query based on search results. Be brief and informative.',
      );
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
    }

    List<SearchResult> results = [];
    List<SearchResult> imageResults = [];
    List<SearchResult> newsResults = [];
    List<SearchResult> videoResults = [];

    try {
      results = await searchWeb(query, forceRefresh: forceRefresh);
    } catch (_) {}

    if (results.isEmpty) {
      results = _fallbackResults(normalizedQuery);
    }

    try {
      imageResults = await searchImages(query);
    } catch (_) {}
    if (imageResults.isEmpty) {
      imageResults = _fallbackResults(normalizedQuery, category: 'images');
    }

    try {
      final videos = await searchByCategory(query, 'videos');
      videoResults = videos;
    } catch (_) {}
    if (videoResults.isEmpty) {
      videoResults = _fallbackResults(normalizedQuery, category: 'videos');
    }

    try {
      newsResults = await searchByCategory(query, 'news');
    } catch (_) {}
    if (newsResults.isEmpty) {
      newsResults = _fallbackResults(normalizedQuery, category: 'news');
    }

    List<SearchResult> bookResults = [];
    try {
      bookResults = _fallbackResults(normalizedQuery, category: 'books');
    } catch (_) {}

    final searchResponse = SearchResponse(
      aiAnswer: '',
      results: results,
      imageResults: imageResults.take(12).toList(),
      newsResults: newsResults.take(10).toList(),
      videoResults: videoResults.take(8).toList(),
      bookResults: bookResults,
      suggestions: [],
      infoboxes: [],
      answers: [],
      resultCount: results.length,
    );

    _fullSearchCache[cacheKey] = _CachedFullResponse(response: searchResponse, storedAt: DateTime.now());
    return searchResponse;
  }

  List<SearchResult> _fallbackResults(String query, {String category = 'all'}) {
    final encoded = Uri.encodeComponent(query);

    if (category == 'images') {
      return [
        SearchResult(title: '$query - Images', url: 'https://unsplash.com/s/photos/$encoded', description: 'High-resolution photos related to "$query".', relevanceScore: 0.9),
        SearchResult(title: '$query - Photos', url: 'https://pixabay.com/images/search/$encoded/', description: 'Free stock images for "$query".', relevanceScore: 0.85),
        SearchResult(title: '$query - Visuals', url: 'https://www.flickr.com/search/?q=$encoded', description: 'Photos tagged with "$query".', relevanceScore: 0.8),
        SearchResult(title: '$query - Stock', url: 'https://www.pexels.com/search/$encoded/', description: 'Stock photos related to "$query".', relevanceScore: 0.75),
      ];
    }

    if (category == 'videos') {
      return [
        SearchResult(title: '$query - Videos', url: 'https://www.youtube.com/results?search_query=$encoded', description: 'Video results for "$query".', relevanceScore: 0.9),
        SearchResult(title: '$query - Video Clips', url: 'https://vimeo.com/search?q=$encoded', description: 'Videos about "$query" on Vimeo.', relevanceScore: 0.85),
        SearchResult(title: '$query - Dailymotion', url: 'https://www.dailymotion.com/search/$encoded', description: 'Video clips related to "$query".', relevanceScore: 0.8),
      ];
    }

    if (category == 'news') {
      final now = DateTime.now();
      return [
        SearchResult(title: '$query - Latest News', url: 'https://news.google.com/search?q=$encoded', description: 'Latest news coverage of "$query".', relevanceScore: 0.9, publishedDate: now.toIso8601String()),
        SearchResult(title: '$query - Reuters', url: 'https://www.reuters.com/search/news?blob=$encoded', description: 'Reuters coverage of "$query".', relevanceScore: 0.85, publishedDate: now.subtract(const Duration(hours: 2)).toIso8601String()),
        SearchResult(title: '$query - BBC', url: 'https://www.bbc.co.uk/search?q=$encoded', description: 'BBC News coverage of "$query".', relevanceScore: 0.8, publishedDate: now.subtract(const Duration(hours: 4)).toIso8601String()),
        SearchResult(title: '$query - AP News', url: 'https://apnews.com/search?q=$encoded', description: 'AP News articles about "$query".', relevanceScore: 0.75, publishedDate: now.subtract(const Duration(hours: 3)).toIso8601String()),
      ];
    }

    if (category == 'books') {
      return [
        SearchResult(title: '$query - Books', url: 'https://books.google.com/books?q=$encoded', description: 'Books related to "$query".', relevanceScore: 0.9),
        SearchResult(title: '$query - Open Library', url: 'https://openlibrary.org/search?q=$encoded', description: 'Browse Open Library for books about "$query".', relevanceScore: 0.85),
        SearchResult(title: '$query - Goodreads', url: 'https://www.goodreads.com/search?q=$encoded', description: 'Book ratings and reviews for "$query".', relevanceScore: 0.8),
        SearchResult(title: '$query - Project Gutenberg', url: 'https://www.gutenberg.org/ebooks/search/?query=$encoded', description: 'Free classic eBooks related to "$query".', relevanceScore: 0.75),
        SearchResult(title: '$query - Internet Archive', url: 'https://archive.org/search?query=$encoded', description: 'Search the Internet Archive for books about "$query".', relevanceScore: 0.7),
      ];
    }

    return [
      SearchResult(title: '$query - Wikipedia', url: 'https://en.wikipedia.org/w/index.php?search=$encoded', description: 'Encyclopedia information about "$query".', relevanceScore: 0.9),
      SearchResult(title: '$query - Britannica', url: 'https://www.britannica.com/search?query=$encoded', description: 'Encyclopedia entry for "$query".', relevanceScore: 0.85),
      SearchResult(title: '$query - YouTube', url: 'https://www.youtube.com/results?search_query=$encoded', description: 'Videos about "$query" on YouTube.', relevanceScore: 0.8),
      SearchResult(title: '$query - Reddit', url: 'https://www.reddit.com/search/?q=$encoded', description: 'Community discussions about "$query".', relevanceScore: 0.75),
    ];
  }

  Future<List<SearchResult>> _searchViaWorker(String query, String category) async {
    if (!AppConfig.hasWorker) return [];

    try {
      final uri = Uri.parse('${AppConfig.workerUrl}/search').replace(queryParameters: {
        'q': query,
        'category': category,
      });
      final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(_searchTimeout);

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

  Future<List<SearchResult>> _searchDuckDuckGo(String query) async {
    try {
      final uri = Uri.parse('https://html.duckduckgo.com/html/')
          .replace(queryParameters: {'q': query, 'ia': 'web'});
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(_searchTimeout);

      if (response.statusCode != 200) return [];

      final body = response.body;
      final results = <SearchResult>[];

      final resultRegex = RegExp(
        r'<a[^>]*class="result__a[^"]*"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        dotAll: true,
      );
      final snippetRegex = RegExp(
        r'class="result__snippet[^"]*"[^>]*>(.*?)</(?:a|div|span)>',
        dotAll: true,
      );

      final linkMatches = resultRegex.allMatches(body).toList();
      final snippetMatches = snippetRegex.allMatches(body).toList();

      for (var i = 0; i < linkMatches.length && results.length < _maxResults; i++) {
        final match = linkMatches[i];
        var rawUrl = match.group(1)?.trim() ?? '';
        final rawTitle = _stripHtml(match.group(2)?.trim() ?? '');
        if (rawTitle.isEmpty || rawUrl.isEmpty) continue;

        final url = _extractDdgUrl(rawUrl);
        if (url == null || url.contains('duckduckgo.com') || url.contains('duck.com')) continue;

        String snippet = '';
        if (i < snippetMatches.length) {
          snippet = _stripHtml(snippetMatches[i].group(1)?.trim() ?? '');
        }

        results.add(SearchResult(
          title: rawTitle,
          url: url,
          description: snippet,
          relevanceScore: (1 - (results.length * 0.01)).clamp(0.0, 1.0),
        ));
      }

      if (results.isEmpty) {
        return await _searchDuckDuckGoLite(query);
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  Future<List<SearchResult>> _searchDuckDuckGoLite(String query) async {
    try {
      final uri = Uri.parse('https://lite.duckduckgo.com/lite/')
          .replace(queryParameters: {'q': query});
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(_searchTimeout);

      if (response.statusCode != 200) return [];

      final body = response.body;
      final results = <SearchResult>[];

      final rowRegex = RegExp(
        r'<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
        dotAll: true,
      );

      for (final match in rowRegex.allMatches(body)) {
        if (results.length >= _maxResults) break;
        var rawUrl = match.group(1)?.trim() ?? '';
        final rawTitle = _stripHtml(match.group(2)?.trim() ?? '');
        if (rawTitle.isEmpty || rawUrl.isEmpty) continue;

        final url = rawUrl.startsWith('//') ? 'https:$rawUrl' : rawUrl;
        if (url.contains('duckduckgo.com') || url.contains('duck.com')) continue;

        results.add(SearchResult(
          title: rawTitle,
          url: url,
          description: '',
          relevanceScore: (1 - (results.length * 0.01)).clamp(0.0, 1.0),
        ));
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  String? _extractDdgUrl(String rawUrl) {
    try {
      if (rawUrl.startsWith('//')) rawUrl = 'https:$rawUrl';
      final uri = Uri.parse(rawUrl);
      final uddg = uri.queryParameters['uddg'];
      if (uddg != null && uddg.isNotEmpty) return Uri.decodeComponent(uddg);
      if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) return rawUrl;
      return null;
    } catch (_) {
      return null;
    }
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  Future<List<SearchResult>> searchByCategory(String query, String category) async {
    if (category == 'images') return searchImages(query);

    final fromWorker = await _searchViaWorker(query, category);
    if (fromWorker.isNotEmpty) return fromWorker;

    return _fallbackResults(query, category: category);
  }

  Future<List<SearchResult>> searchImages(String query) async {
    final fromWorker = await _searchViaWorker(query, 'images');
    if (fromWorker.isNotEmpty) return fromWorker;

    return _fallbackResults(query, category: 'images');
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
}