import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_message.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/acronous_logo.dart';

class AiAssistantSidePanel extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onExpand;

  const AiAssistantSidePanel({
    super.key,
    required this.onClose,
    required this.onExpand,
  });

  @override
  State<AiAssistantSidePanel> createState() => _AiAssistantSidePanelState();
}

class _AiAssistantSidePanelState extends State<AiAssistantSidePanel> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dividerColor = Theme.of(context).dividerColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.5),
            cs.surface,
          ],
        ),
        border: Border(
          left: BorderSide(color: dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chat, _) {
                final msgs = chat.currentMessages;
                _scrollToBottom();
                return msgs.isEmpty
                    ? _buildWelcomeScreen()
                    : _buildMessagesList(msgs, chat);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const AcronousLogo(size: 18, showGlow: true),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Acronous AI',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onExpand,
            icon: Icon(Icons.open_in_full, size: 18, color: cs.onSurfaceVariant),
            tooltip: 'Expand to full screen',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AcronousLogo(size: 48),
            const SizedBox(height: 16),
            Text(
              'How can I help you?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ask me anything',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(List<ChatMessage> messages, ChatProvider chat) {
    return ListView.builder(
      key: const ValueKey('side_panel_messages'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
      itemCount: messages.length + (chat.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                TypingIndicator(),
              ],
            ),
          );
        }
        return ChatMessageWidget(message: messages[index]);
      },
    );
  }

  Widget _buildInputArea() {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: ChatInput(key: ValueKey('side_panel_chat_input')),
      ),
    );
  }
}
