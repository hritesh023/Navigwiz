import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../services/browser_service.dart';
import '../services/theme_service.dart';
import '../widgets/color_picker_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: Consumer<SettingsProvider>(
        builder: (ctx, sp, _) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SettingsHeader(),
              const SizedBox(height: 20),
              const _SectionHeader(title: 'AI ASSISTANT'),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.smart_toy_outlined,
                          color: Theme.of(context).colorScheme.primary, size: 22),
                      ),
                      title: const Text('Assistant Name'),
                      subtitle: Text(sp.aiAssistantName,
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => _editAssistantName(context, sp),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(title: 'ACCOUNT'),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.person_outline,
                          color: Theme.of(context).colorScheme.primary, size: 22),
                      ),
                      title: const Text('Display Name'),
                      subtitle: Text(sp.userDisplayName.isNotEmpty ? sp.userDisplayName : 'Not set',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => _editDisplayName(context, sp),
                    ),
                    Divider(height: 1, indent: 72, color: Theme.of(context).dividerColor),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.email_outlined,
                          color: Theme.of(context).colorScheme.primary, size: 22),
                      ),
                      title: const Text('Email'),
                      subtitle: Text(sp.userEmail.isNotEmpty ? sp.userEmail : 'Not set',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => _editEmail(context, sp),
                    ),
                    Divider(height: 1, indent: 72, color: Theme.of(context).dividerColor),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.logout, color: Colors.red[400], size: 22),
                      ),
                      title: Text('Sign Out', style: TextStyle(color: Colors.red[400])),
                      subtitle: const Text('Return to login screen',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                      onTap: () => _confirmSignOut(context, sp),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(title: 'EXTENSIONS'),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    ...sp.extensions.asMap().entries.map((entry) => ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.extension_outlined,
                          color: Theme.of(context).colorScheme.primary, size: 22),
                      ),
                      title: Text(entry.value['name'] ?? ''),
                      subtitle: Text(entry.value['path'] ?? '',
                        style: const TextStyle(fontSize: 12)),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
                        onPressed: () => sp.removeExtension(entry.key),
                      ),
                    )),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.add_rounded,
                          color: Theme.of(context).colorScheme.primary, size: 22),
                      ),
                      title: Text('Add Extension',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                      onTap: () => _addExtension(context, sp),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(title: 'SEARCH ENGINE'),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    _SearchEngineOption(
                      icon: Icons.auto_awesome,
                      title: 'Navigwiz Agentic Search',
                      subtitle:
                          'AI-curated results with instant answers, fully powered by the Navigwiz AI engine',
                      selected: !sp.useGoogleSearch,
                      onTap: () => _setSearchEngine(context, sp, 'navigwiz'),
                    ),
                    Divider(height: 1, indent: 72, color: Theme.of(context).dividerColor),
                    _SearchEngineOption(
                      icon: Icons.public,
                      title: 'Google Search',
                      subtitle: 'Search directly on Google instead of the Navigwiz AI',
                      selected: sp.useGoogleSearch,
                      onTap: () => _setSearchEngine(context, sp, 'google'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(title: 'BROWSER'),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.block,
                            color: Theme.of(context).colorScheme.primary, size: 22),
                      ),
                      title: const Text('Ad Blocker'),
                      subtitle: const Text('Hide ads while browsing',
                          style: TextStyle(fontSize: 12)),
                      value: sp.adBlockEnabled,
                      onChanged: (v) => sp.setAdBlockEnabled(v),
                    ),
                    Divider(height: 1, indent: 72, color: Theme.of(context).dividerColor),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.home_outlined,
                            color: Theme.of(context).colorScheme.primary, size: 22),
                      ),
                      title: const Text('Homepage'),
                      subtitle: Text(
                        sp.homepageUrl.isEmpty ? 'Navigwiz home' : sp.homepageUrl,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => _editHomepage(context, sp),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(title: 'PRIVACY'),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.history,
                            color: Theme.of(context).colorScheme.primary, size: 22),
                      ),
                      title: const Text('Clear History'),
                      subtitle: const Text('Remove all browsing history',
                          style: TextStyle(fontSize: 12)),
                      onTap: () => _confirmClearData(
                          context, 'history', 'Clear all browsing history?', () {
                        Provider.of<BrowserService>(context, listen: false)
                            .clearHistory();
                      }),
                    ),
                    Divider(height: 1, indent: 72, color: Theme.of(context).dividerColor),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.bookmarks_outlined,
                            color: Theme.of(context).colorScheme.primary, size: 22),
                      ),
                      title: const Text('Clear Bookmarks'),
                      subtitle: const Text('Remove all saved bookmarks',
                          style: TextStyle(fontSize: 12)),
                      onTap: () => _confirmClearData(
                          context, 'bookmarks', 'Clear all bookmarks?', () {
                        Provider.of<BrowserService>(context, listen: false)
                            .clearBookmarks();
                      }),
                    ),
                    Divider(height: 1, indent: 72, color: Theme.of(context).dividerColor),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.delete_sweep_outlined,
                            color: Colors.red[400], size: 22),
                      ),
                      title: Text('Clear All Browsing Data',
                          style: TextStyle(color: Colors.red[400])),
                      subtitle: const Text('Cookies, cache, history and bookmarks',
                          style: TextStyle(fontSize: 12)),
                      onTap: () => _confirmClearData(
                          context, 'all data', 'Clear cookies, cache, history and bookmarks?', () {
                        Provider.of<BrowserService>(context, listen: false)
                            .clearAllBrowsingData();
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(title: 'THEME'),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Theme.of(context).brightness == Brightness.dark
                              ? Icons.light_mode
                              : Icons.dark_mode,
                          color: Theme.of(context).colorScheme.primary, size: 22,
                        ),
                      ),
                      title: Text(Theme.of(context).brightness == Brightness.dark
                          ? 'Dark Mode' : 'Light Mode'),
                      value: Theme.of(context).brightness == Brightness.dark,
                      onChanged: (val) {
                        final themeService = Provider.of<ThemeService>(context, listen: false);
                        themeService.toggleTheme();
                        sp.setDarkMode(themeService.isDarkMode);
                      },
                    ),
                    Divider(height: 1, indent: 72, color: Theme.of(context).dividerColor),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Accent Color',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Consumer<ThemeService>(
                        builder: (context, themeService, _) {
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ...ThemeService.predefinedColors.map((color) {
                                final isSelected = color.toARGB32() ==
                                    themeService.primaryColor.toARGB32();
                                return GestureDetector(
                                  onTap: () => themeService.setPrimaryColor(color),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color: Theme.of(context).colorScheme.onSurface,
                                              width: 2)
                                          : null,
                                    ),
                                    child: isSelected
                                        ? Icon(Icons.check,
                                            size: 18,
                                            color: Theme.of(context).colorScheme.onPrimary)
                                        : null,
                                  ),
                                );
                              }),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showAccentColorPicker(
                                      context, themeService.primaryColor);
                                  if (picked != null) {
                                    themeService.setPrimaryColor(picked);
                                  }
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.red, Colors.green, Colors.blue],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.colorize,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Divider(height: 24, indent: 72, color: Theme.of(context).dividerColor),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Background',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickBackgroundImage(context, false),
                                  icon: const Icon(Icons.image_outlined, size: 16),
                                  label: const Text('Image', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickBackgroundImage(context, true),
                                  icon: const Icon(Icons.gif_box_outlined, size: 16),
                                  label: const Text('GIF', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Consumer<ThemeService>(
                            builder: (context, themeService, _) {
                              if (!themeService.hasBackgroundMedia) {
                                return const SizedBox.shrink();
                              }
                              return TextButton.icon(
                                onPressed: () => themeService.removeBackgroundImage(),
                                icon: const Icon(Icons.delete_outline, size: 16),
                                label: const Text('Remove background',
                                    style: TextStyle(fontSize: 12)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Navigwiz v2.0.0',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI-Native Digital Companion',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _setSearchEngine(BuildContext context, SettingsProvider sp, String engine) {
    sp.setSearchEngine(engine);
    Provider.of<BrowserService>(context, listen: false).setSearchEngine(engine);
  }

  void _editAssistantName(BuildContext context, SettingsProvider sp) {
    final controller = TextEditingController(text: sp.aiAssistantName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Name Your AI Assistant',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Athena, Jarvis, Nova...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.smart_toy_outlined, size: 20),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              sp.setAiAssistantName(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editDisplayName(BuildContext context, SettingsProvider sp) {
    final controller = TextEditingController(text: sp.userDisplayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Display Name',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter your display name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.person_outline, size: 20),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              sp.setUserDisplayName(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editEmail(BuildContext context, SettingsProvider sp) {
    final controller = TextEditingController(text: sp.userEmail);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Email',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Enter your email',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              sp.setUserEmail(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, SettingsProvider sp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Are you sure you want to sign out?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[400]),
            onPressed: () {
              sp.signOut();
              Navigator.pop(ctx);
              Provider.of<AuthProvider>(context, listen: false).signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _editHomepage(BuildContext context, SettingsProvider sp) {
    final controller = TextEditingController(text: sp.homepageUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Homepage',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'https://example.com',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.home_outlined, size: 20),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              sp.setHomepageUrl(value);
              Provider.of<BrowserService>(context, listen: false)
                  .setHomepageUrl(value);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData(
      BuildContext context, String label, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear $label?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(message,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[400]),
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBackgroundImage(BuildContext context, bool isGif) async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final result = await FilePicker.platform.pickFiles(
      type: isGif ? FileType.custom : FileType.image,
      allowedExtensions: isGif ? ['gif'] : null,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      try {
        bytes = await File(file.path!).readAsBytes();
      } catch (_) {}
    }
    if (bytes == null) return;
    await themeService.setBackgroundImageBytes(bytes, path: file.path);
  }

  void _addExtension(BuildContext context, SettingsProvider sp) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final nameController = TextEditingController(text: file.name);

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Add Extension',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            content: TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Extension name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.extension_outlined, size: 20),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  sp.addExtension(nameController.text.trim(), file.path ?? '');
                  Navigator.pop(ctx);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      }
    }
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.22),
            primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.tune, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Navigwiz Settings',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: onSurface)),
                const SizedBox(height: 3),
                Text(
                    'Make the browser yours — search, privacy, theme and your AI companion.',
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _SearchEngineOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SearchEngineOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? primary.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? primary.withValues(alpha: 0.16)
                      : primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? primary : Theme.of(context).dividerColor,
                    width: 2,
                  ),
                  color: selected ? primary : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
