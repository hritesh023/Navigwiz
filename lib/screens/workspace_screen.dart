import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/workspace_provider.dart';
import '../models/workspace.dart';
import '../models/attachment.dart';
import '../services/ai_service.dart';
import '../services/input_actions.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<Attachment> _pendingAttachments = [];
  bool _listening = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment(AttachmentType type) async {
    FilePickerResult? result;
    switch (type) {
      case AttachmentType.image:
        result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
        break;
      case AttachmentType.video:
        result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
        break;
      case AttachmentType.audio:
        result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
        break;
      case AttachmentType.folder:
        final path = await FilePicker.platform.getDirectoryPath();
        if (path != null) {
          final dir = Directory(path);
          setState(() {
            _pendingAttachments.add(Attachment(
              id: 'att_${DateTime.now().millisecondsSinceEpoch}',
              name: dir.path.split(Platform.pathSeparator).last,
              path: dir.path,
              type: AttachmentType.folder,
            ));
          });
        }
        return;
      case AttachmentType.link:
        _showLinkDialog();
        return;
      default:
        result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.any);
    }
    if (result != null) {
      for (final file in result.files) {
        if (file.path != null) {
          final ext = file.name.split('.').last;
          setState(() {
            _pendingAttachments.add(Attachment(
              id: 'att_${DateTime.now().millisecondsSinceEpoch}_${_pendingAttachments.length}',
              name: file.name,
              path: file.path!,
              type: type == AttachmentType.image
                  ? AttachmentType.image
                  : type == AttachmentType.video
                      ? AttachmentType.video
                      : type == AttachmentType.audio
                          ? AttachmentType.audio
                          : Attachment.typeFromExtension(ext),
              size: file.size,
            ));
          });
        }
      }
    }
  }

  void _showLinkDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Add Link',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://...',
            border: OutlineInputBorder(),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                setState(() {
                  _pendingAttachments.add(Attachment(
                    id: 'att_${DateTime.now().millisecondsSinceEpoch}',
                    name: url,
                    path: url,
                    type: AttachmentType.link,
                    url: url,
                  ));
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _createDocument() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    if (wp.activeWorkspace == null) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Create Document',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Document title',
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create File'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    final title = titleController.text.trim().isEmpty
        ? 'Document'
        : titleController.text.trim();
    final location = await wp.createDocument(
        wp.activeWorkspace!.id, title, contentController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(location == null
          ? 'Could not create the document.'
          : 'Document created as a real file${location.contains('/') || location.contains('\\') ? ': $location' : ''}'),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _createAiImage() async {
    final promptController = TextEditingController();
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    if (wp.activeWorkspace == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Create Image with AI',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: promptController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Describe the image you want...',
            border: OutlineInputBorder(),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (promptController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Generating your image...'),
          duration: Duration(seconds: 2)),
    );

    final aiService = Provider.of<AIService>(context, listen: false);
    final imageData = await aiService.generateImage(promptController.text.trim());
    if (imageData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not generate the image.')));
      }
      return;
    }

    final bytes = Uint8List.fromList(base64Decode(imageData));
    final title = promptController.text.trim();
    final location = await wp.createImage(wp.activeWorkspace!.id, title, bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(location == null
          ? 'Could not save the image.'
          : 'Image saved${location.contains('/') || location.contains('\\') ? ' to $location' : ''}.'),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _exportWorkspace() async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    if (wp.activeWorkspace == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Exporting workspace to your files...'),
          duration: Duration(seconds: 2)),
    );

    final folder = await wp.exportWorkspace(wp.activeWorkspace!.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(folder == null
          ? 'Could not export the workspace.'
          : 'Workspace exported as real files.'),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showAttachmentPicker() {    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Attach to Workspace', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16, runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _AttachmentOption(
                    icon: Icons.insert_drive_file_outlined, label: 'Files',
                    onTap: () { Navigator.pop(ctx); _pickAttachment(AttachmentType.file); },
                  ),
                  _AttachmentOption(
                    icon: Icons.folder_outlined, label: 'Folder',
                    onTap: () { Navigator.pop(ctx); _pickAttachment(AttachmentType.folder); },
                  ),
                  _AttachmentOption(
                    icon: Icons.image_outlined, label: 'Images',
                    onTap: () { Navigator.pop(ctx); _pickAttachment(AttachmentType.image); },
                  ),
                  _AttachmentOption(
                    icon: Icons.videocam_outlined, label: 'Video',
                    onTap: () { Navigator.pop(ctx); _pickAttachment(AttachmentType.video); },
                  ),
                  _AttachmentOption(
                    icon: Icons.audiotrack_outlined, label: 'Audio',
                    onTap: () { Navigator.pop(ctx); _pickAttachment(AttachmentType.audio); },
                  ),
                  _AttachmentOption(
                    icon: Icons.link_outlined, label: 'Link',
                    onTap: () { Navigator.pop(ctx); _showLinkDialog(); },
                  ),
                  const SizedBox(width: 4),
                  _AttachmentOption(
                    icon: Icons.note_add_outlined, label: 'Create Doc',
                    onTap: () { Navigator.pop(ctx); _createDocument(); },
                  ),
                  _AttachmentOption(
                    icon: Icons.auto_fix_high, label: 'AI Image',
                    onTap: () { Navigator.pop(ctx); _createAiImage(); },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _submitMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    final provider = Provider.of<WorkspaceProvider>(context, listen: false);
    if (provider.activeWorkspace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a workspace first')),
      );
      return;
    }

    for (final att in _pendingAttachments) {
      provider.addItemToWorkspace(
        provider.activeWorkspace!.id,
        WorkspaceItem(
          id: 'item_${DateTime.now().millisecondsSinceEpoch}',
          title: att.name,
          content: text,
          type: att.type.name,
          url: att.url,
          filePath: att.path,
        ),
      );
    }
    if (text.isNotEmpty) {
      final hasAttachments = _pendingAttachments.isNotEmpty;
      provider.addItemToWorkspace(
        provider.activeWorkspace!.id,
        WorkspaceItem(
          id: 'item_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Note',
          content: text,
          type: 'note',
        ),
      );
      if (!hasAttachments) {
        _askAi(provider.activeWorkspace!.id, text);
      }
    }

    setState(() {
      _pendingAttachments = [];
      _messageController.clear();
    });
  }

  Future<void> _askAi(String workspaceId, String message) async {
    final aiService = Provider.of<AIService>(context, listen: false);
    final provider = Provider.of<WorkspaceProvider>(context, listen: false);
    final result = await aiService.sendAgentMessage(message);
    if (!mounted || !provider.workspaceIds.contains(workspaceId)) {
      return;
    }
    provider.addItemToWorkspace(
      workspaceId,
      WorkspaceItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        title: 'AI Reply',
        content: result.response,
        type: 'note',
      ),
    );
  }

  void _addWorkspaceTab() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Workspace',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Workspace name...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.workspaces_outlined, size: 20),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final wp = Provider.of<WorkspaceProvider>(context, listen: false);
                wp.addWorkspace(name);
                if (wp.workspaces.length == 1) {
                  wp.setActiveWorkspace(wp.workspaces.first.id);
                } else {
                  wp.setActiveWorkspace(wp.workspaces.last.id);
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _editItem(WorkspaceItem item) {
    final titleController = TextEditingController(text: item.title);
    final contentController = TextEditingController(text: item.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Item',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder()),
              maxLines: 3,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final wp = Provider.of<WorkspaceProvider>(context, listen: false);
              if (wp.activeWorkspace != null) {
                wp.updateItem(wp.activeWorkspace!.id, item.id,
                    title: titleController.text.trim(),
                    content: contentController.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Workspace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export workspace as files',
            onPressed: _exportWorkspace,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New workspace tab',
            onPressed: _addWorkspaceTab,
          ),
        ],
      ),
      body: Consumer<WorkspaceProvider>(
        builder: (ctx, wp, _) {
          if (wp.workspaces.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.workspaces_outlined,
                      size: 48, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Text('No workspaces yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Text('Tap + to create your first workspace',
                    style: TextStyle(fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _addWorkspaceTab,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Create Workspace'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildWorkspaceTabs(wp, isDark),
              if (wp.activeWorkspace != null)
                _buildStudioHeader(wp.activeWorkspace!, isDark),
              Expanded(
                child: wp.activeWorkspace == null
                    ? Center(child: Text('Select a workspace tab',
                        style: TextStyle(color: Colors.grey[500])))
                    : _buildWorkspaceContent(wp.activeWorkspace!),
              ),
              if (_pendingAttachments.isNotEmpty)
                _buildAttachmentsBar(),
              _buildMessageBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWorkspaceTabs(WorkspaceProvider wp, bool isDark) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: wp.workspaces.length + 1,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        itemBuilder: (ctx, i) {
          if (i == wp.workspaces.length) {
            return Center(
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(Icons.add_rounded,
                    color: Theme.of(context).colorScheme.primary),
                  onPressed: _addWorkspaceTab,
                  tooltip: 'New workspace tab',
                  visualDensity: VisualDensity.compact,
                ),
              ),
            );
          }
          final ws = wp.workspaces[i];
          final isActive = wp.activeWorkspace?.id == ws.id;
          return GestureDetector(
            onTap: () => wp.setActiveWorkspace(ws.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isActive
                    ? Border(
                        left: BorderSide(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
                        right: BorderSide(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(ws.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => wp.deleteWorkspace(ws.id),
                    child: Icon(Icons.close, size: 14,
                      color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _prefillStudioPrompt(String template) {
    _messageController.text = template;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Studio prompt ready — edit it, then press send.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Attractive studio header: workspace identity + freedom-mode explainer.
  /// Unlike Research/Projects/Chat (which do exactly what is asked), the
  /// workspace is a free-form studio: create video, apps, collages, anything.
  Widget _buildStudioHeader(Workspace workspace, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A237E).withValues(alpha: 0.85),
                  const Color(0xFF4A148C).withValues(alpha: 0.85),
                  const Color(0xFF00695C).withValues(alpha: 0.6),
                ]
              : [
                  const Color(0xFF4F46E5),
                  const Color(0xFF9333EA),
                  const Color(0xFF06B6D4),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workspace.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      '${workspace.items.length} item${workspace.items.length == 1 ? '' : 's'} in this studio',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.explore_outlined,
                        size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Freedom mode',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Your free-form AI studio — create videos, apps, image collages, music, documents, anything. Research, Projects and AI Chat follow instructions; here you explore what AI can do.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StudioQuickAction(
                  icon: Icons.videocam_outlined,
                  label: 'Video',
                  onTap: () => _prefillStudioPrompt(
                      'Create a short video about: '),
                ),
                const SizedBox(width: 8),
                _StudioQuickAction(
                  icon: Icons.web_outlined,
                  label: 'App',
                  onTap: () => _prefillStudioPrompt(
                      'Build an app that: '),
                ),
                const SizedBox(width: 8),
                _StudioQuickAction(
                  icon: Icons.photo_library_outlined,
                  label: 'Collage',
                  onTap: () => _prefillStudioPrompt(
                      'Create a collage of images about: '),
                ),
                const SizedBox(width: 8),
                _StudioQuickAction(
                  icon: Icons.image_outlined,
                  label: 'Image',
                  onTap: () => _createAiImage(),
                ),
                const SizedBox(width: 8),
                _StudioQuickAction(
                  icon: Icons.description_outlined,
                  label: 'Doc',
                  onTap: () => _createDocument(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceContent(Workspace workspace) {
    if (workspace.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          _buildExploreGrid(),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text('No items yet — pick a studio idea above,',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
                Text('or attach files / type below to get started',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: workspace.items.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildExploreGrid(compact: true),
          );
        }
        return _buildItemCard(workspace.items[i - 1]);
      },
    );
  }

  /// Studio idea cards: video, app, collage, image, music, document.
  Widget _buildExploreGrid({bool compact = false}) {
    final ideas = [
      _StudioIdea(
        icon: Icons.videocam_outlined,
        title: 'Create video',
        subtitle: 'Short clips from text',
        colors: [const Color(0xFFEF4444), const Color(0xFFF59E0B)],
        onTap: () =>
            _prefillStudioPrompt('Create a short video about: '),
      ),
      _StudioIdea(
        icon: Icons.web_outlined,
        title: 'Create app',
        subtitle: 'Websites & tools',
        colors: [const Color(0xFF4F46E5), const Color(0xFF06B6D4)],
        onTap: () => _prefillStudioPrompt('Build an app that: '),
      ),
      _StudioIdea(
        icon: Icons.photo_library_outlined,
        title: 'Image collage',
        subtitle: 'Combine pictures',
        colors: [const Color(0xFF9333EA), const Color(0xFFEC4899)],
        onTap: () =>
            _prefillStudioPrompt('Create a collage of images about: '),
      ),
      _StudioIdea(
        icon: Icons.image_outlined,
        title: 'AI image',
        subtitle: 'Generate art',
        colors: [const Color(0xFF8B5CF6), const Color(0xFF3B82F6)],
        onTap: () => _createAiImage(),
      ),
      _StudioIdea(
        icon: Icons.audiotrack_outlined,
        title: 'Audio & music',
        subtitle: 'Voice, mixes',
        colors: [const Color(0xFF10B981), const Color(0xFF14B8A6)],
        onTap: () =>
            _prefillStudioPrompt('Create audio about: '),
      ),
      _StudioIdea(
        icon: Icons.description_outlined,
        title: 'Document',
        subtitle: 'Notes & drafts',
        colors: [const Color(0xFF0EA5E9), const Color(0xFF6366F1)],
        onTap: () => _createDocument(),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Explore the studio',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(width: 6),
            Icon(Icons.auto_awesome,
                size: 14, color: Theme.of(context).colorScheme.primary),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: compact ? 3 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: compact ? 1.1 : 1.6,
          ),
          itemCount: ideas.length,
          itemBuilder: (ctx, i) => _StudioIdeaCard(idea: ideas[i]),
        ),
      ],
    );
  }

  Widget _buildItemCard(WorkspaceItem item) {
    IconData icon;
    Color color = Theme.of(context).colorScheme.primary;
    switch (item.type) {
      case 'image': icon = Icons.image_outlined; color = const Color(0xFF8B5CF6); break;
      case 'folder': icon = Icons.folder_outlined; color = const Color(0xFFF59E0B); break;
      case 'video': icon = Icons.videocam_outlined; color = const Color(0xFFEF4444); break;
      case 'audio': icon = Icons.audiotrack_outlined; color = const Color(0xFF10B981); break;
      case 'link': icon = Icons.link_outlined; color = const Color(0xFF3B82F6); break;
      case 'file': icon = Icons.insert_drive_file_outlined; color = const Color(0xFF0EA5E9); break;
      case 'note': icon = Icons.notes_outlined; color = const Color(0xFF8B5CF6); break;
      default: icon = Icons.description_outlined; color = const Color(0xFF64748B);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        title: Text(item.title,
          style: TextStyle(fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface)),
        subtitle: item.content.isNotEmpty
            ? Text(item.content, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant))
            : null,
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[500]),
          itemBuilder: (ctx) => [
            PopupMenuItem(
              child: const Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')]),
              onTap: () => _editItem(item),
            ),
            PopupMenuItem(
              child: const Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
              onTap: () {
                final wp = Provider.of<WorkspaceProvider>(context, listen: false);
                if (wp.activeWorkspace != null) {
                  wp.removeItemFromWorkspace(wp.activeWorkspace!.id, item.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsBar() {
    final iconMap = {
      AttachmentType.file: Icons.insert_drive_file_outlined,
      AttachmentType.folder: Icons.folder_outlined,
      AttachmentType.image: Icons.image_outlined,
      AttachmentType.video: Icons.videocam_outlined,
      AttachmentType.audio: Icons.audiotrack_outlined,
      AttachmentType.link: Icons.link_outlined,
      AttachmentType.document: Icons.description_outlined,
      AttachmentType.other: Icons.attach_file_outlined,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _pendingAttachments.map((att) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconMap[att.type] ?? Icons.attach_file_outlined,
                    size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(att.name, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface)),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _pendingAttachments.remove(att)),
                    child: Icon(Icons.close, size: 14,
                      color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      InputActions.stopVoice(onState: (v) {
        if (mounted) setState(() => _listening = v);
      });
      return;
    }
    await InputActions.toggleVoice(
      context,
      _messageController,
      onState: (v) {
        if (mounted) setState(() => _listening = v);
      },
    );
  }

  void _askWithCamera() {
    InputActions.showCameraSheet(
      context,
      onImage: (path) {
        final name = path.split('/').last.split('\\').last;
        setState(() {
          _pendingAttachments.add(Attachment(
            id: 'att_${DateTime.now().millisecondsSinceEpoch}',
            name: name.isEmpty ? path : name,
            path: path,
            type: AttachmentType.image,
          ));
        });
        if (_messageController.text.trim().isEmpty) {
          _messageController.text = 'What do you see in this picture?';
        }
      },
    );
  }

  Widget _buildMessageBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: Icon(Icons.add_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
              onPressed: _showAttachmentPicker,
              tooltip: 'Attach files, folders, pictures, video, audio',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _messageController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitMessage(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: _listening
                    ? 'Listening...'
                    : 'Ask AI to process attachments or add a note...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Ask with camera',
            onPressed: _askWithCamera,
            icon: const Icon(Icons.camera_alt_outlined),
          ),
          IconButton(
            tooltip: _listening ? 'Stop listening' : 'Voice input',
            onPressed: _toggleVoice,
            icon: Icon(
              _listening ? Icons.mic_rounded : Icons.mic_outlined,
              color: _listening
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            radius: 22,
            child: IconButton(
              icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              onPressed: _submitMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StudioQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _StudioIdea {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _StudioIdea({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });
}

class _StudioIdeaCard extends StatelessWidget {
  final _StudioIdea idea;

  const _StudioIdeaCard({required this.idea});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: idea.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              idea.colors[0].withValues(alpha: 0.16),
              idea.colors[1].withValues(alpha: 0.10),
            ],
          ),
          border: Border.all(
            color: idea.colors[0].withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: idea.colors[0].withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: idea.colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(idea.icon, color: Colors.white, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(idea.title,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(idea.subtitle,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
          )),
        ],
      ),
    );
  }
}
