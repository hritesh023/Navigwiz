import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/agent_response.dart';
import '../providers/project_provider.dart';
import '../screens/project_screen.dart';
import '../services/ai_service.dart';
import '../services/browser_service.dart';
import 'markdown_body.dart';

class AgenticChatView extends StatefulWidget {
  final EdgeInsets padding;
  final bool autoFocus;

  const AgenticChatView({
    super.key,
    this.padding = EdgeInsets.zero,
    this.autoFocus = false,
  });

  @override
  State<AgenticChatView> createState() => _AgenticChatViewState();
}

class _AgenticChatViewState extends State<AgenticChatView> {
  final List<AgentChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _mode = 'auto';
  String? _sessionId;
  bool _isBusy = false;

  static const Map<String, String> _modeLabels = {
    'auto': 'Chat',
    'web_search': 'Search',
    'research': 'Research',
    'project': 'Build',
    'image': 'Image',
  };

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _send([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty || _isBusy) return;
    _controller.clear();

    setState(() {
      _messages.add(AgentChatMessage(
        id: 'u_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        isUser: true,
      ));
      _isBusy = true;
    });
    _scrollToBottom();

    final aiService = Provider.of<AIService>(context, listen: false);
    AgentResponse result;

    if (_mode == 'image') {
      final imageData = await aiService.generateImage(text);
      result = AgentResponse(
        response: imageData.isNotEmpty
            ? 'Here is the image I generated for: "$text"'
            : 'Image generation is unavailable right now. Try again later.',
        mode: 'image',
        imageData: imageData.isNotEmpty ? imageData : null,
        isSimple: true,
      );
    } else if (_mode == 'research') {
      result = await aiService.runResearchAgent(text);
    } else if (_mode == 'project') {
      result = await aiService.generateProjectAgent(text);
    } else {
      result = await aiService.sendAgentMessage(
        text,
        mode: _mode == 'auto' ? null : _mode,
        sessionId: _sessionId,
      );
      if (result.sessionId.isNotEmpty) _sessionId = result.sessionId;
    }

    final responseText = result.response.isNotEmpty
        ? result.response
        : result.project != null
            ? 'Project "${result.project!.name}" generated.'
            : result.research != null
                ? 'Research completed for your query.'
                : 'I processed your request.';

    if (mounted) {
      setState(() {
        _messages.add(AgentChatMessage(
          id: 'a_${DateTime.now().millisecondsSinceEpoch}',
          text: responseText,
          isUser: false,
          agentResponse: result,
        ));
        _isBusy = false;
      });
      _scrollToBottom();
    }
  }

