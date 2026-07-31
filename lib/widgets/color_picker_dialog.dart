import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

Future<Color?> showAccentColorPicker(BuildContext context, Color initialColor) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _AccentColorPickerDialog(initialColor: initialColor),
  );
}

class _AccentColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const _AccentColorPickerDialog({required this.initialColor});

  @override
  State<_AccentColorPickerDialog> createState() => _AccentColorPickerDialogState();
}

class _AccentColorPickerDialogState extends State<_AccentColorPickerDialog> {
  late Color _currentColor = widget.initialColor;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text('Pick Accent Color',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: widget.initialColor,
          onColorChanged: (color) => setState(() => _currentColor = color),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _currentColor),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
