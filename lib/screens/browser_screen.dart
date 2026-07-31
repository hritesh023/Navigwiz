import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/browser_service.dart';
import '../services/theme_service.dart';
import '../utils/domain_helper.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/memory_provider.dart';
import '../widgets/address_bar.dart';
import '../widgets/browser_tab_bar.dart';
import '../widgets/customization_panel.dart';
import '../widgets/ai_assistant_side_panel.dart';
import '../widgets/saturn_logo.dart';
import '../widgets/acronous_logo.dart';
import '../widgets/navigwiz_search_results.dart';
import 'acronous_chat_page.dart';
import 'settings_screen.dart';
import 'workspace_screen.dart';
import 'research_screen.dart';

class BrowserScreen extends StatefulWidget {
  final bool enableEmbeddedWebView;

  const BrowserScreen({
    super.key,
    this.enableEmbeddedWebView = true,
  });

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  bool _showCustomizationPanel = false;
  bool _showAiAssistantPanel = false;
  bool _showWorkspacePanel = false;
  WebViewController? _webViewController;
  final TextEditingController _homeSearchController = TextEditingController();

  static const String _adBlockScript = r'''
(() => {
  const selectors = [
    'ins.adsbygoogle',
    '.adsbygoogle',
    '[id^="google_ads_"]',
    '[id*="ad-slot"]',
    '.ad-banner',
    '.advertisement',
    '.advert',
    '.ads',
    '[aria-label="Ads"]',
    '[aria-label="Advertisement"]',
    '[class*="ad-container"]',
    '[class*="ad-widget"]',
    '[data-ad-slot]',
    '[data-ad-client]',
  ];
  const block = () => {
    try {
      for (const s of selectors) {
        document.querySelectorAll(s).forEach(el => el.remove());
      }
    } catch (e) {}
  };
  const start = () => {
    block();
    if (document.body) {
      new MutationObserver(block).observe(document.body, {
        childList: true,
        subtree: true,
      });
    }
  };
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})();
''';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && widget.enableEmbeddedWebView) {
      _initializeBrowser();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final browserService =
            Provider.of<BrowserService>(context, listen: false);
        if (browserService.tabs.isEmpty) {
          browserService.createNewTab();
        }
      });
    }
  }

  @override
  void dispose() {
    _homeSearchController.dispose();
    _webViewController = null;
    super.dispose();
  }

  void _initializeBrowser() {
    _createWebViewController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final browserService =
          Provider.of<BrowserService>(context, listen: false);
      if (_webViewController != null) {
        browserService.setWebViewController(_webViewController!);
      }
      if (browserService.tabs.isEmpty) {
        browserService.createNewTab();
      }
    });
  }

  void _createWebViewController() {
    final adBlockEnabled =
        Provider.of<SettingsProvider>(context, listen: false).adBlockEnabled;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            final browserService =
                Provider.of<BrowserService>(context, listen: false);
            final activeTab = browserService.activeTab;
            if (activeTab != null &&
                (progress == 100 ||
                    progress < activeTab.progress ||
                    progress - activeTab.progress >= 8)) {
              browserService.updateTab(
                activeTab.id,
                progress: progress,
                isLoading: progress < 100,
              );
            }
          },
          onPageStarted: (String url) {
            final browserService =
                Provider.of<BrowserService>(context, listen: false);
            if (browserService.activeTab != null) {
              browserService.updateTab(
                browserService.activeTab!.id,
                url: url,
                isLoading: true,
              );
            }
          },
          onPageFinished: (String url) {
            final browserService =
                Provider.of<BrowserService>(context, listen: false);
            if (browserService.activeTab != null) {
              browserService.updateTab(
                browserService.activeTab!.id,
                url: url,
                isLoading: false,
                progress: 100,
              );
            }
            if (adBlockEnabled) {
              _webViewController?.runJavaScript(_adBlockScript);
            }
            if (!browserService.isPrivateMode) {
              Provider.of<MemoryProvider>(context, listen: false).remember(
                type: 'visit',
                content: 'Visited: $url',
                url: url,
              );
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
                'WebView error: ${error.description} (code: ${error.errorCode})');
          },
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Consumer<ThemeService>(
            builder: (_, themeService, __) => _buildTitleBar(themeService),
          ),
          Consumer<BrowserService>(
            builder: (_, browserService, __) => BrowserTabBar(
              tabs: browserService.tabs,
              activeTabIndex: browserService.activeTabIndex,
              isPrivate: browserService.isPrivateMode,
              onTabSelected: (index) => browserService.switchToTab(index),
              onTabClosed: (tabId) => browserService.closeTab(tabId),
              onNewTab: () => browserService.createNewTab(),
            ),
          ),
          Consumer<BrowserService>(
            builder: (_, browserService, __) => AddressBar(
              url: browserService.activeTab?.url ?? '',
              isLoading: browserService.activeTab?.isLoading ?? false,
              progress: browserService.activeTab?.progress ?? 0,
              isPrivate: browserService.isPrivateMode,
              onUrlSubmitted: (url) => browserService.navigateToUrl(url),
              onBackPressed: () => browserService.goBack(),
              onForwardPressed: () => browserService.goForward(),
              onReloadPressed: () => browserService.reload(),
              canGoBack: browserService.canGoBack,
              canGoForward: browserService.canGoForward,
              trailingActions: <Widget>[
                _buildToolbarButton(
                  icon: Icons.travel_explore,
                  tooltip: 'Research Mode',
                  isActive: false,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ResearchScreen()),
                  ),
                ),
                const SizedBox(width: 4),
                _buildToolbarButton(
                  icon: Icons.workspaces_outline,
                  tooltip: 'Workspaces',
                  isActive: _showWorkspacePanel,
                  onPressed: () => setState(
                      () => _showWorkspacePanel = !_showWorkspacePanel),
                ),
                const SizedBox(width: 4),
                _buildAcronousButton(),
                const SizedBox(width: 4),
                _buildToolbarButton(
                  icon: _showCustomizationPanel ? Icons.close : Icons.palette,
                  tooltip: 'Customize',
                  isActive: _showCustomizationPanel,
                  onPressed: () => setState(
                      () => _showCustomizationPanel = !_showCustomizationPanel),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<BrowserService>(
              builder: (_, browserService, __) => Stack(
                children: [
                  browserService.activeTab != null
                      ? _buildWebView(browserService)
                      : _buildEmptyState(),
                  if (_showAiAssistantPanel)
                    Positioned(
                      right: _showCustomizationPanel
                          ? 350
                          : _showWorkspacePanel
                              ? 320
                              : 0,
                      top: 0,
                      bottom: 0,
                      width: 400,
                      child: AiAssistantSidePanel(
                        onClose: () =>
                            setState(() => _showAiAssistantPanel = false),
                        onExpand: () async {
                          setState(() => _showAiAssistantPanel = false);
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                                builder: (_) => const AcronousChatPage()),
                          );
                          if (result == true && mounted) {
                            setState(() => _showAiAssistantPanel = true);
                          }
                        },
                      ),
                    ),
                  if (_showWorkspacePanel)
                    Positioned(
                      right: _showCustomizationPanel ? 350 : 0,
                      top: 0,
                      bottom: 0,
                      width: 320,
                      child: _buildQuickWorkspacePanel(),
                    ),
                  if (_showCustomizationPanel)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 350,
                      child: CustomizationPanel(
                        onClose: () =>
                            setState(() => _showCustomizationPanel = false),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView(BrowserService browserService) {
    final activeUrl = browserService.activeTab?.url;
    if (DomainHelper.isNavigwizSearchUrl(activeUrl)) {
      final query = DomainHelper.searchQueryFromUrl(activeUrl);
      return query.isEmpty
          ? _buildEmptyState()
          : NavigwizSearchResults(
              key: ValueKey('$activeUrl-${browserService.reloadNonce}'),
              query: query,
            );
    }

    if (DomainHelper.isNavigwizDomain(activeUrl)) {
      return _buildEmptyState();
    }

    if (_webViewController == null) {
      return _buildEmptyState();
    }
    return WebViewWidget(controller: _webViewController!);
  }

  Widget _buildEmptyState() {
    final themeService = Provider.of<ThemeService>(context);
    final isPrivate =
        Provider.of<BrowserService>(context).isPrivateMode;
    final hasImageBackground = themeService.backgroundImageBytes != null &&
        !themeService.hasVideoBackground;

    final content = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isPrivate) ...[
              _buildPrivateModeNotice(),
              const SizedBox(height: 22),
            ],
            if (themeService.hasVideoBackground) ...[
              _buildLiveWallpaperHint(themeService),
              const SizedBox(height: 22),
            ],
            const SaturnLogo(size: 100, showGlow: true),
            const SizedBox(height: 20),
            Text(
              'Navigwiz',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isSignedIn && auth.userName != null && auth.userName!.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Welcome, ${auth.userName}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  );
                }
                return Text(
                  'AI-Powered Internet Operating System',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .shadow
                          .withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _homeSearchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _submitHomeSearch,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'What do you want to do?',
                          hintStyle: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Search',
                      onPressed: () =>
                          _submitHomeSearch(_homeSearchController.text),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildQuickAccessButtons(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            themeService.primaryColor.withValues(alpha: 0.18),
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).colorScheme.surfaceContainerLowest,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImageBackground)
            Image.memory(
              themeService.backgroundImageBytes!,
              fit: BoxFit.cover,
              opacity: isPrivate
                  ? const AlwaysStoppedAnimation(0.35)
                  : const AlwaysStoppedAnimation(0.55),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          content,
        ],
      ),
    );
  }

  Widget _buildPrivateModeNotice() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF37474F).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_off, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "You've gone incognito",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tabs, history, cookies and site data from this window are not saved.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessButtons() {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildQuickAction(Icons.travel_explore, 'Research', () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ResearchScreen()));
        }, theme),
        _buildQuickAction(Icons.workspaces_outline, 'Workspaces', () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const WorkspaceScreen()));
        }, theme),
        _buildQuickAction(Icons.auto_awesome, 'AI Chat', () {
          setState(() => _showAiAssistantPanel = !_showAiAssistantPanel);
        }, theme),
      ],
    );
  }

  Widget _buildQuickAction(
      IconData icon, String label, VoidCallback onTap, ThemeData theme) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
      label: Text(label,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  Widget _buildLiveWallpaperHint(ThemeService themeService) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(seconds: 5),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Container(
          width: 220,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                themeService.primaryColor.withValues(alpha: 0.2 + value * 0.4),
                Theme.of(context).colorScheme.secondary,
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitHomeSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    Provider.of<BrowserService>(context, listen: false).navigateToUrl(query);
  }

  Future<void> _togglePrivateMode() async {
    final browserService =
        Provider.of<BrowserService>(context, listen: false);
    final enabling = !browserService.isPrivateMode;
    browserService.setPrivateMode(enabling);
    if (!kIsWeb && widget.enableEmbeddedWebView && _webViewController != null) {
      _createWebViewController();
      Provider.of<BrowserService>(context, listen: false)
          .setWebViewController(_webViewController!);
    }
  }

  Widget _buildTitleBar(ThemeService themeService) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const SaturnLogo(size: 16, showGlow: true),
          const SizedBox(width: 8),
          Text(
            'Navigwiz',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          _buildTitleButton(Icons.home_outlined, 'Home', () {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const BrowserScreen()));
          }),
          const SizedBox(width: 4),
          _buildTitleButton(Icons.travel_explore, 'Research', () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ResearchScreen()));
          }),
          const SizedBox(width: 4),
          _buildTitleButton(Icons.workspaces_outline, 'Workspaces', () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WorkspaceScreen()));
          }),
          const SizedBox(width: 4),
          Consumer<BrowserService>(
            builder: (context, browserService, _) => _buildPrivateModeButton(
              isActive: browserService.isPrivateMode,
              onTap: _togglePrivateMode,
            ),
          ),
          const SizedBox(width: 4),
          _buildTitleButton(Icons.settings_outlined, 'Settings', () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
          const Spacer(),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (!auth.isSignedIn) return const SizedBox.shrink();
              return _buildTitleButton(Icons.logout, 'Sign Out', () {
                auth.redirectToLogout();
              });
            },
          ),
          if (!kIsWeb) ...[
            _buildWindowControl(Icons.remove, Colors.grey[600]!),
            _buildWindowControl(Icons.crop_square, Colors.grey[600]!),
            _buildWindowControl(Icons.close, Colors.red[400]!),
          ],
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTitleButton(IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivateModeButton({
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final tint = isActive
        ? const Color(0xFF37474F)
        : theme.colorScheme.surfaceContainer;
    final fg = isActive
        ? Colors.white
        : theme.colorScheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: isActive ? 'Exit Incognito' : 'New Incognito Window',
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isActive ? Icons.visibility_off : Icons.visibility,
                    size: 12, color: fg),
                const SizedBox(width: 4),
                Text(
                  isActive ? 'Incognito' : 'Private',
                  style: TextStyle(fontSize: 11, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWindowControl(IconData icon, Color color) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 8, color: Colors.white),
    );
  }

  Widget _buildAcronousButton() {
    return Tooltip(
      message: 'Acronous AI',
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _showAiAssistantPanel
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: () =>
              setState(() => _showAiAssistantPanel = !_showAiAssistantPanel),
          icon: const AcronousLogo(size: 16, showGlow: true),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: 16,
            color: isActive
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildQuickWorkspacePanel() {
    final theme = Theme.of(context);
    final workspaceProvider = context.watch<WorkspaceProvider>();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Text('Workspaces',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: theme.colorScheme.onSurface)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _showWorkspacePanel = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: workspaceProvider.workspaces.isEmpty
                ? Center(
                    child: Text('No workspaces',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: workspaceProvider.workspaces.length,
                    itemBuilder: (ctx, i) {
                      final ws = workspaceProvider.workspaces[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.folder_outlined,
                            size: 18, color: theme.colorScheme.primary),
                        title: Text(ws.name,
                            style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface)),
                        subtitle: Text('${ws.items.length} items',
                            style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant)),
                        onTap: () {
                          workspaceProvider.setActiveWorkspace(ws.id);
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const WorkspaceScreen()));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
