/// A single browsing-history record.
///
/// Stored as JSON in SharedPreferences (`history_v2`). The legacy `history`
/// string-list is migrated on first load, so old installs keep their data.
class HistoryEntry {
  final String id;
  final String url;
  final String title;
  final DateTime visitedAt;

  const HistoryEntry({
    required this.id,
    required this.url,
    required this.title,
    required this.visitedAt,
  });

  factory HistoryEntry.fromUrl(String url, {String? title, DateTime? visitedAt}) {
    final now = visitedAt ?? DateTime.now();
    return HistoryEntry(
      id: '${now.microsecondsSinceEpoch}-${url.hashCode}',
      url: url,
      title: (title == null || title.isEmpty) ? url : title,
      visitedAt: now,
    );
  }

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String? ?? '';
    return HistoryEntry(
      id: json['id'] as String? ?? '${url.hashCode}',
      url: url,
      title: json['title'] as String? ?? url,
      visitedAt: DateTime.tryParse(json['visitedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'visitedAt': visitedAt.toIso8601String(),
      };
}
