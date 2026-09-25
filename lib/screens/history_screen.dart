import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/history_entry.dart';
import '../services/browser_service.dart';
import '../utils/domain_helper.dart';

/// Browsing history page, opened from Settings → Browsing History.
///
/// Mirrors what mainstream browsers offer: newest-first visit tracking with
/// titles + timestamps, text search, per-item deletion, and time-range
/// clearing (last hour / 24 hours / 7 days / all time).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HistoryEntry> _filtered(List<HistoryEntry> entries) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries
        .where((e) =>
            e.url.toLowerCase().contains(q) ||
            e.title.toLowerCase().contains(q))
        .toList();
  }

  String _groupLabel(DateTime visited) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(visited.year, visited.month, visited.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff <= 7) return 'Previous 7 days';
    return 'Older';
  }

  String _timeLabel(DateTime visited) {
    final h = visited.hour % 12 == 0 ? 12 : visited.hour % 12;
    final m = visited.minute.toString().padLeft(2, '0');
    final ampm = visited.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Browsing History'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear browsing history',
            onPressed: () => _showClearDialog(context),
          ),
        ],
      ),
      body: Consumer<BrowserService>(
        builder: (context, browser, _) {
          final entries = _filtered(browser.historyEntries);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search history',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  if (entries.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${entries.length} ${entries.length == 1 ? 'item' : 'items'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: entries.isEmpty
                        ? _buildEmpty(context)
                        : _buildGroupedList(context, browser, entries),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            searching ? Icons.search_off_outlined : Icons.history,
            size: 56,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 12),
          Text(
            searching ? 'No history matches your search' : 'No browsing history yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            searching
                ? 'Try a different keyword.'
                : 'Pages you visit will appear here.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context, BrowserService browser,
      List<HistoryEntry> entries) {
    final groups = <String, List<HistoryEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(_groupLabel(e.visitedAt), () => []).add(e);
    }
    const order = ['Today', 'Yesterday', 'Previous 7 days', 'Older'];
    final orderedKeys =
        order.where((k) => groups.containsKey(k)).toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: orderedKeys.fold<int>(
          0, (sum, k) => sum + 1 + groups[k]!.length),
      itemBuilder: (context, index) {
        var cursor = index;
        for (final key in orderedKeys) {
          if (cursor == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
              child: Text(
                key,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          cursor -= 1;
          final items = groups[key]!;
          if (cursor < items.length) {
            return _buildRow(context, browser, items[cursor]);
          }
          cursor -= items.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildRow(
      BuildContext context, BrowserService browser, HistoryEntry entry) {
    final isSearch = DomainHelper.isNavigwizSearchUrl(entry.url);
    final displayTitle = isSearch
        ? 'Search: ${DomainHelper.searchQueryFromUrl(entry.url)}'
        : entry.title;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: Colors.red[400]),
      ),
      onDismissed: (_) => browser.removeHistoryEntry(entry.id),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: isSearch
              ? Icon(Icons.search,
                  color: Theme.of(context).colorScheme.primary)
              : DomainHelper.getFaviconForUrl(entry.url, size: 20),
          title: Text(
            displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '${entry.url} · ${_timeLabel(entry.visitedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Delete this item',
            onPressed: () => browser.removeHistoryEntry(entry.id),
          ),
          onTap: () {
            browser.navigateToUrl(entry.url);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    const options = [
      _ClearOption('Last hour', Duration(hours: 1)),
      _ClearOption('Last 24 hours', Duration(hours: 24)),
      _ClearOption('Last 7 days', Duration(days: 7)),
      _ClearOption('All time', null),
    ];
    Duration? selected;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Clear browsing history?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map((o) => RadioListTile<Duration?>(
                      title: Text(o.label,
                          style: const TextStyle(fontSize: 14)),
                      value: o.range,
                      // ignore: deprecated_member_use
                      groupValue: selected,
                      // ignore: deprecated_member_use
                      onChanged: (v) =>
                          setDialogState(() => selected = v),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red[400]),
              onPressed: () {
                final browser =
                    Provider.of<BrowserService>(context, listen: false);
                if (selected == null) {
                  browser.clearHistory();
                } else {
                  browser.clearHistoryBefore(
                      DateTime.now().subtract(selected!));
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Browsing history cleared')),
                );
              },
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearOption {
  final String label;
  final Duration? range;
  const _ClearOption(this.label, this.range);
}
