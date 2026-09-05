import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/browser_tab.dart';
import '../utils/domain_helper.dart';

class BrowserService extends ChangeNotifier {
  final List<BrowserTab> _tabs = [];
  int _activeTabIndex = 0;
  int _reloadNonce = 0;
  WebViewController? _webViewController;
  List<String> _bookmarks = [];
  List<String> _history = [];
  bool _privateMode = false;
  String _searchEngine = 'navigwiz';
  String _homepageUrl = '';

  // Per-tab navigation history for web platform
  final Map<String, List<String>> _tabHistory = {};
  final Map<String, List<String>> _tabForwardHistory = {};

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  int get activeTabIndex => _activeTabIndex;
  int get reloadNonce => _reloadNonce;
  BrowserTab? get activeTab => _tabs.isNotEmpty ? _tabs[_activeTabIndex] : null;
  WebViewController? get webViewController => _webViewController;
  List<String> get bookmarks => List.unmodifiable(_bookmarks);
  List<String> get history => List.unmodifiable(_history);
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

  Future<void> clearPrivateData() async {
    if (!kIsWeb) {
      try {
        await WebViewCookieManager().clearCookies();
        await _webViewController?.clearCache();
      } catch (e) {
        debugPrint('Failed to clear private data: $e');
      }
    }
    _history.clear();
    if (!kIsWeb) {
      await _saveHistory();
    }
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
    await _loadBookmarks();
    await _loadHistory();
    _createNewTab(url: initialUrl);
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    _bookmarks = prefs.getStringList('bookmarks') ?? [];
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _history = prefs.getStringList('history') ?? [];
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bookmarks', _bookmarks);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', _history);
  }

  void createNewTab({String? url}) {
    final tabId = DateTime.now().millisecondsSinceEpoch.toString();
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
    if (_tabs.length <= 1) return;

    final index = _tabs.indexWhere((tab) => tab.id == tabId);
    if (index != -1) {
      _tabHistory.remove(tabId);
      _tabForwardHistory.remove(tabId);
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
      notifyListeners();
    }
  }

  void switchToTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _activeTabIndex = index;
      notifyListeners();
      _loadActiveTabInWebView();
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
        _addToHistory(url);
      }

      notifyListeners();
    }
  }

  Future<void> _addToHistory(String url) async {
    if (_privateMode) return;
    if (!_history.contains(url)) {
      _history.insert(0, url);
      if (_history.length > 100) {
        _history.removeLast();
      }
      await _saveHistory();
    }
  }

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
    _history.clear();
    if (!kIsWeb) {
      await _saveHistory();
    }
    notifyListeners();
  }

  Future<void> clearBookmarks() async {
    _bookmarks.clear();
    await _saveBookmarks();
    notifyListeners();
  }

  Future<void> clearAllBrowsingData() async {
    await clearPrivateData();
    await clearBookmarks();
  }

  void setWebViewController(WebViewController controller) {
    _webViewController = controller;
    _loadActiveTabInWebView();
    notifyListeners();
  }

  Future<void> _loadActiveTabInWebView() async {
    final url = activeTab?.url ?? '';
    if (_webViewController == null ||
        url.isEmpty ||
        DomainHelper.isNavigwizDomain(url)) {
      return;
    }
    await _webViewController!.loadRequest(Uri.parse(url));
  }

  Future<void> navigateToUrl(String url) async {
    final normalizedUrl = _normalizeUrl(url);
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
      final uri = Uri.parse(normalizedUrl);
      await launchUrl(uri, webOnlyWindowName: '_blank');
      if (tab != null) {
        updateTab(tab.id, isLoading: false, progress: 100);
      }
      return;
    }

    if (_webViewController != null) {
      await _webViewController!.loadRequest(Uri.parse(normalizedUrl));
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
      if (await _webViewController!.canGoBack()) {
        await _webViewController!.goBack();
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
      if (await _webViewController!.canGoForward()) {
        await _webViewController!.goForward();
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
    if (DomainHelper.isNavigwizDomain(activeTab?.url)) {
      _reloadNonce++;
      notifyListeners();
      return;
    }

    if (!kIsWeb && _webViewController != null) {
      await _webViewController!.reload();
      return;
    }

    final tab = activeTab;
    if (tab == null) return;

    final url = tab.url;
    if (url.isNotEmpty && !DomainHelper.isNavigwizDomain(url)) {
      final uri = Uri.parse(url);
      await launchUrl(uri, webOnlyWindowName: '_blank');
    }
  }
}
