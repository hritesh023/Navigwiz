import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/camera_screen.dart';
import 'speech_service.dart';

/// Shared voice / camera / attach behaviors used by EVERY search bar in
/// Navigwiz (home search, address bar, research, projects, workspace,
/// private browser, Acronous AI chat). Functions mirror the Acronous AI app:
/// mic dictates into the field, camera captures/shows a picture to ask about,
/// "+" attaches files/folders/pictures/video/audio for reference/convert.
class InputActions {
  static final SpeechService _speech = SpeechService();
  static bool _listening = false;

  static bool get isListening => _listening;

  /// Toggles voice dictation into [controller]. Returns true while listening.
  /// [onState] is called on start/stop so the caller can repaint its mic icon.
  static Future<bool> toggleVoice(
    BuildContext context,
    TextEditingController controller, {
    void Function(bool listening)? onState,
  }) async {
    if (_listening) {
      _speech.stopListening();
      _listening = false;
      onState?.call(false);
      return false;
    }
    try {
      final available = await _speech.initialize();
      if (!available) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice input is not available on this device.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return false;
      }
      _listening = true;
      onState?.call(true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listening... speak now, tap mic to stop.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      await _speech.startListening(onResult: (result) {
        try {
          final words = (result.recognizedWords as String?) ?? '';
          if (words.isNotEmpty) {
            controller.text = words;
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          }
          if ((result.finalResult as bool?) == true) {
            _listening = false;
            onState?.call(false);
          }
        } catch (_) {}
      });
      return true;
    } catch (_) {
      _listening = false;
      onState?.call(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start voice input.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }
  }

  static void stopVoice({void Function(bool listening)? onState}) {
    try {
      _speech.stopListening();
    } catch (_) {}
    _listening = false;
    onState?.call(false);
  }

  /// Camera flow (mirrors Acronous AI app): opens the in-app camera; on
  /// platforms without a camera falls back to gallery. Returns the captured
  /// image path, or null when cancelled/unavailable.
  static Future<String?> captureWithCamera(BuildContext context) async {
    // Try the full camera screen first (mobile/desktop).
    try {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
      if (result is (String?, CameraResult)) {
        if (result.$2 == CameraResult.success && result.$1 != null) {
          return result.$1;
        }
        if (result.$2 == CameraResult.cancelled) return null;
      } else if (result is String) {
        return result;
      }
    } catch (_) {}
    // Fallback: gallery picker (also what web uses for "camera").
    return pickGalleryImage();
  }

  static Future<String?> pickGalleryImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      return image?.path;
    } catch (_) {
      return null;
    }
  }

  static void showCameraSheet(
    BuildContext context, {
    required ValueChanged<String> onImage,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Ask with your camera',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Show a picture and ask about it.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SheetOption(
                    icon: Icons.photo_camera_outlined,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final path = await captureWithCamera(context);
                      if (path != null && context.mounted) onImage(path);
                    },
                  ),
                  _SheetOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final path = await pickGalleryImage();
                      if (path != null && context.mounted) onImage(path);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// "+" flow (mirrors Acronous AI app): attach files/folders/pictures/video/
  /// audio/links and ask about them (modify, reference, convert, ...).
  static void showAttachSheet(
    BuildContext context, {
    required ValueChanged<List<PickedAttachment>> onPicked,
  }) {
    showModalBottomSheet(
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Attach to ask',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Attach any file, folder, picture, video or audio.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _SheetOption(
                    icon: Icons.insert_drive_file_outlined,
                    label: 'Files',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final files = await pickFiles(FileType.any);
                      if (files.isNotEmpty && context.mounted) onPicked(files);
                    },
                  ),
                  if (!kIsWeb)
                    _SheetOption(
                      icon: Icons.folder_outlined,
                      label: 'Folder',
                      onTap: () async {
                        Navigator.pop(ctx);
                        final folder = await pickFolder();
                        if (folder != null && context.mounted) {
                          onPicked([folder]);
                        }
                      },
                    ),
                  _SheetOption(
                    icon: Icons.image_outlined,
                    label: 'Images',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final files = await pickFiles(FileType.image);
                      if (files.isNotEmpty && context.mounted) onPicked(files);
                    },
                  ),
                  _SheetOption(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final files = await pickFiles(FileType.video);
                      if (files.isNotEmpty && context.mounted) onPicked(files);
                    },
                  ),
                  _SheetOption(
                    icon: Icons.audiotrack_outlined,
                    label: 'Audio',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final files = await pickFiles(FileType.audio);
                      if (files.isNotEmpty && context.mounted) onPicked(files);
                    },
                  ),
                  _SheetOption(
                    icon: Icons.link_outlined,
                    label: 'Link',
                    onTap: () {
                      Navigator.pop(ctx);
                      showLinkDialog(context, onPicked: onPicked);
                    },
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

  static Future<List<PickedAttachment>> pickFiles(FileType type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowMultiple: true,
      );
      if (result == null) return const [];
      return result.files
          .where((f) => f.name.isNotEmpty)
          .map(
            (f) => PickedAttachment(
              name: f.name,
              path: f.path ?? f.name,
              size: f.size,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<PickedAttachment?> pickFolder() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) return null;
      final name = path.split(kIsWeb ? '/' : _separator).last;
      return PickedAttachment(
        name: name.isEmpty ? path : name,
        path: path,
        isFolder: true,
      );
    } catch (_) {
      return null;
    }
  }

  static String get _separator => '/';

  static void showLinkDialog(
    BuildContext context, {
    required ValueChanged<List<PickedAttachment>> onPicked,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Add Link',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://...',
            border: OutlineInputBorder(),
          ),
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                onPicked([PickedAttachment(name: url, path: url)]);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

/// Lightweight attachment descriptor shared by all search bars. Screens map
/// it into their own model (workspace Attachment, chat MessageAttachment...).
class PickedAttachment {
  final String name;
  final String path;
  final int size;
  final bool isFolder;

  const PickedAttachment({
    required this.name,
    required this.path,
    this.size = 0,
    this.isFolder = false,
  });
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetOption({
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
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
