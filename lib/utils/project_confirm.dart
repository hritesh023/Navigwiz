import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/agent_response.dart';

/// opencode-style permission prompt shown before project files are created.
///
/// On web the browser folder picker is the permission gate, so this returns
/// true immediately. On desktop/mobile the user is asked to allow Navigwiz to
/// create the project in the given folder.
Future<bool> confirmProjectSave(
    BuildContext context, AgentProject project, String location) async {
  if (kIsWeb) return true;

  final allowed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(Icons.folder_copy_outlined,
          size: 32, color: Theme.of(context).colorScheme.primary),
      title: Text('Allow Navigwiz to create this project?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The AI will create '
            '${project.files.length} file${project.files.length == 1 ? '' : 's'} '
            'for "${project.name.isEmpty ? 'Untitled project' : project.name}" in:',
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              location,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Files are created for real on your device. You can change the folder anytime.',
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Deny')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow')),
      ],
    ),
  );
  return allowed ?? false;
}
