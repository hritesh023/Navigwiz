import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/project_provider.dart';
import '../services/ai_service.dart';
import '../services/browser_service.dart';
import '../utils/project_confirm.dart';
import '../widgets/nav_search_bar.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _selectedType = 'all';
  String _projectRoot = '';
  bool _generating = false;
  String _searchQuery = '';
  // AI Overview for the project search bar: AI answers first, local files
  // and web links follow below.
  String _projectAiAnswer = '';
  List<SearchResult> _projectAiSources = const [];
  bool _projectAiLoading = false;

  @override
  void initState() {
    super.initState();
    _initProjectRoot();
  }

  void _initProjectRoot() {
    final pp = Provider.of<ProjectProvider>(context, listen: false);
    if (kIsWeb) {
      _projectRoot = 'NavigwizProjects';
      pp.setProjectRoot(_projectRoot);
      return;
    }
    try {
      if (Platform.isWindows) {
        _projectRoot = '${Platform.environment['USERPROFILE']}\\NavigwizProjects';
      } else {
        _projectRoot = '${Platform.environment['HOME']}/NavigwizProjects';
      }
    } catch (_) {
      _projectRoot = '${Directory.systemTemp.path}/NavigwizProjects';
    }
    pp.setProjectRoot(_projectRoot);
    pp.refreshFiles(_projectRoot);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Project search bar: filters local files AND fetches an AI Overview first
  /// (same behavior as every other search bar in the app).
  Future<void> _onProjectSearch(String value) async {
    final q = value.trim().toLowerCase();
    setState(() {
      _searchQuery = q;
      _projectAiAnswer = '';
      _projectAiSources = const [];
      _projectAiLoading = q.length >= 3;
    });
    if (q.length < 3) return;
    try {
      final aiService = Provider.of<AIService>(context, listen: false);
      final res = await aiService.searchWithOverview(value.trim(),
          forceRefresh: false, waitForAi: true);
      if (!mounted) return;
      setState(() {
        _projectAiAnswer = res.aiAnswer;
        _projectAiSources = res.results.take(5).toList();
        _projectAiLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _projectAiLoading = false);
    }
  }

  Future<void> _createFromTemplate(String template) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    String content = '';
    switch (template) {
      case 'txt':
        content = '$name\n';
        break;
      case 'json':
        content = '{\n  "name": "$name",\n  "version": "1.0.0"\n}\n';
        break;
      case 'html':
        content = '<!DOCTYPE html>\n<html lang="en">\n<head>\n'
            '<meta charset="UTF-8">\n<meta name="viewport" content="width=device-width, initial-scale=1.0">\n'
            '<title>$name</title>\n</head>\n<body>\n\n</body>\n</html>';
        break;
      case 'py':
        content = '# $name\n\n\ndef main():\n    pass\n\n\nif __name__ == "__main__":\n    main()\n';
        break;
      case 'md':
        content = '# $name\n\n';
        break;
      case 'dart':
        content = "// $name\n\nvoid main() {\n  print('Hello from $name!');\n}\n";
        break;
      case 'js':
        content = "// $name\n\nfunction main() {\n  console.log('Hello from $name!');\n}\n\nmain();\n";
        break;
    }

    final provider = Provider.of<ProjectProvider>(context, listen: false);
    await provider.createFile(_projectRoot, '$name.$template', template, content: content);
    _nameController.clear();
  }

  Future<void> _createFolder() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    await provider.createFolder(_projectRoot, name);
    _nameController.clear();
    if (mounted) Navigator.pop(context);
  }

  void _showQuickCreateSheet() {
    _nameController.clear();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Create New Project File',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 6),
              Text('Files are stored on your device',
                style: TextStyle(fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'File or folder name...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 20),
              Text('Quick Templates',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _TemplateChip(icon: Icons.folder_outlined, label: 'Folder', onTap: _createFolder),
                  _TemplateChip(icon: Icons.text_snippet_outlined, label: 'Text', onTap: () => _createFromTemplate('txt')),
                  _TemplateChip(icon: Icons.code_outlined, label: 'HTML', onTap: () => _createFromTemplate('html')),
                  _TemplateChip(icon: Icons.terminal_outlined, label: 'Python', onTap: () => _createFromTemplate('py')),
                  _TemplateChip(icon: Icons.description_outlined, label: 'Markdown', onTap: () => _createFromTemplate('md')),
                  _TemplateChip(icon: Icons.javascript_outlined, label: 'JavaScript', onTap: () => _createFromTemplate('js')),
                  _TemplateChip(icon: Icons.dangerous_outlined, label: 'Dart', onTap: () => _createFromTemplate('dart')),
                  _TemplateChip(icon: Icons.data_object_outlined, label: 'JSON', onTap: () => _createFromTemplate('json')),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateWithAi() async {
    final descriptionController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Generate with AI',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: descriptionController,
              autofocus: true,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Describe anything you want to build...\ne.g. "a Rust CLI todo app", "a Go REST API", "a Flutter weather app", "a Python ML script"...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style:
                  TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'AI picks the best language & stack for your idea automatically — any language, any framework.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (descriptionController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _generating = true);
    final aiService = Provider.of<AIService>(context, listen: false);
    final provider = Provider.of<ProjectProvider>(context, listen: false);

    try {
      // No language restriction: the AI infers the right language/stack
      // from the user's requirements.
      final result = await aiService.buildProjectAgent(
        descriptionController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _generating = false);

      if (result.project == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.response.isEmpty
              ? 'Could not generate a project'
              : result.response),
          duration: const Duration(seconds: 4),
        ));
        return;
      }

      final location = kIsWeb
          ? 'a folder you choose (the browser will ask permission)'
          : provider.defaultProjectRoot;
      final allowed = await confirmProjectSave(context, result.project!, location);
      if (!allowed || !mounted) return;

      final savedPath = await provider.saveAgentProject(result.project!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(kIsWeb
            ? savedPath
            : 'Project saved to $savedPath'),
        duration: const Duration(seconds: 4),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reach the AI service')));
    }
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
        title: const Text('Projects'),
        centerTitle: true,
        actions: [
          if (_generating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Generate with AI',
              onPressed: _generateWithAi,
            ),
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Open project folder',
            onPressed: () async {
              final path = await FilePicker.platform.getDirectoryPath();
              if (path == null || !context.mounted) return;
              final provider = Provider.of<ProjectProvider>(context, listen: false);
              setState(() => _projectRoot = path);
              provider.setProjectRoot(path);
              provider.refreshFiles(path);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _AiBanner(onGenerate: _generateWithAi, generating: _generating),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: NavSearchBar(
              controller: _searchController,
              hintText: 'Ask AI or search files?...',
              onSubmitted: _onProjectSearch,
              onSubmitPressed: () =>
                  _onProjectSearch(_searchController.text),
              onAttachPressed: _showQuickCreateSheet,
              onAttachmentsChanged: (files) {
                if (files.isNotEmpty && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Attached ${files.map((f) => f.name).join(', ')} — describe what to build with them.',
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ),
          if (_searchQuery.isNotEmpty &&
              (_projectAiLoading || _projectAiAnswer.isNotEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _ProjectAiOverview(
                loading: _projectAiLoading,
                answer: _projectAiAnswer,
                sources: _projectAiSources,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All', selected: _selectedType == 'all',
                  onTap: () => setState(() => _selectedType = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Files', selected: _selectedType == 'file',
                  onTap: () => setState(() => _selectedType = 'file'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Folders', selected: _selectedType == 'folder',
                  onTap: () => setState(() => _selectedType = 'folder'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Code', selected: _selectedType == 'code',
                  onTap: () => setState(() => _selectedType = 'code'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 10,
            child: Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          ),
          Expanded(
            child: Consumer<ProjectProvider>(
              builder: (ctx, pp, _) {
                var files = pp.files;
                if (_searchQuery.isNotEmpty) {
                  files = files
                      .where((f) => f.name.toLowerCase().contains(_searchQuery))
                      .toList();
                }
                if (_selectedType != 'all') {
                  if (_selectedType == 'code') {
                    files = files.where((f) =>
                        ['py', 'dart', 'js', 'html', 'css', 'json', 'xml', 'yaml'].contains(f.type)
                    ).toList();
                  } else if (_selectedType == 'file') {
                    files = files.where((f) => f.type != 'folder').toList();
                  } else {
                    files = files.where((f) => f.type == _selectedType).toList();
                  }
                }

                if (files.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      const Color(0xFF1A237E).withValues(alpha: 0.6),
                                      const Color(0xFF4A148C).withValues(alpha: 0.6),
                                    ]
                                  : [
                                      const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                      const Color(0xFF9333EA).withValues(alpha: 0.15),
                                    ],
                            ),
                          ),
                          child: const Icon(Icons.folder_open_outlined,
                              size: 44, color: Color(0xFF4F46E5)),
                        ),
                        const SizedBox(height: 20),
                        Text('No project files yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          )),
                        const SizedBox(height: 8),
                        Text('Tap + to create your first file or folder',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _showQuickCreateSheet,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Create New'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _generateWithAi,
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('Create Project with AI'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: files.length,
                  itemBuilder: (ctx, i) {
                    final file = files[i];
                    final isFolder = file.type == 'folder';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFolder
                                ? Colors.amber.withValues(alpha: 0.15)
                                : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isFolder ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                            color: isFolder ? Colors.amber[700] : Theme.of(context).colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        title: Text(file.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          )),
                        subtitle: Text(
                          isFolder
                              ? 'Folder'
                              : '${(file.size / 1024).toStringAsFixed(1)} KB  |  .${file.type}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                        trailing: PopupMenuButton(
                          icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[500]),
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              child: const Row(children: [
                                Icon(Icons.open_in_new, size: 18), SizedBox(width: 8), Text('Open')
                              ]),
                              onTap: () => pp.openFile(file.path),
                            ),
                            PopupMenuItem(
                              child: const Row(children: [
                                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))
                              ]),
                              onTap: () => pp.deleteFile(file.id),
                            ),
                          ],
                        ),
                        onTap: () => pp.openFile(file.path),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickCreateSheet,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TemplateChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

/// AI Overview card for the Projects search bar: AI answer first, then links.
class _ProjectAiOverview extends StatelessWidget {
  final bool loading;
  final String answer;
  final List<SearchResult> sources;

  const _ProjectAiOverview({
    required this.loading,
    required this.answer,
    required this.sources,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.12),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(5),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome,
                        size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(loading ? 'AI Overview — answering…' : 'AI Overview',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            Text('Getting the latest answer for you…',
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant))
          else
            Text(answer,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: theme.colorScheme.onSurface)),
          if (!loading && sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sources.map((s) {
                String host = s.url;
                try {
                  host = Uri.parse(s.url).host.replaceFirst('www.', '');
                } catch (_) {}
                return ActionChip(
                  avatar: Icon(Icons.link,
                      size: 12, color: theme.colorScheme.primary),
                  label: Text(host,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    try {
                      Provider.of<BrowserService>(context, listen: false)
                          .navigateToUrl(s.url);
                    } catch (_) {}
                  },
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiBanner extends StatelessWidget {
  final VoidCallback onGenerate;
  final bool generating;

  const _AiBanner({
    required this.onGenerate,
    required this.generating,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A237E).withValues(alpha: 0.9),
                  const Color(0xFF4A148C).withValues(alpha: 0.9),
                ]
              : [
                  const Color(0xFF4F46E5),
                  const Color(0xFF9333EA),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.35 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Build anything with AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Describe an app or website and get a full project folder',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: generating ? null : onGenerate,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4F46E5),
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: generating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                  )
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(generating ? 'Generating' : 'Create Project'),
          ),
        ],
      ),
    );
  }
}
