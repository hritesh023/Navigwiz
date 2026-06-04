import 'package:flutter/material.dart';
import '../widgets/saturn_logo.dart';

class DomainHelper {
  static const String _navigwizDomain = 'Navigwiz';
  static const String _navigwizSearchPrefix = 'Navigwiz Search:';

  static bool isNavigwizDomain(String? url) {
    if (url == null) return false;
    final trimmedUrl = url.trim();
    return trimmedUrl == _navigwizDomain ||
        trimmedUrl == 'about:blank' ||
        isNavigwizSearchUrl(trimmedUrl);
  }

  static bool isNavigwizSearchUrl(String? url) {
    if (url == null) return false;
    return url.trim().startsWith(_navigwizSearchPrefix);
  }

  static String getDisplayTitle(String? url, String defaultTitle) {
    if (isNavigwizSearchUrl(url)) {
      return 'New Tab';
    }
    if (isNavigwizDomain(url) || url == 'about:blank') {
      return 'Navigwiz';
    }
    return defaultTitle == 'New Tab' ? titleFromUrl(url ?? '') : defaultTitle;
  }

  static Widget getFaviconForUrl(String? url, {double size = 16.0}) {
    if (isNavigwizDomain(url) || url == 'about:blank') {
      return SaturnLogo(size: size);
    }
    return Icon(Icons.language, size: size);
  }

  static String getNavigwizDomain() {
    return _navigwizDomain;
  }

  static String getNavigwizSearchUrl(String query) {
    return '$_navigwizSearchPrefix ${query.trim()}';
  }

  static String searchQueryFromUrl(String? url) {
    if (!isNavigwizSearchUrl(url)) return '';
    return url!.trim().substring(_navigwizSearchPrefix.length).trim();
  }

  static String titleFromUrl(String url) {
    if (isNavigwizSearchUrl(url)) {
      return 'New Tab';
    }
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty) {
        return uri.host.replaceFirst('www.', '');
      }
      if (uri.queryParameters.containsKey('q')) {
        return uri.queryParameters['q']!;
      }
    } catch (_) {
      // Keep the fallback below.
    }
    return url.isEmpty ? 'Navigwiz' : url;
  }
}
