import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/agent_response.dart';
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
  bool _isAiLoading = true;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    final aiService = Provider.of<AIService>(context, listen: false);
    setState(() {
      _isLoading = true;
      _isAiLoading = true;
    });

    // Results page + AI answer fire TOGETHER in parallel (not serially):
    // links render as soon as /search returns (~1s) while the single
    // /v1/chat roundtrip (fast search + LLM) lands the AI Overview on top
    // when ready. Total wait = max, never sum.
    final resultsFuture = aiService.searchWithOverview(
      widget.query,
      forceRefresh: true,
      waitForAi: false,
    );
    final aiFuture =
        aiService.sendAgentMessage(widget.query, mode: 'web_search');

    unawaited(resultsFuture.then((response) {      if (!mounted) return;
      setState(() {
        final currentAi = _searchResponse?.aiAnswer ?? '';
        _searchResponse = SearchResponse(
          aiAnswer: currentAi,
          results: response.results,
          imageResults: response.imageResults,
          newsResults: response.newsResults,
          videoResults: response.videoResults,
          bookResults: response.bookResults,
          suggestions: response.suggestions,
          infoboxes: response.infoboxes,
          answers: response.answers,
          resultCount: response.resultCount,
          searchTime: response.searchTime,
        );
        _isLoading = false;
      });
    }).catchError((_) {
      if (mounted) setState(() => _isLoading = false);
    }));

    unawaited(aiFuture.then((agent) {
      if (!mounted) return;
      setState(() {
        _isAiLoading = false;
        final answer = agent.response.trim();
        final current = _searchResponse;
        if (answer.isNotEmpty) {
          _searchResponse = SearchResponse(
            aiAnswer: answer,
            results: current?.results ?? _agentSourcesAsResults(agent),
            imageResults: current?.imageResults ?? const [],
            newsResults: current?.newsResults ?? const [],
            videoResults: current?.videoResults ?? const [],
            bookResults: current?.bookResults ?? const [],
            suggestions: current?.suggestions ?? const [],
            infoboxes: current?.infoboxes ?? const [],
            answers: current?.answers ?? const [],
            resultCount: current?.resultCount,
            searchTime: current?.searchTime ?? '',
          );
        } else if (current == null) {
          // Chat empty but finished: fall back to agent sources as links.
          final fallback = _agentSourcesAsResults(agent);
          if (fallback.isNotEmpty) {
            _searchResponse = SearchResponse(
              aiAnswer: '',
              results: fallback,
              resultCount: fallback.length,
            );
          }
        }
      });
    }).catchError((_) {
      if (mounted) setState(() => _isAiLoading = false);
    }));
  }

  /// Converts agent sources to result cards so the page never ends up with
  /// links missing when /search returns empty but chat found sources.
  List<SearchResult> _agentSourcesAsResults(AgentResponse agent) {
    return agent.sources
        .where((s) => s.title.isNotEmpty && s.url.isNotEmpty)
        .take(10)
        .map((s) => SearchResult(
              title: s.title,
              url: s.url,
              description: s.snippet,
              relevanceScore: 0.8,
            ))
        .toList();
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
    final images = response?.imageResults ?? <SearchResult>[];
    final items = <Widget>[];

    // AI Overview ALWAYS first — live answer, loading skeleton, or fallback.
    items.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: _isAiLoading && (response?.aiAnswer.isEmpty ?? true)
          ? _buildAiLoading(theme)
          : (response?.aiAnswer.isNotEmpty ?? false)
              ? _buildAiAnswer(theme)
              : _buildAiEmpty(theme),
    ));
    // Photos strip when the query merits visuals (image results present).
    if (images.isNotEmpty) {
      items.add(_buildImageStrip(theme, images));
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

  Widget _buildAiLoading(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
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
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text('AI Overview — answering…',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          _shimmerLine(theme, double.infinity),
          const SizedBox(height: 8),
          _shimmerLine(theme, double.infinity),
          const SizedBox(height: 8),
          _shimmerLine(theme, 180),
        ],
      ),
    );
  }

  Widget _shimmerLine(ThemeData theme, double width) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _buildAiEmpty(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI Overview is unavailable right now — results below are still fresh.',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageStrip(ThemeData theme, List<SearchResult> images) {
    final withThumbs =
        images.where((r) => (r.imageUrl ?? '').isNotEmpty).take(10).toList();
    final fallback = withThumbs.isEmpty
        ? images.take(10).toList()
        : withThumbs;
    if (fallback.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Icon(Icons.image_outlined,
                  size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('Photos',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: fallback.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final r = fallback[i];
              final thumb = (r.imageUrl ?? '').isNotEmpty
                  ? r.imageUrl!
                  : r.url;
              return GestureDetector(
                onTap: () => _openUrl(r.url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 150,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(r.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: theme
                                          .colorScheme.onSurfaceVariant)),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            color: Colors.black.withValues(alpha: 0.55),
                            child: Text(r.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
