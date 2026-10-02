import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import '../models/browser_tab.dart';
import '../models/history_entry.dart';
import '../utils/domain_helper.dart';

class BrowserService extends ChangeNotifier {
  static const int maxHistoryEntries = 500;
  static const String _historyV2Key = 'history_v2';
  static const String _legacyHistoryKey = 'history';
  final List<BrowserTab> _tabs = [];
  int _activeTabIndex = 0;
  int _reloadNonce = 0;
  WebViewController? _webViewController;
  List<String> _bookmarks = [];
  final List<HistoryEntry> _historyEntries = [];
  bool _privateMode = false;
  String _searchEngine = 'navigwiz';
  String _homepageUrl = '';

  // Per-tab navigation history for web platform
  final Map<String, List<String>> _tabHistory = {};
  final Map<String, List<String>> _tabForwardHistory = {};
  int _tabIdCounter = 0;

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  int get activeTabIndex => _activeTabIndex;
  int get reloadNonce => _reloadNonce;
  BrowserTab? get activeTab => _tabs.isNotEmpty ? _tabs[_activeTabIndex] : null;
  WebViewController? get webViewController => _webViewController;
  List<String> get bookmarks => List.unmodifiable(_bookmarks);
  /// Newest-first browsing history with titles + timestamps.
  List<HistoryEntry> get historyEntries => List.unmodifiable(_historyEntries);
  /// Legacy accessor (URLs only, newest-first). Kept for compatibility.
  List<String> get history =>
      List.unmodifiable(_historyEntries.map((e) => e.url));
  String get currentUrl => activeTab?.url ?? '';
  bool get isPrivateMode => _privateMode;
  String get searchEngine => _searchEngine;
  String get homepageUrl => _homepageUrl;

  /// Only the exact value 'google' enables Google. Any other value
  /// (including null/empty/unknown) falls back to Navigwiz search.
  /// This guarantees long/difficult questions never redirect to Google
  /// unless the user explicitly picked Google in Settings.
  static String sanitizeEngine(String? engine) {
    final normalized = (engine ?? '').trim().toLowerCase();
    if (normalized == 'google') return 'google';
    return 'navigwiz';
  }

  bool get useGoogleSearch => _searchEngine == 'google';

  void setSearchEngine(String engine) {
    final sanitized = sanitizeEngine(engine);
    if (_searchEngine == sanitized) return;
    _searchEngine = sanitized;
    notifyListeners();
  }

  void setHomepageUrl(String value) {
    if (_homepageUrl == value) return;
    _homepageUrl = value;
    notifyListeners();
  }

  void setPrivateMode(bool value) {
    if (_privateMode == value) return;
    _privateMode = value;
    if (!value) {
      clearPrivateData();
    }
    notifyListeners();
  }

  /// Clears private-session traces (cookies/cache). Persistent browsing
  /// history is NOT wiped here — private mode never records, so there is
  /// nothing private in it; wiping it on exiting private mode would destroy
  /// the user's normal history (previous bug). Use clearHistory() for that.
  Future<void> clearPrivateData() async {
    if (!kIsWeb) {
      try {
        await WebViewCookieManager().clearCookies();
        await _webViewController?.clearCache();
      } catch (e) {
        debugPrint('Failed to clear private data: $e');
      }
    }
    notifyListeners();
  }

  bool get canGoBack {
    if (!kIsWeb && _webViewController != null) {
      final tab = activeTab;
      if (tab == null) return false;
      if (DomainHelper.isNavigwizDomain(tab.url)) return false;
      final backStack = _tabHistory[tab.id];
      return backStack != null && backStack.length > 1;
    }
    final tab = activeTab;
    if (tab == null) return false;
    final backStack = _tabHistory[tab.id];
    return backStack != null && backStack.length > 1;
  }

  bool get canGoForward {
    if (!kIsWeb && _webViewController != null) {
      final tab = activeTab;
      if (tab == null) return false;
      final forwardStack = _tabForwardHistory[tab.id];
      return forwardStack != null && forwardStack.isNotEmpty;
    }
    final tab = activeTab;
    if (tab == null) return false;
    final forwardStack = _tabForwardHistory[tab.id];
    return forwardStack != null && forwardStack.isNotEmpty;
  }

