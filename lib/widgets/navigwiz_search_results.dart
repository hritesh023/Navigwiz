import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_service.dart';
import '../services/browser_service.dart';
import 'markdown_body.dart';

class NavigwizSearchResults extends StatefulWidget {
  final String query;

  const NavigwizSearchResults({
    super.key,
    required this.query,
  });

  @override
  State<NavigwizSearchResults> createState() => _NavigwizSearchResultsState();
}

class _NavigwizSearchResultsState extends State<NavigwizSearchResults> {
  SearchResponse? _searchResponse;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    final aiService = Provider.of<AIService>(context, listen: false);
    setState(() => _isLoading = true);

    final response = await aiService.searchWithOverview(
      widget.query,
      forceRefresh: true,
      waitForAi: false,
    );

    if (!mounted) return;
    setState(() {
      _searchResponse = response;
      _isLoading = false;
    });

    final aiAnswer = await aiService.getAiAnswerForSearch(response.results, widget.query);
    if (!mounted || aiAnswer.isEmpty) return;
    setState(() {
      _searchResponse = SearchResponse(
        aiAnswer: aiAnswer,
        results: response.results,
        suggestions: response.suggestions,
        infoboxes: response.infoboxes,
        answers: response.answers,
        resultCount: response.resultCount,
        searchTime: response.searchTime,
      );
    });
  }

  void _openUrl(String url) {
    Provider.of<BrowserService>(context, listen: false).navigateToUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: _isLoading ? _buildLoading(theme) : _buildResults(theme),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.search, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 18),
          const CircularProgressIndicator(strokeWidth: 2.5),
          const SizedBox(height: 14),
          Text(
            'Navigwiz agentic AI is finding the best results…',
            style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    final response = _searchResponse;
    final results = response?.results ?? <SearchResult>[];
    final items = <Widget>[];

    if (response?.aiAnswer.isNotEmpty ?? false) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: _buildAiAnswer(theme),
      ));
    }
    if (response != null && response.suggestions.isNotEmpty) {
      items.add(_buildSuggestions(theme));
    }
    if (results.isEmpty) {
      items.add(_buildEmptyState(theme));
    } else {
      for (final r in results) {
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: _buildResultCard(theme, r),
        ));
      }
      items.add(_buildFooter(theme));
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(theme)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => items[index],
            childCount: items.length,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final response = _searchResponse;
    final primary = theme.colorScheme.primary;
    final count = response?.resultCount ?? response?.results.length ?? 0;
    final time = response?.searchTime ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.16),
            primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: primary.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text('Navigwiz Agentic Search',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
              ),
              const Spacer(),
              if (count > 0)
                Text('$count results',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant)),
              if (count > 0 && time.isNotEmpty)
                Text(' • $time',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.search, size: 22, color: primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.query,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiAnswer(ThemeData theme) {
    final answer = _searchResponse?.aiAnswer ?? '';
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.12),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text('AI Overview',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 10),
          MarkdownBody(text: answer, onOpenUrl: _openUrl),
        ],
      ),
    );
  }

  Widget _buildSuggestions(ThemeData theme) {
    final suggestions = _searchResponse?.suggestions ?? const <String>[];
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Related searches',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestions
                .map((s) => ActionChip(
                      avatar: Icon(Icons.search,
                          size: 14, color: theme.colorScheme.primary),
                      label: Text(s,
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface)),
                      onPressed: () => _openUrl(s),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme, SearchResult result) {
    final primary = theme.colorScheme.primary;
    final domain = _domainOf(result.url);
    final letter = domain.isNotEmpty ? domain[0].toUpperCase() : '?';

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openUrl(result.url),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withValues(alpha: 0.18),
                      primary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(letter,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(result.title,
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface)),
                        ),
                        Icon(Icons.north_east,
                            size: 14, color: primary.withValues(alpha: 0.8)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(domain,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: primary)),
                    if (result.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(result.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                    if (result.publishedDate != null &&
                        result.publishedDate!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(_prettyDate(result.publishedDate!),
                          style: TextStyle(
                              fontSize: 10.5,
                              color: theme.colorScheme.onSurfaceVariant)),
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

  Widget _buildFooter(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome,
              size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Curated by the Navigwiz agentic AI — every result links to a real source.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off,
                size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text('No results found for "${widget.query}"',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('Try different keywords or a more specific query.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  String _domainOf(String url) {
    try {
      final host = Uri.parse(url).host;
      return host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  String _prettyDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays < 1) return 'Today';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return dt.year.toString();
  }
}
