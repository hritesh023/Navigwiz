import 'package:flutter/material.dart';
import '../utils/domain_helper.dart';
import '../widgets/saturn_logo.dart';

class AddressBar extends StatefulWidget {
  final String url;
  final bool isLoading;
  final int progress;
  final Function(String) onUrlSubmitted;
  final VoidCallback onBackPressed;
  final VoidCallback onForwardPressed;
  final VoidCallback onReloadPressed;
  final bool canGoBack;
  final bool canGoForward;
  final List<Widget> trailingActions;

  const AddressBar({
    super.key,
    required this.url,
    required this.isLoading,
    required this.progress,
    required this.onUrlSubmitted,
    required this.onBackPressed,
    required this.onForwardPressed,
    required this.onReloadPressed,
    this.canGoBack = false,
    this.canGoForward = false,
    this.trailingActions = const [],
  });

  @override
  State<AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends State<AddressBar> {
  late TextEditingController _controller;
  bool _isEditing = false;

  String _displayUrl(String url) {
    if (DomainHelper.isNavigwizSearchUrl(url)) {
      final query = DomainHelper.searchQueryFromUrl(url);
      return query.isNotEmpty ? query : url;
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _displayUrl(widget.url));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AddressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.url != oldWidget.url) {
      _controller.text = _displayUrl(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Navigation controls with modern styling
              Row(
                children: [
                  _buildNavigationButton(
                    icon: Icons.arrow_back,
                    onPressed: widget.canGoBack ? widget.onBackPressed : null,
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 2),
                  _buildNavigationButton(
                    icon: Icons.arrow_forward,
                    onPressed: widget.canGoForward ? widget.onForwardPressed : null,
                    tooltip: 'Forward',
                  ),
                  const SizedBox(width: 2),
                  _buildNavigationButton(
                    icon: Icons.refresh,
                    onPressed: widget.onReloadPressed,
                    tooltip: 'Reload',
                    isLoading: widget.isLoading,
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // Modern address field
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      _isEditing = false;
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isEditing
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                          : Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isEditing
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: _isEditing
                          ? [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: TextField(
                      controller: _controller,
                      onTap: () => setState(() => _isEditing = true),
                      onSubmitted: (value) {
                        _isEditing = false;
                        widget.onUrlSubmitted(value);
                      },
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search or enter address',
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        prefixIcon: _isEditing
                            ? null
                            : Container(
                                padding: const EdgeInsets.all(12),
                                child: _getFavicon(widget.url),
                              ),
                        suffixIcon: _isEditing ? _buildGoButton() : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (widget.trailingActions.isNotEmpty) ...[
                const SizedBox(width: 8),
                ...widget.trailingActions,
              ],
            ],
          ),

          // Modern progress bar
          if (widget.isLoading && widget.progress < 100)
            Container(
              height: 2,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(1),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widget.progress / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getFavicon(String url) {
    if (url.isEmpty || url == 'about:blank') {
      return const SaturnLogo(size: 16);
    }

    if (DomainHelper.isNavigwizDomain(url)) {
      return const SaturnLogo(size: 16);
    }

    try {
      final uri = Uri.parse(url);
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Theme.of(context).colorScheme.surfaceContainer,
        ),
        child: Center(
          child: Text(
            uri.host.isNotEmpty ? uri.host[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } catch (e) {
      return const SaturnLogo(size: 16);
    }
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                )
              : Icon(
                  icon,
                  size: 16,
                  color: enabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildGoButton() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: IconButton(
        onPressed: () {
          _isEditing = false;
          widget.onUrlSubmitted(_controller.text);
        },
        icon: Icon(
          Icons.arrow_forward,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        tooltip: 'Go',
      ),
    );
  }
}
