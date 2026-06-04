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
