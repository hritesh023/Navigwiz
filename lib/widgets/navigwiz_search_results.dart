import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ai_service.dart';
import '../services/browser_service.dart';
import 'saturn_logo.dart';

String _formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  try {
    final dt = DateTime.parse(dateStr);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  } catch (_) {
    return dateStr;
  }
}

class NavigwizSearchResults extends StatefulWidget {
  final String query;

  const NavigwizSearchResults({super.key, required this.query});

  @override
  State<NavigwizSearchResults> createState() => _NavigwizSearchResultsState();
}

class _NavigwizSearchResultsState extends State<NavigwizSearchResults> {
  static const List<_SearchCategory> _categories = [
    _SearchCategory(id: 'all', label: 'All', icon: Icons.search),
    _SearchCategory(id: 'images', label: 'Images', icon: Icons.image),
    _SearchCategory(id: 'videos', label: 'Videos', icon: Icons.videocam),
    _SearchCategory(id: 'news', label: 'News', icon: Icons.article),
    _SearchCategory(id: 'books', label: 'Books', icon: Icons.menu_book),
  ];

  List<SearchResult> _results = [];
  List<SearchResult> _imageResults = [];
  List<SearchResult> _newsResults = [];
  List<SearchResult> _videoResults = [];
  List<SearchResult> _bookResults = [];
  List<Infobox> _infoboxes = [];
  String _aiAnswer = '';
  int? _resultCount;
  String _searchTime = '';
  bool _isLoading = true;
  bool _hasError = false;
  String _currentCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  void didUpdateWidget(covariant NavigwizSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _currentCategory = 'all';
      _loadResults();
    }
  }

  Future<void> _loadResults({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _results = [];
      _imageResults = [];
      _newsResults = [];
      _videoResults = [];
      _bookResults = [];
      _infoboxes = [];
      _aiAnswer = '';
      _resultCount = null;
      _searchTime = '';
    });

    try {
      final aiService = Provider.of<AIService>(context, listen: false);

      final response = await aiService
          .searchWithOverview(
            widget.query,
            forceRefresh: forceRefresh,
            category: _currentCategory,
            waitForAi: false,
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() {
        _results = response.results;
        _imageResults = response.imageResults;
        _newsResults = response.newsResults;
        _videoResults = response.videoResults;
        _bookResults = response.bookResults;
        _infoboxes = response.infoboxes;
        _resultCount = response.resultCount;
        _searchTime = response.searchTime;
        _isLoading = false;
        _hasError = false;
      });

      if (_currentCategory == 'all' || _currentCategory == 'images') {
        _loadAiAnswer(aiService);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = _results.isEmpty;
        });
        if (_results.isEmpty) {
          try {
            final aiService = Provider.of<AIService>(context, listen: false);
            final fallback = await aiService.searchWeb(widget.query, forceRefresh: true);
            if (mounted && fallback.isNotEmpty) {
              setState(() {
                _results = fallback;
                _hasError = false;
              });
            }
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _loadAiAnswer(AIService aiService) async {
    try {
      final answer = await aiService
          .getAiAnswerForSearch(_results, widget.query)
          .timeout(const Duration(seconds: 20));
      if (mounted && answer.isNotEmpty) {
        setState(() => _aiAnswer = answer);
      }
    } catch (_) {}
  }

  void _refresh() => _loadResults(forceRefresh: true);

  void _switchCategory(String category) {
    if (category == _currentCategory) return;
    setState(() => _currentCategory = category);
    _loadResults(forceRefresh: true);
  }

  void _openUrl(String url) {
    Provider.of<BrowserService>(context, listen: false).navigateToUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: _isLoading
          ? _buildSkeletonLoading(theme)
          : _hasError
              ? _buildError()
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildStatsBar()),
                    SliverToBoxAdapter(child: _buildCategoryTabs()),
                    if (_aiAnswer.isNotEmpty && _currentCategory == 'all')
                      SliverToBoxAdapter(child: _buildAIOverview()),
                    if (_infoboxes.isNotEmpty && _currentCategory == 'all')
                      SliverToBoxAdapter(child: _buildKnowledgePanel()),
                    if (_imageResults.isNotEmpty && _currentCategory == 'all')
                      SliverToBoxAdapter(child: _buildImageStrip()),
                    if (_videoResults.isNotEmpty && _currentCategory == 'all')
                      SliverToBoxAdapter(child: _buildVideoStrip()),
                    if (_newsResults.isNotEmpty && _currentCategory == 'all')
                      SliverToBoxAdapter(child: _buildNewsSection()),
                    if (_results.isEmpty && _currentCategory != 'all')
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _SearchMessage(
                          icon: _categoryIcon(_currentCategory),
                          title: 'No ${_categoryLabel(_currentCategory)} found',
                          message: 'Try a different search query or category.',
                          actionLabel: 'Refresh',
                          onAction: _refresh,
                        ),
                      )
                    else if (_results.isEmpty && _currentCategory == 'all')
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _SearchMessage(
                          icon: Icons.search_off,
                          title: 'No results found',
                          message: 'Try a different search query.',
                          actionLabel: 'Refresh',
                          onAction: _refresh,
                        ),
                      )
                    else if (_currentCategory == 'images')
                      _buildImageGrid()
                    else if (_currentCategory == 'videos')
                      _buildVideoGrid()
                    else if (_currentCategory == 'news')
                      _buildNewsList()
                    else if (_currentCategory == 'books')
                      _buildBooksList()
                    else ...[
                      if (_results.isNotEmpty && _currentCategory == 'all')
                        SliverToBoxAdapter(child: _buildExploreMore()),
                      const SliverPadding(
                        padding: EdgeInsets.only(bottom: 28),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _buildSkeletonLoading(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      children: [
        _SkeletonBlock(height: 46, width: double.infinity, borderRadius: 12),
        const SizedBox(height: 12),
        _SkeletonBlock(height: 14, width: 140, borderRadius: 6),
        const SizedBox(height: 16),
        _SkeletonBlock(height: 36, width: double.infinity, borderRadius: 8),
        const SizedBox(height: 16),
        ...List.generate(6, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SkeletonBlock(height: 80, width: double.infinity, borderRadius: 12),
        )),
      ],
    );
  }

  IconData _categoryIcon(String category) {
    for (final c in _categories) {
      if (c.id == category) return c.icon;
    }
    return Icons.search;
  }

  String _categoryLabel(String category) {
    for (final c in _categories) {
      if (c.id == category) return c.label;
    }
    return category;
  }

  String _getDomain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  Widget _buildImageGrid() {
    final results = _imageResults.isNotEmpty ? _imageResults : _results;
    if (results.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _SearchMessage(
          icon: Icons.image, title: 'No images found',
          message: 'Try a different search query.', actionLabel: 'Refresh', onAction: _refresh,
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.3,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _ImageResultTile(result: results[index]),
          childCount: results.length,
        ),
      ),
    );
  }

  Widget _buildVideoGrid() {
    final videos = _videoResults.isNotEmpty ? _videoResults : _results;
    if (videos.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _SearchMessage(
          icon: Icons.videocam, title: 'No videos found',
          message: 'Try a different search query.', actionLabel: 'Refresh', onAction: _refresh,
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 16, childAspectRatio: 1.1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _VideoGridTile(result: videos[index]),
          childCount: videos.length,
        ),
      ),
    );
  }

  Widget _buildNewsList() {
    final news = _newsResults.isNotEmpty ? _newsResults : _results;
    if (news.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _SearchMessage(
          icon: Icons.article, title: 'No news found',
          message: 'Try a different search query.', actionLabel: 'Refresh', onAction: _refresh,
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildNewsItem(news[index], index == news.length - 1, index),
          childCount: news.length,
        ),
      ),
    );
  }

  Widget _buildBooksList() {
    final theme = Theme.of(context);
    final books = _bookResults.isNotEmpty ? _bookResults : _results;
    if (books.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _SearchMessage(
          icon: Icons.menu_book, title: 'No books found',
          message: 'Try a different search query.', actionLabel: 'Refresh', onAction: _refresh,
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildBookCard(books[index], theme),
          childCount: books.length,
        ),
      ),
    );
  }

  Widget _buildBookCard(SearchResult result, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
        child: InkWell(
          onTap: () => _openUrl(result.url),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56, height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.menu_book, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.2), maxLines: 3, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text(result.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.3)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.language, size: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Flexible(child: Text(_getDomain(result.url), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return _SearchHeader(
      query: widget.query, isLoading: _isLoading, onRefresh: _refresh, resultCount: _results.length,
    );
  }

  Widget _buildStatsBar() {
    if (_searchTime.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
          child: Row(children: [
            Icon(Icons.travel_explore, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text('${_formatNumber(_resultCount ?? _results.length)} sources found',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Widget _buildCategoryTabs() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Row(
            children: _categories.map((cat) {
              final isActive = cat.id == _currentCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: InkWell(
                  onTap: () => _switchCategory(cat.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? theme.colorScheme.primaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(cat.icon, size: 16, color: isActive ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(cat.label, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal, color: isActive ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildAIOverview() {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(widget.query, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.15)),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Text('Answer', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                      const Spacer(),
                      Text('Navigwiz AI', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45), fontWeight: FontWeight.w500)),
                    ]),
                    const SizedBox(height: 20),
                    Text(_aiAnswer, style: theme.textTheme.bodyLarge?.copyWith(height: 1.65, color: theme.colorScheme.onSurface, fontSize: 15)),
                    if (_results.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _results.take(6).map((r) {
                          final srcDomain = _getDomain(r.url);
                          return InkWell(
                            onTap: () => _openUrl(r.url),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  width: 14, height: 14,
                                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(3)),
                                  child: Icon(Icons.language, size: 10, color: theme.colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(width: 6),
                                Text(srcDomain, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w500, fontSize: 11)),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKnowledgePanel() {
    final infobox = _infoboxes.first;
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(infobox.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.2))),
                        if (infobox.url != null && infobox.url!.isNotEmpty)
                          InkWell(
                            onTap: () => _openUrl(infobox.url!),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(_getDomain(infobox.url!), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600, fontSize: 11)),
                                const SizedBox(width: 4),
                                Icon(Icons.open_in_new, size: 13, color: theme.colorScheme.onSecondaryContainer),
                              ]),
                            ),
                          ),
                      ],
                    ),
                    if (infobox.content.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(infobox.content, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5), maxLines: 6, overflow: TextOverflow.ellipsis),
                    ],
                    if (infobox.attributes.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: infobox.attributes.take(6).map((attr) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                SizedBox(width: 110, child: Text(attr.label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 11))),
                                Expanded(child: Text(attr.value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
                              ]),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(Icons.info_outline, size: 13, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Text('Auto-generated based on web sources. May contain inaccuracies.',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageStrip() {
    final theme = Theme.of(context);
    final images = _imageResults.take(12).toList();
    if (images.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.image, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Images', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
                const Spacer(),
                if (_results.isNotEmpty)
                  InkWell(
                    onTap: () => _switchCategory('images'),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('More', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 3),
                        Icon(Icons.arrow_forward, size: 13, color: theme.colorScheme.primary),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final img = images[index];
                    return _ImageThumbnailTile(
                      width: 180, height: 130,
                      imageUrl: img.imageUrl,
                      label: img.title,
                      onTap: () => _openUrl(img.url),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoStrip() {
    final theme = Theme.of(context);
    final videos = _videoResults.take(8).toList();
    if (videos.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.videocam, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Videos', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
                const Spacer(),
                if (_results.isNotEmpty)
                  InkWell(
                    onTap: () => _switchCategory('videos'),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('More', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 3),
                        Icon(Icons.arrow_forward, size: 13, color: theme.colorScheme.primary),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: videos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return SizedBox(
                      width: 200,
                      child: GestureDetector(
                        onTap: () => _openUrl(video.url),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _VideoThumbnail(url: video.imageUrl),
                            const SizedBox(height: 6),
                            Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, height: 1.2)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsSection() {
    final theme = Theme.of(context);
    final newsItems = _newsResults.take(6).toList();
    if (newsItems.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.newspaper, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('News', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4)),
                  child: Text(_newsResults.length.toString(), style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: theme.colorScheme.onPrimaryContainer)),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.24)),
                ),
                child: Column(
                  children: List.generate(newsItems.length, (index) {
                    final item = newsItems[index];
                    final isLast = index == newsItems.length - 1;
                    return _buildNewsItem(item, isLast, index);
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsItem(SearchResult item, bool isLast, int index) {
    final theme = Theme.of(context);
    final domain = _getDomain(item.url);
    final dateStr = item.publishedDate;

    return Column(
      children: [
        InkWell(
          onTap: () => _openUrl(item.url),
          borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(12)) : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Row(children: [
                        Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(3)),
                          child: Icon(Icons.language, size: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 5),
                        Text(domain, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
                        if (dateStr != null && dateStr.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.circle, size: 3, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(width: 6),
                          Text(_formatDate(dateStr), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 11)),
                        ],
                      ]),
                      const SizedBox(height: 5),
                      Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 14, endIndent: 14, color: theme.dividerColor.withValues(alpha: 0.15)),
      ],
    );
  }

  Widget _buildExploreMore() {
    final theme = Theme.of(context);
    if (_results.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.explore, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Explore More', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
              ]),
              const SizedBox(height: 14),
              ..._results.take(20).map((result) => _buildResourceCard(result, theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceCard(SearchResult result, ThemeData theme) {
    final domain = _getDomain(result.url);
    final dateStr = result.publishedDate;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
        child: InkWell(
          onTap: () => _openUrl(result.url),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.language, size: 22, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(domain, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontWeight: FontWeight.w500, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (dateStr != null && dateStr.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.circle, size: 3, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                          const SizedBox(width: 6),
                          Text(_formatDate(dateStr), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 11)),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(result.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 15, height: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(result.description, maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text('Search could not load', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Something went wrong. Please try again.', textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _SearchCategory {
  final String id;
  final String label;
  final IconData icon;
  const _SearchCategory({required this.id, required this.label, required this.icon});
}

class _SearchHeader extends StatefulWidget {
  final String query;
  final bool isLoading;
  final VoidCallback onRefresh;
  final int resultCount;

  const _SearchHeader({
    required this.query, required this.isLoading, required this.onRefresh, this.resultCount = 0,
  });

  @override
  State<_SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<_SearchHeader> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _SearchHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _controller.text = widget.query;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    Provider.of<BrowserService>(context, listen: false).navigateToUrl(query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const SaturnLogo(size: 24, showGlow: true),
                const SizedBox(width: 8),
                Text('Navigwiz', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
              ]),
              const SizedBox(height: 10),
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.28)),
                ),
                child: Row(children: [
                  const SizedBox(width: 14),
                  Icon(Icons.search, size: 20, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _submitSearch(),
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                    ),
                  ),
                  IconButton(tooltip: 'Search', onPressed: _submitSearch, icon: const Icon(Icons.arrow_forward)),
                  IconButton(tooltip: 'Refresh results', onPressed: widget.isLoading ? null : widget.onRefresh, icon: const Icon(Icons.refresh)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageResultTile extends StatelessWidget {
  final SearchResult result;

  const _ImageResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: GestureDetector(
        onTap: () => Provider.of<BrowserService>(context, listen: false).navigateToUrl(result.url),
        child: result.imageUrl != null && result.imageUrl!.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    result.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return _buildPlaceholder(theme);
                    },
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                        ),
                      ),
                      child: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              )
            : _buildPlaceholder(theme),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image, size: 32, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _ImageThumbnailTile extends StatelessWidget {
  final double width;
  final double height;
  final String? imageUrl;
  final String label;
  final VoidCallback onTap;

  const _ImageThumbnailTile({
    required this.width, required this.height,
    this.imageUrl, required this.label, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width, height: height,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return _buildPlaceholder(theme);
                      },
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter, end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                          ),
                        ),
                        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                )
              : Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image, size: 28, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                        if (label.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image, size: 32, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _VideoGridTile extends StatelessWidget {
  final SearchResult result;

  const _VideoGridTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final browserService = Provider.of<BrowserService>(context, listen: false);

    return GestureDetector(
      onTap: () => browserService.navigateToUrl(result.url),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: result.imageUrl != null && result.imageUrl!.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          result.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildVideoPlaceholder(theme),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return _buildVideoPlaceholder(theme);
                          },
                        ),
                        Positioned(
                          bottom: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    )
                  : _buildVideoPlaceholder(theme),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, height: 1.2)),
                  if (result.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(result.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Stack(
        children: [
          const Center(child: Icon(Icons.videocam, size: 28)),
          Positioned(
            bottom: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  final String? url;

  const _VideoThumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 200, height: 110,
        child: url != null && url!.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    url!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return _buildPlaceholder(theme);
                    },
                  ),
                  Positioned(
                    bottom: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              )
            : _buildPlaceholder(theme),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.videocam, size: 32, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _SkeletonBlock extends StatefulWidget {
  final double height;
  final double width;
  final double borderRadius;

  const _SkeletonBlock({
    required this.height,
    required this.width,
    this.borderRadius = 8,
  });

  @override
  State<_SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<_SkeletonBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width == double.infinity ? double.infinity : widget.width,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class _SearchMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _SearchMessage({
    required this.icon, required this.title, required this.message,
    required this.actionLabel, required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.refresh), label: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
