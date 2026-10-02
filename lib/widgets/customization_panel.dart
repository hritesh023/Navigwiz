import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/background_file_reader.dart';
import '../services/theme_service.dart';
import 'color_picker_dialog.dart';
import 'background_crop_dialog.dart';

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
    final hasMedia = themeService.hasBackgroundMedia &&
        themeService.backgroundImageBytes != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
        ),
        child: hasMedia
            ? ClipRect(
                child: Transform.translate(
                  offset: Offset(
                    themeService.backgroundOffsetX * 50,
                    themeService.backgroundOffsetY * 30,
                  ),
                  child: Transform.scale(
                    scale: themeService.backgroundZoom,
                    child: Image.memory(
                      themeService.backgroundImageBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => _buildNoBackground(),
                    ),
                  ),
                ),
              )
            : _buildNoBackground(),
      ),
    );
  }

  Widget _buildNoBackground() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wallpaper, size: 28, color: Colors.grey[500]),
          const SizedBox(height: 4),
          Text('No background image',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildBackgroundActions(
      BuildContext context, ThemeService themeService) {
    final hasMedia = themeService.hasBackgroundMedia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        const SizedBox(height: 8),
        // Explicit success button: with a background set it opens the
        // crop/adjust dialog (drag to pan, slider to zoom, Apply to
        // confirm); with none set it starts the image picker.
        FilledButton.icon(
          onPressed: () => _applyBackground(context, themeService),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: Text(
            hasMedia ? 'Apply background' : 'Choose & apply background',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hasMedia
              ? 'Background shows on the new-tab page. Use Apply to crop/adjust its frame.'
              : 'Pick an image or GIF, adjust its frame, then press Apply.',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (hasMedia) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () => _adjustFraming(context, themeService),
                icon: const Icon(Icons.crop_free, size: 16),
                label: const Text('Adjust framing',
                    style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: () => themeService.removeBackgroundImage(),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remove background',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Explicit panel-level Apply: re-opens the crop/adjust dialog for the
  /// current background (pan/zoom + Apply = success), or starts the picker
  /// when nothing is set yet.
  Future<void> _applyBackground(
      BuildContext context, ThemeService themeService) async {
    if (themeService.hasBackgroundMedia &&
        themeService.backgroundImageBytes != null) {
      await _adjustFraming(context, themeService);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background applied'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      await _pickImage(context, themeService);
    }
  }

  Future<void> _pickImage(
      BuildContext context, ThemeService themeService) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final raw = await _readBytes(result.files.first);
      if (raw == null || raw.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read that file.')),
          );
        }
        return;
      }
      if (context.mounted) {
        await _prepareAndCrop(
          context,
          themeService,
          raw,
          path: result.files.first.path ?? result.files.first.name,
          kindLabel: 'Background',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set background: $e')),
        );
      }
    }
  }

  Future<void> _pickGif(
      BuildContext context, ThemeService themeService) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gif'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final raw = await _readBytes(result.files.first);
      if (raw == null || raw.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read that GIF.')),
          );
        }
        return;
      }
      if (context.mounted) {
        await _prepareAndCrop(
          context,
          themeService,
          raw,
          path: result.files.first.path ?? result.files.first.name,
          kindLabel: 'Animated background',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set GIF background: $e')),
        );
      }
    }
  }

  /// Compresses FIRST, then previews: the crop dialog shows exactly what
  /// will be saved, so a preview that renders but a save that fails (quota
  /// errors, oversized GIFs) can no longer disagree with each other.
  Future<void> _prepareAndCrop(
    BuildContext context,
    ThemeService themeService,
    Uint8List raw, {
    required String path,
    required String kindLabel,
  }) async {
    final navigator = Navigator.of(context);
    // Big GIFs can take a few seconds to downscale on web — show progress
    // first (the heavy work below blocks the UI thread once started).
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    late final Uint8List prepared;
    try {
      prepared = await themeService.prepareBackgroundBytes(raw);
    } finally {
      try {
        if (navigator.canPop()) navigator.pop();
      } catch (_) {}
    }
    if (!context.mounted) return;
    await _showCropAndApply(
      context,
      themeService,
      prepared,
      path: path,
      kindLabel: kindLabel,
    );
  }

  Future<void> _showCropAndApply(
    BuildContext context,
    ThemeService themeService,
    Uint8List bytes, {
    required String path,
    required String kindLabel,
  }) async {
    // [bytes] must already be prepared (quota-safe) via prepareBackgroundBytes
    // so the dialog previews exactly what Apply will save.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackgroundCropDialog(
        bytes: bytes,
        onApply: (zoom, offsetX, offsetY) async {
          await themeService.applyPreparedBackground(bytes, path: path);
          await themeService.setBackgroundFraming(
              zoom: zoom, offsetX: offsetX, offsetY: offsetY);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('$kindLabel applied'),
                  duration: const Duration(seconds: 2)),
            );
          }
        },
      ),
    );
  }

  Future<void> _adjustFraming(
      BuildContext context, ThemeService themeService) async {
    final bytes = themeService.backgroundImageBytes;
    if (bytes == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackgroundCropDialog(
        bytes: bytes,
        initialZoom: themeService.backgroundZoom,
        initialOffsetX: themeService.backgroundOffsetX,
        initialOffsetY: themeService.backgroundOffsetY,
        onApply: (zoom, offsetX, offsetY) async {
          await themeService.setBackgroundFraming(
              zoom: zoom, offsetX: offsetX, offsetY: offsetY);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Background framing updated')),
            );
          }
        },
      ),
    );
  }

  Future<Uint8List?> _readBytes(PlatformFile file) async {
    // Preferred: bytes straight from the picker (works on web + desktop).
    if (file.bytes != null && file.bytes!.isNotEmpty) return file.bytes;
    // Native fallback: the picker sometimes returns only a path (large
    // files, platform quirks). Web-safe — the io implementation is only
    // linked on platforms with dart:io, otherwise this returns null.
    try {
      return await readBackgroundFileBytes(file.path);
    } catch (_) {
      return null;
    }
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

