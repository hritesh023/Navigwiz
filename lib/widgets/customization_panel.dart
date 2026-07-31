import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/theme_service.dart';
import 'color_picker_dialog.dart';

class CustomizationPanel extends StatelessWidget {
  final VoidCallback onClose;

  const CustomizationPanel({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Icon(Icons.palette,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Customize',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _SectionLabel(label: 'THEME'),
                _buildDarkModeTile(context, themeService),
                const SizedBox(height: 16),
                const _SectionLabel(label: 'ACCENT COLOR'),
                _buildColorSwatches(context, themeService),
                const SizedBox(height: 8),
                _buildCustomColorButton(context, themeService),
                const SizedBox(height: 16),
                const _SectionLabel(label: 'BACKGROUND'),
                _buildBackgroundPreview(context, themeService),
                const SizedBox(height: 10),
                _buildBackgroundActions(context, themeService),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkModeTile(BuildContext context, ThemeService themeService) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(themeService.isDarkMode ? 'Dark Mode' : 'Light Mode',
            style: TextStyle(
                fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
        value: themeService.isDarkMode,
        onChanged: (val) {
          themeService.setDarkMode(val);
          Provider.of<SettingsProvider>(context, listen: false)
              .setDarkMode(val);
        },
      ),
    );
  }

  Widget _buildColorSwatches(BuildContext context, ThemeService themeService) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ThemeService.predefinedColors.map((color) {
        final isSelected = color.toARGB32() == themeService.primaryColor.toARGB32();
        return GestureDetector(
          onTap: () => themeService.setPrimaryColor(color),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? Icon(Icons.check,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimary)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomColorButton(
      BuildContext context, ThemeService themeService) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () async {
          final picked = await showAccentColorPicker(
              context, themeService.primaryColor);
          if (picked != null) {
            themeService.setPrimaryColor(picked);
          }
        },
        icon: const Icon(Icons.colorize, size: 16),
        label: const Text('Custom color', style: TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildBackgroundPreview(
      BuildContext context, ThemeService themeService) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
        image: themeService.hasBackgroundMedia
            ? DecorationImage(
                image: MemoryImage(themeService.backgroundImageBytes!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: themeService.hasBackgroundMedia
          ? null
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wallpaper,
                      size: 28, color: Colors.grey[500]),
                  const SizedBox(height: 4),
                  Text('No background image',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
    );
  }

  Widget _buildBackgroundActions(
      BuildContext context, ThemeService themeService) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(context, themeService),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Image', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickGif(context, themeService),
                icon: const Icon(Icons.gif_box_outlined, size: 16),
                label: const Text('GIF', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        if (themeService.hasBackgroundMedia) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => themeService.removeBackgroundImage(),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Remove background',
                  style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickImage(
      BuildContext context, ThemeService themeService) async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final bytes = await _readBytes(result.files.first);
    if (bytes == null) return;
    themeService.setBackgroundImageBytes(bytes,
        path: result.files.first.path);
  }

  Future<void> _pickGif(
      BuildContext context, ThemeService themeService) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gif'],
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = await _readBytes(result.files.first);
    if (bytes == null) return;
    themeService.setBackgroundImageBytes(bytes,
        path: result.files.first.path);
  }

  Future<Uint8List?> _readBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    if (file.path != null) {
      try {
        return await File(file.path!).readAsBytes();
      } catch (_) {}
    }
    return null;
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
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

