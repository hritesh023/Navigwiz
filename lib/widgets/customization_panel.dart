import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/theme_service.dart';

class CustomizationPanel extends StatefulWidget {
  final VoidCallback onClose;

  const CustomizationPanel({super.key, required this.onClose});

  @override
  State<CustomizationPanel> createState() => _CustomizationPanelState();
}

class _CustomizationPanelState extends State<CustomizationPanel> {

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildThemeSection(context),
                  const SizedBox(height: 24),
                  _buildBackgroundSection(context),
                  const SizedBox(height: 24),
                  _buildColorSection(context),
                  const SizedBox(height: 24),
                  _buildPresetThemes(context),
                  const SizedBox(height: 24),
                  _buildAiSection(context),
                  const SizedBox(height: 24),
                  _buildPermissionsSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.palette),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Customize Navigwiz',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme Mode', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ToggleButtons(
              isSelected: [!themeService.isDarkMode, themeService.isDarkMode],
              onPressed: (index) {
                themeService.setDarkMode(index == 1);
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Light'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Dark'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackgroundSection(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Background',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (themeService.hasBackgroundMedia)
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: themeService.hasVideoBackground
                      ? null
                      : DecorationImage(
                          image:
                              MemoryImage(themeService.backgroundImageBytes!),
                          fit: BoxFit.cover,
                        ),
                  gradient: themeService.hasVideoBackground
                      ? LinearGradient(
                          colors: [
                            themeService.primaryColor.withValues(alpha: 0.35),
                            Theme.of(context).colorScheme.surface,
                          ],
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    if (themeService.hasVideoBackground)
                      const Center(
                        child: Icon(Icons.movie, size: 36),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        onPressed: () => themeService.removeBackgroundImage(),
                        icon: const Icon(Icons.delete, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 32),
                      SizedBox(height: 4),
                      Text('No background image'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickBackgroundImage,
                icon: const Icon(Icons.image),
                label: const Text('Choose Image'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickBackgroundVideo,
                icon: const Icon(Icons.movie),
                label: const Text('Choose Video'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildColorSection(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Primary Color',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: themeService.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildRgbSlider(
              context,
              label: 'R',
              value: _colorChannel(themeService.primaryColor, 16),
              onChanged: (value) => _setRgb(themeService, red: value),
            ),
            _buildRgbSlider(
              context,
              label: 'G',
              value: _colorChannel(themeService.primaryColor, 8),
              onChanged: (value) => _setRgb(themeService, green: value),
            ),
            _buildRgbSlider(
              context,
              label: 'B',
              value: _colorChannel(themeService.primaryColor, 0),
              onChanged: (value) => _setRgb(themeService, blue: value),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showColorPicker(context, themeService),
                icon: const Icon(Icons.color_lens),
                label: const Text('Choose Color'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRgbSlider(
    BuildContext context, {
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 18, child: Text(label)),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            divisions: 255,
            value: value.toDouble(),
            onChanged: (nextValue) => onChanged(nextValue.round()),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(value.toString(), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  void _setRgb(
    ThemeService themeService, {
    int? red,
    int? green,
    int? blue,
  }) {
    final color = themeService.primaryColor;
    themeService.setPrimaryColor(
      Color.fromARGB(
        _colorChannel(color, 24),
        red ?? _colorChannel(color, 16),
        green ?? _colorChannel(color, 8),
        blue ?? _colorChannel(color, 0),
      ),
    );
  }

  int _colorChannel(Color color, int shift) {
    return (color.toARGB32() >> shift) & 0xff;
  }

  Widget _buildAiSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI & Search', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Built-in AI assistant with web search via DuckDuckGo.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }

  Widget _buildPermissionsSection(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget _buildPresetThemes(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preset Themes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ThemeService.predefinedColors.map((color) {
                final isSelected =
                    themeService.primaryColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => themeService.setPrimaryColor(color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            )
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickBackgroundImage() async {
    // Get theme service before async operation
    final themeService = Provider.of<ThemeService>(context, listen: false);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      final pickedFile = result?.files.single;
      if (pickedFile != null && pickedFile.bytes != null) {
        await themeService.setBackgroundImageBytes(
          pickedFile.bytes!,
          path: pickedFile.path,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Background image updated')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not pick image')),
        );
      }
    }
  }

  Future<void> _pickBackgroundVideo() async {
    final themeService = Provider.of<ThemeService>(context, listen: false);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: true,
      );

      final pickedFile = result?.files.single;
      if (pickedFile != null && pickedFile.bytes != null) {
        if (pickedFile.bytes!.lengthInBytes > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Choose a video under 5 MB for now.'),
              ),
            );
          }
          return;
        }
        await themeService.setBackgroundVideoBytes(
          pickedFile.bytes!,
          path: pickedFile.path,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video background selected')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not pick video')),
        );
      }
    }
  }

  void _showColorPicker(BuildContext context, ThemeService themeService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: themeService.primaryColor,
              onColorChanged: (Color color) {
                themeService.setPrimaryColor(color);
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}
