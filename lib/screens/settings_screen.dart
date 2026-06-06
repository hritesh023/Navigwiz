import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../services/theme_service.dart';

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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
              const _SectionHeader(title: 'THEME'),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: SwitchListTile(
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
          );
        },
      ),
    );
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
