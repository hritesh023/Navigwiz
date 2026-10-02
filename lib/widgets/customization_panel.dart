import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/background_picker.dart';
import '../services/theme_service.dart';
import 'background_crop_dialog.dart';
import 'color_picker_dialog.dart';

/// Customize panel: theme mode, accent color, and new-tab background.
///
/// Picker flow (ported from Equyvo's `ChatThemeSelector`):
/// browser `<input type=file accept="image/*,.gif">` + data-URL read on web
/// (no `file_picker`, so the web "use bytes instead" crash is impossible)
/// -> MIME/size precheck -> validate/compress via
/// [ThemeService.prepareBackgroundBytes] (stored in the user's local
/// storage via SharedPreferences, like Equyvo's `chat-theme` localStorage
/// key) -> crop dialog -> Done applies.
class CustomizationPanel extends StatefulWidget {
  final VoidCallback onClose;

  const CustomizationPanel({super.key, required this.onClose});

  @override
  State<CustomizationPanel> createState() => _CustomizationPanelState();
}

class _CustomizationPanelState extends State<CustomizationPanel> {
  bool _busy = false;
  String? _busyKind; // 'image' | 'gif'

  // ------------------------------------------------------------------ UI --

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
          _buildHeader(theme),
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

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.palette, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Customize',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _busy ? null : widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkModeTile(
      BuildContext context, ThemeService themeService) {
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
        title: Text(
          themeService.isDarkMode ? 'Dark Mode' : 'Light Mode',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        value: themeService.isDarkMode,
        onChanged: (val) {
          themeService.setDarkMode(val);
          Provider.of<SettingsProvider>(context, listen: false)
              .setDarkMode(val);
        },
      ),
    );
  }

  Widget _buildColorSwatches(
      BuildContext context, ThemeService themeService) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ThemeService.predefinedColors.map((color) {
        final isSelected =
            color.toARGB32() == themeService.primaryColor.toARGB32();
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
                      color: Theme.of(context).colorScheme.onSurface, width: 2)
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
            context,
            themeService.primaryColor,
          );
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
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
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
                      errorBuilder: (_, __, ___) => _buildNoBackground(
                        message:
                            'Saved file is unreadable — pick a new one.',
                      ),
                    ),
                  ),
                ),
              )
            : _buildNoBackground(),
      ),
    );
  }

  Widget _buildNoBackground({String message = 'No background image'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wallpaper, size: 28, color: Colors.grey[500]),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
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
                onPressed: _busy
                    ? null
                    : () => _pickBackground(
                          context,
                          themeService,
                          gifOnly: false,
                        ),
                icon: _busy && _busyKind == 'image'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined, size: 16),
                label: const Text('Image', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _pickBackground(
                          context,
                          themeService,
                          gifOnly: true,
                        ),
                icon: _busy && _busyKind == 'gif'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gif_box_outlined, size: 16),
                label: const Text('GIF', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed:
              _busy ? null : () => _applyBackground(context, themeService),
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
              : 'Pick an image or GIF, adjust its frame, then press Apply.\nJPG, PNG, GIF or WebP up to 12 MB.',
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
                onPressed:
                    _busy ? null : () => _adjustFraming(context, themeService),
                icon: const Icon(Icons.crop_free, size: 16),
                label: const Text('Adjust framing',
                    style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed:
                    _busy ? null : () => themeService.removeBackgroundImage(),
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

  // ---------------------------------------------------------- picker flow --

  Future<void> _applyBackground(
    BuildContext context,
    ThemeService themeService,
  ) async {
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
      await _pickBackground(context, themeService, gifOnly: false);
    }
  }

  /// Single unified picker, ported from Equyvo's `ChatThemeSelector`:
  /// the browser's own `<input type=file>` + data-URL read on web, so no
  /// `PlatformFile` (and its throwing `.path`) is ever involved.
  Future<void> _pickBackground(
    BuildContext context,
    ThemeService themeService, {
    required bool gifOnly,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyKind = gifOnly ? 'gif' : 'image';
    });
    try {
      late final PickedBackground? picked;
      try {
        picked = await pickBackgroundImage(gifOnly: gifOnly);
      } catch (e) {
        _showError(_friendlyPickError(e, gifOnly ? 'GIF background' : 'background'));
        return;
      }
      if (picked == null) return; // user cancelled

      final precheck = _precheckPicked(picked, gifOnly: gifOnly);
      if (precheck != null) {
        _showError(precheck);
        return;
      }

      final raw = picked.bytes;
      if (raw.isEmpty) {
        _showError('Selected file is empty.');
        return;
      }

      if (gifOnly && !ThemeService.isGifBytes(raw)) {
        _showError(
          'That file is not a GIF (it may have been renamed). Please pick a real .gif file, or use Image for photos.',
        );
        return;
      }

      if (!context.mounted) return;
      await _prepareAndCrop(
        context,
        themeService,
        raw,
        displayName: picked.name,
        kindLabel: gifOnly ? 'Animated background' : 'Background',
      );
    } catch (e) {
      _showError(_friendlyPickError(e, gifOnly ? 'GIF background' : 'background'));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyKind = null;
        });
      } else {
        _busy = false;
        _busyKind = null;
      }
    }
  }

  /// Cheap checks before the expensive decode: extension, size, emptiness.
  /// Mirrors Equyvo's `processFile` guards (MIME/size) plus our quota caps.
  String? _precheckPicked(PickedBackground picked, {required bool gifOnly}) {
    final name = picked.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    if (gifOnly) {
      if (ext != 'gif' && picked.mimeType != 'image/gif') {
        return 'Please pick a .gif file for animated backgrounds (or use Image for photos).';
      }
    } else if (ext.isNotEmpty &&
        !ThemeService.supportedImageExtensions.contains(ext)) {
      return '“.$ext” is not supported. Please pick a JPG, PNG, GIF or WebP image.';
    }
    if (picked.size > ThemeService.maxDecodeBytes || picked.bytes.lengthInBytes > ThemeService.maxDecodeBytes) {
      return 'That file is too large. Please pick an image/GIF under 12 MB.';
    }
    if (picked.bytes.isEmpty) {
      return 'Selected file is empty.';
    }
    return null;
  }

  /// Compress first, then preview: the crop dialog shows exactly what will
  /// be saved, so preview and save can never disagree.
  Future<void> _prepareAndCrop(
    BuildContext context,
    ThemeService themeService,
    Uint8List raw, {
    required String displayName,
    required String kindLabel,
  }) async {
    // Let the progress indicator paint before the heavy decode blocks the
    // UI thread (on web the spinner would otherwise never appear).
    var progressShowing = false;
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      progressShowing = true;
      await Future.delayed(const Duration(milliseconds: 60));
    }

    late final Uint8List prepared;
    try {
      prepared = await themeService.prepareBackgroundBytes(
        raw,
        fileName: displayName,
      );
    } catch (e) {
      if (progressShowing && context.mounted) {
        _popProgress(context);
      }
      if (mounted) _showError(_friendlyPickError(e, kindLabel));
      return;
    }
    if (progressShowing && context.mounted) {
      _popProgress(context);
    }
    if (!context.mounted) return;
    await _showCropAndApply(
      context,
      themeService,
      prepared,
      displayName: displayName,
      kindLabel: kindLabel,
    );
  }

  void _popProgress(BuildContext context) {
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
  }

  Future<void> _showCropAndApply(
    BuildContext context,
    ThemeService themeService,
    Uint8List bytes, {
    required String displayName,
    required String kindLabel,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackgroundCropDialog(
        bytes: bytes,
        onApply: (zoom, offsetX, offsetY) async {
          // `displayName` is metadata only (file name on web, native path
          // elsewhere) — never dereferenced as a filesystem path on web.
          await themeService.applyPreparedBackground(bytes, path: displayName);
          await themeService.setBackgroundFraming(
            zoom: zoom,
            offsetX: offsetX,
            offsetY: offsetY,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$kindLabel applied'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _adjustFraming(
    BuildContext context,
    ThemeService themeService,
  ) async {
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
            zoom: zoom,
            offsetX: offsetX,
            offsetY: offsetY,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Background framing updated')),
            );
          }
        },
      ),
    );
  }

  // --------------------------------------------------------------- errors --

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  /// One friendly line for every failure. In particular the old web crash
  /// (`PlatformFile.path` → "use bytes instead") is mapped to an actionable
  /// message instead of leaking plugin internals.
  String _friendlyPickError(Object e, String what) {
    final raw = e
        .toString()
        .replaceFirst(RegExp(r'^(Exception|StateError|ArgumentError):\s*'), '');
    if (raw.contains('bytes` property instead') ||
        raw.contains('Picking paths is unsupported')) {
      return 'Could not read that file in this browser. Please try again or pick a smaller JPG, PNG, GIF or WebP image.';
    }
    if (raw.contains('storage full') ||
        raw.contains('QuotaExceeded') ||
        raw.contains('quota')) {
      return 'Could not save $what (browser storage full). Try a smaller image or remove the old background first.';
    }
    if (e is StateError || e is ArgumentError) return raw;
    if (raw.contains('permission') || raw.contains('denied')) {
      return 'Permission denied while reading the file. Please try again or pick another file.';
    }
    return 'Could not set $what: $raw';
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
