import 'package:flutter/material.dart';

class NavSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onVoicePressed;
  final VoidCallback? onAttachPressed;
  final VoidCallback? onSubmitPressed;
  final ValueChanged<String>? onSubmitted;
  final bool isLoading;

  const NavSearchBar({
    super.key,
    required this.controller,
    this.onCameraPressed,
    this.onVoicePressed,
    this.onAttachPressed,
    this.onSubmitPressed,
    this.onSubmitted,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      height: 56,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[900]!.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!.withValues(alpha: 0.5)
              : Colors.grey[300]!.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey[400]!)
                .withValues(alpha: isDark ? 0.3 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          _IconButton(
            icon: Icons.add_rounded,
            tooltip: 'Attach Files or Folders',
            onPressed: onAttachPressed,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'What do you want to do?...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          _IconButton(
            icon: Icons.camera_alt_outlined,
            tooltip: 'Camera Analysis',
            onPressed: onCameraPressed,
          ),
          _IconButton(
            icon: Icons.mic_outlined,
            tooltip: 'Voice Search',
            onPressed: onVoicePressed,
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 1,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          _SubmitButton(
            isLoading: isLoading,
            onPressed: onSubmitPressed ?? (() {
              if (onSubmitted != null) {
                onSubmitted!(controller.text);
              }
            }),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 22,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.arrow_forward,
          size: 20,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
