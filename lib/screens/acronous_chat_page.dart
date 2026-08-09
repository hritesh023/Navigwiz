import 'package:flutter/material.dart';
import '../widgets/agentic_chat_view.dart';

class AcronousChatPage extends StatelessWidget {
  const AcronousChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Navigwiz AI Chat'),
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: const AgenticChatView(
        autoFocus: true,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      ),
    );
  }
}
