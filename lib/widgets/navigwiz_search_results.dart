import 'package:flutter/material.dart';

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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Searching for "${widget.query}"',
              style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Search results will appear here',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
