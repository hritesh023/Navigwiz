import 'package:flutter/material.dart';
import '../models/browser_tab.dart';
import '../utils/domain_helper.dart';
import '../widgets/saturn_logo.dart';

class BrowserTabBar extends StatelessWidget {
  final List<BrowserTab> tabs;
  final int activeTabIndex;
  final Function(int) onTabSelected;
  final Function(String) onTabClosed;
  final VoidCallback onNewTab;

  const BrowserTabBar({
    super.key,
    required this.tabs,
    required this.activeTabIndex,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onNewTab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const SizedBox(width: 8),
              for (var index = 0; index < tabs.length; index++)
                Container(
                  margin: const EdgeInsets.only(right: 2, top: 2),
                  child: _TabItem(
                    tab: tabs[index],
                    isActive: index == activeTabIndex,
                    onTap: () => onTabSelected(index),
                    onClose: () => onTabClosed(tabs[index].id),
                  ),
                ),
              _NewTabButton(onPressed: onNewTab),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewTabButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _NewTabButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 32,
      margin: const EdgeInsets.only(left: 4, top: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.42),
          width: 0.5,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          Icons.add,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        padding: EdgeInsets.zero,
        tooltip: 'New Tab',
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final BrowserTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 120,
          maxWidth: 240,
        ),
        height: 32,
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          border: Border.all(
            color: isActive
                ? Theme.of(context).dividerColor.withValues(alpha: 0.8)
                : Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: isActive ? 1 : 0.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),

            // Favicon with better styling
            SizedBox(
              width: 16,
              height: 16,
              child: tab.url.isEmpty || tab.url == 'about:blank'
                  ? const SaturnLogo(size: 14)
                  : DomainHelper.getFaviconForUrl(
                      tab.url,
                      size: 14.0,
                    ),
            ),

            const SizedBox(width: 6),

            // Title with better typography
            Expanded(
              child: Text(
                tab.title.isEmpty ? 'New Tab' : tab.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                  letterSpacing: 0,
                ),
              ),
            ),

            // Loading indicator or close button
            if (tab.isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              )
            else
              _buildCloseButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: 24,
        height: 24,
        child: IconButton(
          onPressed: onClose,
          icon: Icon(
            Icons.close,
            size: 12,
            color: isActive
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          padding: EdgeInsets.zero,
          tooltip: 'Close tab',
          style: IconButton.styleFrom(
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}