  Future<void> initialize({String? initialUrl}) async {
    try {
      await _loadBookmarks();
    } catch (e) {
      debugPrint('Bookmarks load failed: $e');
      _bookmarks = [];
    }
    try {
      await _loadHistory();
    } catch (e) {
      debugPrint('History load failed: $e');
      _historyEntries.clear();
    }
    try {
      _createNewTab(url: initialUrl);
    } catch (e) {
      debugPrint('Initial tab creation failed: $e');
      // Last-resort: guarantee at least one usable tab so the UI never
      // renders an empty browser.
      if (_tabs.isEmpty) {
        _tabs.add(BrowserTab(
          id: 'fallback-${DateTime.now().millisecondsSinceEpoch}',
          url: DomainHelper.getNavigwizDomain(),
          title: 'Navigwiz',
        ));
        _activeTabIndex = 0;
        notifyListeners();
      }
    }
  }

  Future<void> _loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _bookmarks = prefs.getStringList('bookmarks') ?? [];
    } catch (_) {
      _bookmarks = [];
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Preferred store: JSON entries with title + timestamp.
      String? raw;
      try {
        raw = prefs.getString(_historyV2Key);
      } catch (_) {
        raw = null;
      }
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw) as List;
          _historyEntries
            ..clear()
            ..addAll(decoded
                .whereType<Map>()
                .map((m) {
                  try {
                    return HistoryEntry.fromJson(
                        Map<String, dynamic>.from(m));
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<HistoryEntry>()
                .where((e) => e.url.isNotEmpty));
          return;
        } catch (_) {
          // Fall through to legacy migration.
        }
      }
      // One-time migration from the legacy URL-only list.
      List<String> legacy = [];
      try {
        legacy = prefs.getStringList(_legacyHistoryKey) ?? [];
      } catch (_) {}
      _historyEntries
        ..clear()
        ..addAll(legacy
            .where((u) => u.isNotEmpty)
            .map((u) => HistoryEntry.fromUrl(u)));
      if (legacy.isNotEmpty) {
        await _saveHistory();
      }
    } catch (_) {
      _historyEntries.clear();
    }
  }

  Future<void> _saveBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('bookmarks', _bookmarks);
    } catch (e) {
      debugPrint('Bookmarks save failed: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.setString(_historyV2Key,
            jsonEncode(_historyEntries.map((e) => e.toJson()).toList()));
        // Drop the legacy key once migrated so the two stores can't diverge.
        await prefs.remove(_legacyHistoryKey);
      } catch (_) {}
    } catch (_) {}
  }

  void createNewTab({String? url}) {
    // Millisecond timestamps collide when tabs are opened rapidly (double
    // new-tab taps produced duplicate ids and broke per-tab history).
    final tabId =
        '${DateTime.now().millisecondsSinceEpoch}-${_tabIdCounter++}';
    final defaultUrl = _homepageUrl.isNotEmpty
        ? _homepageUrl
        : DomainHelper.getNavigwizDomain();
    final tab = BrowserTab(
      id: tabId,
      url: url ?? defaultUrl,
      title: url == null ? 'Navigwiz' : DomainHelper.titleFromUrl(url),
    );
    _tabs.add(tab);
    _activeTabIndex = _tabs.length - 1;
    _tabHistory[tabId] = [url ?? defaultUrl];
    _tabForwardHistory[tabId] = [];
    notifyListeners();

    if (url != null && url != defaultUrl) {
      navigateToUrl(url);
    }
  }

  void _createNewTab({String? url}) {
    createNewTab(url: url);
  }

  void closeTab(String tabId) {
    if (_tabs.isEmpty) return;
    // Never strand the UI with zero tabs: resetting the last tab home is
    // safer than ignoring the close (which left users stuck on a dead tab).
    if (_tabs.length <= 1) {
      final only = _tabs.first;
      if (only.id == tabId) {
        _tabHistory[only.id] = [DomainHelper.getNavigwizDomain()];
        _tabForwardHistory[only.id] = [];
        updateTab(only.id,
            url: DomainHelper.getNavigwizDomain(),
            title: 'Navigwiz',
            isLoading: false,
            progress: 100);
      }
      return;
    }

    final index = _tabs.indexWhere((tab) => tab.id == tabId);
    if (index != -1) {
      _tabHistory.remove(tabId);
      _tabForwardHistory.remove(tabId);
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
      notifyListeners();
      unawaited(_loadActiveTabInWebView());
    }
  }

  void switchToTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      if (_activeTabIndex == index) return;
      _activeTabIndex = index;
      notifyListeners();
      unawaited(_loadActiveTabInWebView());
    }
  }

  void updateTab(String tabId,
      {String? title, String? url, bool? isLoading, int? progress}) {
    final index = _tabs.indexWhere((tab) => tab.id == tabId);
    if (index != -1) {
      final currentTab = _tabs[index];
      final displayTitle =
          DomainHelper.getDisplayTitle(url, title ?? currentTab.title);
      final nextTab = currentTab.copyWith(
        title: displayTitle,
        url: url,
        isLoading: isLoading,
        progress: progress,
      );
      if (nextTab.title == currentTab.title &&
          nextTab.url == currentTab.url &&
          nextTab.isLoading == currentTab.isLoading &&
          nextTab.progress == currentTab.progress) {
        return;
      }
      _tabs[index] = nextTab;

      if (url != null &&
          url != currentTab.url &&
          url != 'about:blank' &&
          !_privateMode) {
        _recordVisit(url, nextTab.title);
      }

      notifyListeners();
    }
  }

  /// Records a visit (newest-first). Internal Navigwiz home pages are skipped
  /// so history only shows real pages + searches, like other browsers.
  /// Private mode never records.
  Future<void> _recordVisit(String url, [String? title]) async {
    if (_privateMode) return;
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed == 'about:blank') return;
    if (trimmed == DomainHelper.getNavigwizDomain()) return;
    final displayTitle = (title == null || title.isEmpty)
        ? DomainHelper.titleFromUrl(trimmed)
        : title;
    _historyEntries.insert(
        0, HistoryEntry.fromUrl(trimmed, title: displayTitle));
    if (_historyEntries.length > maxHistoryEntries) {
      _historyEntries.removeRange(
          maxHistoryEntries, _historyEntries.length);
    }
    notifyListeners();
    await _saveHistory();
  }

  /// Public entry point for recording search queries and manual visits.
  Future<void> recordVisit(String url, {String? title}) =>
      _recordVisit(url, title);

  Future<void> addBookmark(String url) async {
    if (!_bookmarks.contains(url)) {
      _bookmarks.add(url);
      await _saveBookmarks();
      notifyListeners();
    }
  }

  Future<void> removeBookmark(String url) async {
    _bookmarks.remove(url);
    await _saveBookmarks();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _historyEntries.clear();
    await _saveHistory();
    notifyListeners();
  }

  /// Deletes a single history entry by id (falls back to matching url).
  Future<void> removeHistoryEntry(String id) async {
    final index =
        _historyEntries.indexWhere((e) => e.id == id || e.url == id);
    if (index != -1) {
      _historyEntries.removeAt(index);
      await _saveHistory();
      notifyListeners();
    }
  }

  /// Deletes history newer than [olderThan]. Null wipes everything.
  Future<void> clearHistoryBefore(DateTime? olderThan) async {
    if (olderThan == null) {
      await clearHistory();
      return;
    }
    _historyEntries
        .removeWhere((e) => e.visitedAt.isAfter(olderThan));
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearBookmarks() async {
    _bookmarks.clear();
    await _saveBookmarks();
    notifyListeners();
  }

  Future<void> clearAllBrowsingData() async {
    await clearPrivateData();
    await clearHistory();
    await clearBookmarks();
  }

  void setWebViewController(WebViewController controller) {
    _webViewController = controller;
    unawaited(_loadActiveTabInWebView());
    notifyListeners();
  }

  Future<void> _loadActiveTabInWebView() async {
    try {
      final url = activeTab?.url ?? '';
      if (_webViewController == null ||
          url.isEmpty ||
          DomainHelper.isNavigwizDomain(url)) {
        return;
      }
      final uri = _safeParseUri(url);
      if (uri == null) return;
      await _webViewController!.loadRequest(uri);
    } catch (e) {
      // A bad URL or a dead controller must never crash the browser.
      debugPrint('Load tab in WebView failed: $e');
    }
  }

  Future<void> navigateToUrl(String url) async {
    String normalizedUrl;
    try {
      normalizedUrl = _normalizeUrl(url);
    } catch (e) {
      debugPrint('Normalize URL failed for "$url": $e');
      normalizedUrl = DomainHelper.getNavigwizSearchUrl(url);
    }
    final tab = activeTab;
    final isInternalNavigwizUrl =
        DomainHelper.isNavigwizDomain(normalizedUrl);

    if (tab != null) {
      final previousUrl = tab.url;

      updateTab(
        tab.id,
        url: normalizedUrl,
        title: DomainHelper.titleFromUrl(normalizedUrl),
        isLoading: isInternalNavigwizUrl ? false : !kIsWeb,
        progress: isInternalNavigwizUrl || kIsWeb ? 100 : 10,
      );

      if (normalizedUrl != previousUrl) {
        _pushHistory(tab.id, normalizedUrl);
      }
    }

    if (isInternalNavigwizUrl) {
      return;
    }

    if (kIsWeb) {
      try {
        final uri = _safeParseUri(normalizedUrl);
        if (uri == null) {
          if (tab != null) {
            updateTab(tab.id, isLoading: false, progress: 100);
          }
          return;
        }
        final launched =
            await launchUrl(uri, webOnlyWindowName: '_blank').timeout(
          const Duration(seconds: 10),
          onTimeout: () => false,
        );
        if (!launched) {
          debugPrint('launchUrl refused for $normalizedUrl');
        }
      } catch (e) {
        debugPrint('External navigation failed for $normalizedUrl: $e');
      } finally {
        if (tab != null) {
          updateTab(tab.id, isLoading: false, progress: 100);
        }
      }
      return;
    }

    if (_webViewController != null) {
      try {
        final uri = _safeParseUri(normalizedUrl);
        if (uri == null) {
          updateTab(tab!.id, isLoading: false, progress: 100);
          return;
        }
        await _webViewController!.loadRequest(uri);
      } catch (e) {
        debugPrint('WebView load failed for $normalizedUrl: $e');
        if (tab != null) {
          updateTab(tab.id, isLoading: false, progress: 100);
        }
      }
    }
  }

  /// Lenient URI parse that never throws: returns null for garbage instead
  /// of crashing navigation. Internal Navigwiz pseudo-URLs
  /// ("Navigwiz Search: ...") intentionally return null — callers must treat
  /// them as internal and never pass them to Uri/ WebView.
  Uri? _safeParseUri(String url) {
    if (url.isEmpty || DomainHelper.isNavigwizDomain(url)) return null;
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme) return null;
      if (uri.scheme != 'http' &&
          uri.scheme != 'https' &&
          uri.scheme != 'file' &&
          uri.scheme != 'about' &&
          uri.scheme != 'data') {
        return null;
      }
      return uri;
    } catch (_) {
      return null;
    }
  }

  void _pushHistory(String tabId, String url) {
    _tabHistory[tabId] ??= [];
    _tabHistory[tabId]!.add(url);
    _tabForwardHistory[tabId] = [];
  }

  String _normalizeUrl(String url) {
    if (url.isEmpty) {
      return DomainHelper.getNavigwizDomain();
    }

    url = url.trim();

    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('file://') ||
        url.startsWith('about:') ||
        url.startsWith('data:') ||
        url.startsWith('chrome://') ||
        url.startsWith('edge://') ||
        url.startsWith('brave://')) {
      return url;
    }

    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}(:\d+)?$');
    if (ipRegex.hasMatch(url)) {
      return 'http://$url';
    }

    if (url.startsWith('localhost') ||
        url.startsWith('127.0.0.1') ||
        url.startsWith('192.168.') ||
        url.startsWith('10.') ||
        url.startsWith('172.16.')) {
      return 'http://$url';
    }

    final domainRegex = RegExp(
      r'^[a-zA-Z0-9][a-zA-Z0-9-]*(\.[a-zA-Z0-9][a-zA-Z0-9-]*)+(:\d+)?(/.*)?$',
    );
    if (domainRegex.hasMatch(url) && !url.contains(' ')) {
      return 'https://$url';
    }

    // Explicit opt-in only: Google is used solely when the user picked it
    // in Settings. Every other case — including long questions, questions
    // with punctuation, or any unrecognized engine value — stays inside
    // the Navigwiz frontend as custom Navigwiz Search results.
    if (_searchEngine == 'google') {
      final query = Uri.encodeComponent(url);
      return 'https://www.google.com/search?q=$query';
    }

    return DomainHelper.getNavigwizSearchUrl(url);
  }

  Future<void> goBack() async {
    if (!kIsWeb && _webViewController != null) {
      try {
        if (await _webViewController!
            .canGoBack()
            .timeout(const Duration(seconds: 5), onTimeout: () => false)) {
          await _webViewController!.goBack();
        }
      } catch (e) {
        debugPrint('WebView goBack failed: $e');
      }
      return;
    }

    final tab = activeTab;
    if (tab == null) return;

    final backStack = _tabHistory[tab.id];
    if (backStack == null || backStack.length < 2) return;

    final currentUrl = backStack.removeLast();
    _tabForwardHistory[tab.id] ??= [];
    _tabForwardHistory[tab.id]!.add(currentUrl);

    final previousUrl = backStack.last;
    if (DomainHelper.isNavigwizDomain(previousUrl)) {
      updateTab(tab.id, url: previousUrl, title: 'Navigwiz', isLoading: false, progress: 100);
    } else {
      updateTab(tab.id, url: 'about:blank', title: 'Navigwiz', isLoading: false, progress: 100);
    }
    notifyListeners();
  }

  Future<void> goForward() async {
    if (!kIsWeb && _webViewController != null) {
      try {
        if (await _webViewController!
            .canGoForward()
            .timeout(const Duration(seconds: 5), onTimeout: () => false)) {
          await _webViewController!.goForward();
        }
      } catch (e) {
        debugPrint('WebView goForward failed: $e');
      }
      return;
    }

    final tab = activeTab;
    if (tab == null) return;

    final forwardStack = _tabForwardHistory[tab.id];
    if (forwardStack == null || forwardStack.isEmpty) return;

    final nextUrl = forwardStack.removeLast();
    _tabHistory[tab.id] ??= [];
    _tabHistory[tab.id]!.add(nextUrl);

    if (DomainHelper.isNavigwizDomain(nextUrl)) {
      updateTab(tab.id, url: nextUrl, title: 'Navigwiz', isLoading: false, progress: 100);
    } else {
      updateTab(tab.id, url: nextUrl, isLoading: false, progress: 100);
    }
    notifyListeners();
  }

  Future<void> reload() async {
    try {
      if (DomainHelper.isNavigwizDomain(activeTab?.url)) {
        _reloadNonce++;
        notifyListeners();
        return;
      }

      if (!kIsWeb && _webViewController != null) {
        try {
          await _webViewController!
              .reload()
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('WebView reload failed: $e');
        }
        return;
      }

      final tab = activeTab;
      if (tab == null) return;

      final url = tab.url;
      if (url.isNotEmpty && !DomainHelper.isNavigwizDomain(url)) {
        try {
          final uri = _safeParseUri(url);
          if (uri == null) return;
          await launchUrl(uri, webOnlyWindowName: '_blank')
              .timeout(const Duration(seconds: 10), onTimeout: () => false);
        } catch (e) {
          debugPrint('Reload launch failed for $url: $e');
        }
      }
    } catch (e) {
      debugPrint('Reload failed: $e');
    }
  }
}
