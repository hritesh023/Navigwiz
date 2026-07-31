import 'package:flutter/material.dart';
import 'agentic_chat_view.dart';

class AiAssistantSidePanel extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback? onExpand;

  const AiAssistantSidePanel({
    super.key,
    required this.onClose,
    this.onExpand,
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
                Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI Assistant',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface),
                ),
                const Spacer(),
                if (onExpand != null)
                  IconButton(
                    icon: const Icon(Icons.open_in_full, size: 18),
                    onPressed: onExpand,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Expanded(
            child: AgenticChatView(),
          ),
        ],
      ),
    );
  }
}
