import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_service.dart';
import '../services/browser_service.dart';
import 'acronous_logo.dart';

class AIAssistantPanel extends StatefulWidget {
  final List<AIMessage> messages;
  final bool isLoading;
  final Function(String) onSendMessage;
  final VoidCallback onClose;

  const AIAssistantPanel({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.onSendMessage,
    required this.onClose,
  });

  @override
  State<AIAssistantPanel> createState() => _AIAssistantPanelState();
}

class _AIAssistantPanelState extends State<AIAssistantPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context),

          // Messages area
          Expanded(child: _buildMessagesArea(context)),

          // Input area
          _buildInputArea(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          const AcronousLogo(size: 20, showGlow: true),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Acronous AI',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: widget.messages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AcronousLogo(size: 64, showGlow: true),
                  const SizedBox(height: 16),
                  Text(
                    'Ask AI anything',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search the web, summarize pages, translate text, and get quick answers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final message = widget.messages[index];
                final isUser = message.isUser;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: const AcronousLogo(size: 16),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content,
                                style: TextStyle(
                                  color: isUser
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Consumer<AIService>(
      builder: (context, aiService, child) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Quick action buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _QuickActionButton(
                      icon: Icons.search,
                      label: 'Search',
                      onPressed: () => _performQuickAction('search'),
                    ),
                    _QuickActionButton(
                      icon: Icons.summarize,
                      label: 'Summarize',
                      onPressed: () => _performQuickAction('summarize'),
                    ),
                    _QuickActionButton(
                      icon: Icons.translate,
                      label: 'Translate',
                      onPressed: () => _performQuickAction('translate'),
                    ),
                    _QuickActionButton(
                      icon: Icons.cloud,
                      label: 'Weather',
                      onPressed: () => _performQuickAction('weather'),
                    ),
                    _QuickActionButton(
                      icon: Icons.newspaper,
                      label: 'News',
                      onPressed: () => _performQuickAction('news'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Message input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Ask AI...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: aiService.isLoading ? null : _sendMessage,
                    icon: aiService.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    _scrollToBottom();

    try {
      widget.onSendMessage(message);
      _scrollToBottom();
    } catch (e) {
      // Error handling is done by the parent widget
      _scrollToBottom();
    }
  }

  void _performQuickAction(String action) {
    switch (action) {
      case 'search':
        _messageController.text = 'Search for: ';
        break;
      case 'summarize':
        final browserService = Provider.of<BrowserService>(
          context,
          listen: false,
        );
        if (browserService.currentUrl.isNotEmpty) {
          _messageController.text = 'Please summarize the current page';
        } else {
          _messageController.text = 'Please summarize this text: ';
        }
        break;
      case 'translate':
        _messageController.text = 'Translate this to English: ';
        break;
      case 'weather':
        _messageController.text = 'What\'s the weather like?';
        _sendMessage();
        break;
      case 'news':
        _messageController.text = 'What are the latest news headlines?';
        _sendMessage();
        break;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
