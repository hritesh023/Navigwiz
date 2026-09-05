import 'package:flutter/material.dart';
import '../utils/domain_helper.dart';
import 'agentic_chat_view.dart';

/// Acronous AI guide: pops up only when the user taps the Acronous button,
/// examines the current page, and assists with the work on it.
class AiAssistantSidePanel extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback? onExpand;
  final String currentUrl;
  final String currentTitle;

  const AiAssistantSidePanel({
    super.key,
    required this.onClose,
    this.onExpand,
    this.currentUrl = '',
    this.currentTitle = '',
  });

  String _pageLabel() {
    if (DomainHelper.isNavigwizSearchUrl(currentUrl)) {
      final q = DomainHelper.searchQueryFromUrl(currentUrl);
      return q.isEmpty ? 'Navigwiz search' : 'Search: "$q"';
    }
    if (DomainHelper.isNavigwizDomain(currentUrl) ||
        currentUrl.isEmpty ||
        currentUrl == 'about:blank') {
      return 'Navigwiz home';
    }
    try {
      final uri = Uri.parse(currentUrl);
      if (uri.host.isNotEmpty) {
        return uri.host.replaceFirst('www.', '');
      }
    } catch (_) {}
    return currentTitle.isNotEmpty ? currentTitle : 'this page';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Acronous AI guide',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface),
                    ),
                    const Spacer(),
                    if (onExpand != null)
                      IconButton(
                        icon: const Icon(Icons.open_in_full, size: 18),
                        tooltip: 'Open full chat',
                        onPressed: onExpand,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Close guide',
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.remove_red_eye_outlined,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Looking at ${_pageLabel()} — ask me to summarize, explain or help with it.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AgenticChatView(
              // Seed page context so the guide answers about THIS page.
              pageContext: currentUrl.isNotEmpty
                  ? 'The user is viewing: title="$currentTitle" url="$currentUrl". Help with this page when asked.'
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
