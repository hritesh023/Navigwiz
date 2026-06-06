import 'package:flutter/material.dart';

class BrowserTab {
  final String id;
  String title;
  String url;
  IconData favicon;
  bool isLoading;
  int progress;

  BrowserTab({
    required this.id,
    this.title = 'New Tab',
    this.url = 'about:blank',
    this.favicon = Icons.language,
    this.isLoading = false,
    this.progress = 0,
  });

  factory BrowserTab.fromJson(Map<String, dynamic> json) => BrowserTab(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'New Tab',
    url: json['url'] as String? ?? 'about:blank',
    favicon: _parseIcon(json['favicon'] as String? ?? 'language'),
    isLoading: json['isLoading'] as bool? ?? false,
    progress: json['progress'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'favicon': favicon.codePoint > 0 ? String.fromCharCode(favicon.codePoint) : 'language',
    'isLoading': isLoading,
    'progress': progress,
  };

  static IconData _parseIcon(String iconName) {
    switch (iconName) {
      case 'language': return Icons.language;
      case 'search': return Icons.search;
      case 'lock': return Icons.lock;
      case 'lock_open': return Icons.lock_open;
      default: return Icons.language;
    }
  }

  BrowserTab copyWith({
    String? id,
    String? title,
    String? url,
    IconData? favicon,
    bool? isLoading,
    int? progress,
  }) {
    return BrowserTab(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      favicon: favicon ?? this.favicon,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
    );
  }
}