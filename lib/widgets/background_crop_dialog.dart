import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Lets the user crop/adjust the framing of a background image/GIF before
/// applying it: drag to pan, slider to zoom, then Apply to confirm.
class BackgroundCropDialog extends StatefulWidget {
  final Uint8List bytes;
  final double initialZoom;
  final double initialOffsetX;
  final double initialOffsetY;
  final Future<void> Function(double zoom, double offsetX, double offsetY)
      onApply;

  const BackgroundCropDialog({
    super.key,
    required this.bytes,
    this.initialZoom = 1.0,
    this.initialOffsetX = 0.0,
    this.initialOffsetY = 0.0,
    required this.onApply,
  });

  @override
  State<BackgroundCropDialog> createState() => _BackgroundCropDialogState();
}

class _BackgroundCropDialogState extends State<BackgroundCropDialog> {
  late double _zoom;
  late double _offsetX;
  late double _offsetY;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _zoom = widget.initialZoom;
    _offsetX = widget.initialOffsetX;
    _offsetY = widget.initialOffsetY;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Adjust background',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      return GestureDetector(
                        onPanUpdate: (d) {
                          setState(() {
                            _offsetX = (_offsetX - d.delta.dx / (c.maxWidth / 2))
                                .clamp(-1.0, 1.0);
                            _offsetY = (_offsetY - d.delta.dy / (c.maxHeight / 2))
                                .clamp(-1.0, 1.0);
                          });
                        },
                        child: ColoredBox(
                          color: Colors.black,
                          child: Transform.translate(
                            offset: Offset(
                              _offsetX * c.maxWidth * 0.5,
                              _offsetY * c.maxHeight * 0.5,
                            ),
                            child: Transform.scale(
                              scale: _zoom,
                              child: Image.memory(
                                widget.bytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, __, ___) =>
                                    const Center(child: Icon(Icons.broken_image, color: Colors.white)),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.zoom_out, size: 18),
                  Expanded(
                    child: Slider(
                      value: _zoom,
                      min: 0.5,
                      max: 4.0,
                      onChanged: (v) => setState(() => _zoom = v),
                    ),
                  ),
                  const Icon(Icons.zoom_in, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text('Drag to pan · use the slider to zoom',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _applying ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _applying
                        ? null
                        : () async {
                            setState(() => _applying = true);
                            await widget.onApply(_zoom, _offsetX, _offsetY);
                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(_applying ? 'Applying…' : 'Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
