import 'package:flutter/material.dart';
import '../models/browser_tab.dart';
import '../utils/domain_helper.dart';
import '../widgets/saturn_logo.dart';

class BrowserTabBar extends StatelessWidget {
  final List<BrowserTab> tabs;
  final int activeTabIndex;
  final bool isPrivate;
  final Function(int) onTabSelected;
  final Function(String) onTabClosed;
  final VoidCallback onNewTab;

  const BrowserTabBar({
    super.key,
    required this.tabs,
    required this.activeTabIndex,
    this.isPrivate = false,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onNewTab,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final privateStripColor =
        isDark ? const Color(0xFF263238) : const Color(0xFFD6E7FD);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isPrivate
            ? privateStripColor
            : Theme.of(context).colorScheme.surface,
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
                    isPrivate: isPrivate,
                    onTap: () => onTabSelected(index),
                    onClose: () => onTabClosed(tabs[index].id),
                  ),
                ),
              _NewTabButton(onPressed: onNewTab, isPrivate: isPrivate),
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
  final bool isPrivate;

  const _NewTabButton({required this.onPressed, this.isPrivate = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const privateBlue = Color(0xFF1E40AF);
    return Container(
      width: 34,
      height: 32,
      margin: const EdgeInsets.only(left: 4, top: 2),
      decoration: BoxDecoration(
        color: isPrivate
            ? (isDark ? const Color(0xFF37474F) : const Color(0xFFBFDBFE))
            : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPrivate
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : privateBlue.withValues(alpha: 0.3))
              : Theme.of(context).dividerColor.withValues(alpha: 0.42),
          width: 0.5,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          Icons.add,
          size: 17,
          color: isPrivate
              ? (isDark ? Colors.white.withValues(alpha: 0.9) : privateBlue)
              : Theme.of(context).colorScheme.onSurfaceVariant,
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
  final bool isPrivate;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    this.isPrivate = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const privateBlue = Color(0xFF1E40AF);
    const privateBlueDark = Color(0xFF1E3A8A);
    final privateActiveFill =
        isDark ? const Color(0xFF455A64) : const Color(0xFFBFDBFE);
    final privateIdleFill =
        isDark ? const Color(0xFF263238) : const Color(0xFFD6E7FD);
    final privateTitle =
        isDark ? Colors.white : privateBlueDark;
    final privateTitleDim = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : privateBlue.withValues(alpha: 0.75);
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
              ? (isPrivate ? privateActiveFill : Theme.of(context).colorScheme.surface)
              : (isPrivate
                  ? privateIdleFill
                  : Theme.of(context).colorScheme.surfaceContainer),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          border: Border.all(
            color: isActive
                ? (isPrivate
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : privateBlue.withValues(alpha: 0.35))
                    : Theme.of(context).dividerColor.withValues(alpha: 0.8))
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
              child: isPrivate
                  ? Icon(Icons.visibility_off,
                      size: 14,
                      color: isDark
                          ? const Color(0xFF90A4AE)
                          : const Color(0xFF1D4ED8))
                  : tab.url.isEmpty || tab.url == 'about:blank'
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
                      ? (isPrivate
                          ? privateTitle
                          : Theme.of(context).colorScheme.onSurface)
                      : (isPrivate
                          ? privateTitleDim
                          : Theme.of(context).colorScheme.onSurfaceVariant),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final privateClose = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF1E40AF).withValues(alpha: 0.75);
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
            color: isPrivate
                ? privateClose
                : isActive
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
