import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/project_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _initProjectRoot();
  }

  void _initProjectRoot() {
    try {
      if (Platform.isWindows) {
        _projectRoot = '${Platform.environment['USERPROFILE']}\\NavigwizProjects';
      } else {
        _projectRoot = '${Platform.environment['HOME']}/NavigwizProjects';
      }
    } catch (_) {
      _projectRoot = '${Directory.systemTemp.path}/NavigwizProjects';
    }
    final pp = Provider.of<ProjectProvider>(context, listen: false);
    pp.setProjectRoot(_projectRoot);
    pp.refreshFiles(_projectRoot);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createFromTemplate(String template) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    String content = '';
    switch (template) {
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey[900]!.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark
                      ? Colors.grey[700]!.withValues(alpha: 0.5)
                      : Colors.grey[300]!.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : Colors.grey[400]!)
                        .withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search, color: Colors.grey[500]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search or create files...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Create new file/folder',
                    onPressed: _showQuickCreateSheet,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
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
                        Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[500]),
                        const SizedBox(height: 16),
                        Text('No project files yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                        const SizedBox(height: 8),
                        Text('Tap + to create your first file or folder',
                          style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _showQuickCreateSheet,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Create New'),
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
