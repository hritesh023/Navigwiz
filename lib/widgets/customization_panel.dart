import 'package:flutter/material.dart';

class CustomizationPanel extends StatelessWidget {
  final VoidCallback onClose;

  const CustomizationPanel({
    super.key,
    required this.onClose,
  });

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
            child: Row(
              children: [
                Icon(Icons.palette, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Customize',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Customization options coming soon',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