  void _openUrl(String url) {
    Provider.of<BrowserService>(context, listen: false).navigateToUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _buildWelcome(theme)
              : _buildMessageList(theme),
        ),
        _buildModeSelector(theme),
        _buildInputBar(theme),
      ],
    );
  }

  Widget _buildWelcome(ThemeData theme) {
    final suggestions = [
      'What can Navigwiz AI do for me?',
      'Research the best laptops under \$80,000',
      'Generate a website about a coffee shop',
      'What happened in AI news this week?',
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          widget.padding.left + 16, widget.padding.top + 16, widget.padding.right + 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.16),
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome,
                    color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Navigwiz AI',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 4),
                      Text(
                        'I can chat, search the web, research topics in depth, build projects and generate images. Pick a mode below, then ask me anything.',
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Try asking',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((s) => ActionChip(
                  label: Text(s,
                      style: TextStyle(
                          fontSize: 12, color: theme.colorScheme.onSurface)),
                  onPressed: () => _send(s),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
          widget.padding.left + 16, widget.padding.top + 16, widget.padding.right + 16, 16),
      itemCount: _messages.length + (_isBusy ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Thinking...', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          );
        }
        final message = _messages[index];
        if (message.isUser) return _UserBubble(text: message.text);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _AiBubble(message: message, onOpenUrl: _openUrl),
        );
      },
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _modeLabels.entries.map((entry) {
            final selected = _mode == entry.key;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                selected: selected,
                showCheckmark: false,
                avatar: Icon(
                  _modeIcon(entry.key),
                  size: 14,
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (_) => setState(() => _mode = entry.key),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _modeIcon(String mode) {
    switch (mode) {
      case 'web_search':
        return Icons.search;
      case 'research':
        return Icons.travel_explore;
      case 'project':
        return Icons.code;
      case 'image':
        return Icons.image_outlined;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  Widget _buildInputBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          widget.padding.left + 12, 6, widget.padding.right + 12, widget.padding.bottom + 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autoFocus,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: TextStyle(
                  fontSize: 14, color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Message ${_modeLabels[_mode]}...',
                hintStyle:
                    TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isBusy
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                  : theme.colorScheme.primary,
            ),
            child: IconButton(
              onPressed: _isBusy ? null : () => _send(),
              icon: const Icon(Icons.arrow_upward,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onPrimary)),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final AgentChatMessage message;
  final ValueChanged<String> onOpenUrl;

  const _AiBubble({required this.message, required this.onOpenUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final response = message.agentResponse;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome,
                  size: 12, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 6),
            Text('Navigwiz AI',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant)),
            if (response != null && response.mode.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_modeLabel(response.mode),
                    style: TextStyle(
                        fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.text.isNotEmpty)
                MarkdownBody(text: message.text, onOpenUrl: onOpenUrl),
              if (response?.imageData != null && response!.imageData!.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    base64Decode(response.imageData!),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
              if (response?.research != null) ...[
                const SizedBox(height: 12),
                _ResearchCard(research: response!.research!, onOpenUrl: onOpenUrl),
              ],
              if (response?.project != null) ...[
                const SizedBox(height: 12),
                _ProjectCard(project: response!.project!),
              ],
              if (response?.sources != null && response!.sources.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Sources',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: response.sources.map((s) => ActionChip(
                        avatar: Icon(Icons.link,
                            size: 12,
                            color: theme.colorScheme.primary),
                        label: Text(_domainOf(s.url),
                            style: const TextStyle(fontSize: 11)),
                        onPressed: () => onOpenUrl(s.url),
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                ),
              ],
            ],
          ),
        ),
        if (response?.suggestions != null && response!.suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: response.suggestions.map((s) => InkWell(
                    onTap: () => onOpenUrl(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.north_east,
                              size: 12, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(s,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface)),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
            ),
          ),
        if (message.isError)
          const SizedBox(height: 8),
      ],
    );
  }

  String _domainOf(String url) {
    try {
      final host = Uri.parse(url).host;
      return host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'web_search':
        return 'Search';
      case 'research':
        return 'Research';
      case 'project':
        return 'Project';
      case 'image':
      case 'image_generation':
        return 'Image';
      default:
        return 'Chat';
    }
  }
}

class _ResearchCard extends StatelessWidget {
  final AgentResearch research;
  final ValueChanged<String> onOpenUrl;

  const _ResearchCard({required this.research, required this.onOpenUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('Research Report',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface)),
            ],
          ),
          if (research.executiveSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(research.executiveSummary,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
          if (research.keyFindings.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Key Findings',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            ...research.keyFindings.take(5).map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 12, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(f.title,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: theme.colorScheme.onSurface)),
                      ),
                    ],
                  ),
                )),
          ],
          if (research.references.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('References',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            ...research.references.take(5).map((ref) => InkWell(
                  onTap: () => onOpenUrl(ref.url),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.link,
                            size: 12, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(ref.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary)),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _ProjectCard extends StatefulWidget {
  final AgentProject project;
  const _ProjectCard({required this.project});

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _saving = false;

  Future<void> _save() async {
    final provider =
        Provider.of<ProjectProvider>(context, listen: false);
    setState(() => _saving = true);
    try {
      final savedPath =
          await provider.saveAgentProject(widget.project);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(kIsWeb
            ? savedPath
            : 'Saved project to $savedPath'),
        duration: const Duration(seconds: 3),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the project')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code, size: 16, color: theme.colorScheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(widget.project.name.isEmpty
                    ? 'Generated Project'
                    : widget.project.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface)),
              ),
              if (widget.project.language.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(widget.project.language,
                      style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onTertiaryContainer)),
                ),
            ],
          ),
          if (widget.project.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.project.summary,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 10),
          if (widget.project.files.isEmpty)
            Text('No files were generated.',
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant))
          else
            ...widget.project.files.take(12).map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined,
                          size: 12, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(f.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface)),
                      ),
                      Text('${(f.content.length / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )),
          if (widget.project.files.length > 12)
            Text('+${widget.project.files.length - 12} more files',
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_alt,
                          size: 16),
                  label: const Text('Save Project',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ProjectScreen()));
                },
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Open Projects', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
