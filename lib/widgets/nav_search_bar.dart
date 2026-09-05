import 'package:flutter/material.dart';

import '../services/input_actions.dart';

/// Unified Navigwiz search bar: "+" attach, camera, mic and submit.
/// Same functions as the Acronous AI app (voice dictation, camera capture,
/// file/folder/picture/video/audio/link attach) with Navigwiz pill styling.
/// Used by home search, research, projects, workspace, private browser and
/// the Acronous AI chat input.
class NavSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onVoicePressed;
  final VoidCallback? onAttachPressed;
  final VoidCallback? onSubmitPressed;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<List<PickedAttachment>>? onAttachmentsChanged;
  final bool isLoading;
  final String hintText;
  final bool autofocus;
  final TextInputAction textInputAction;
  final bool showAttach;
  final bool showCamera;
  final bool showVoice;

  const NavSearchBar({
    super.key,
    required this.controller,
    this.onCameraPressed,
    this.onVoicePressed,
    this.onAttachPressed,
    this.onSubmitPressed,
    this.onSubmitted,
    this.onAttachmentsChanged,
    this.isLoading = false,
    this.hintText = 'What do you want to do?...',
    this.autofocus = false,
    this.textInputAction = TextInputAction.search,
    this.showAttach = true,
    this.showCamera = true,
    this.showVoice = true,
  });

  @override
  State<NavSearchBar> createState() => _NavSearchBarState();
}

class _NavSearchBarState extends State<NavSearchBar> {
  final List<PickedAttachment> _attachments = [];
  bool _listening = false;

  @override
  void dispose() {
    if (_listening) InputActions.stopVoice();
    super.dispose();
  }

  List<PickedAttachment> get attachments => List.unmodifiable(_attachments);

  void _submit() {
    if (widget.onSubmitPressed != null) {
      widget.onSubmitPressed!();
      return;
    }
    widget.onSubmitted?.call(widget.controller.text);
  }

  Future<void> _onVoice() async {
    if (widget.onVoicePressed != null) {
      widget.onVoicePressed!();
      return;
    }
    if (_listening) {
      InputActions.stopVoice(onState: (v) {
        if (mounted) setState(() => _listening = v);
      });
      return;
    }
    await InputActions.toggleVoice(
      context,
      widget.controller,
      onState: (v) {
        if (mounted) setState(() => _listening = v);
      },
    );
  }

  void _onCamera() {
    if (widget.onCameraPressed != null) {
      widget.onCameraPressed!();
      return;
    }
    InputActions.showCameraSheet(
      context,
      onImage: (path) {
        final name = path.split('/').last.split('\\').last;
        _addAttachments([
          PickedAttachment(name: name.isEmpty ? path : name, path: path),
        ]);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Picture added — ask anything about it.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _onAttach() {
    if (widget.onAttachPressed != null) {
      widget.onAttachPressed!();
      return;
    }
    InputActions.showAttachSheet(
      context,
      onPicked: (files) {
        _addAttachments(files);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              files.length == 1
                  ? 'Attached ${files.first.name} — ask to modify, reference or convert it.'
                  : 'Attached ${files.length} files — ask to modify, reference or convert them.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _addAttachments(List<PickedAttachment> files) {
    if (files.isEmpty) return;
    setState(() => _attachments.addAll(files));
    widget.onAttachmentsChanged?.call(attachments);
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
    widget.onAttachmentsChanged?.call(attachments);
  }

  /// Lets hosts (e.g. home search) consume + clear attachments on submit.
  void clearAttachments() {
    if (_attachments.isEmpty) return;
    setState(() => _attachments.clear());
    widget.onAttachmentsChanged?.call(attachments);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_attachments.isNotEmpty) _buildAttachmentChips(),
        Container(
          constraints: const BoxConstraints(maxWidth: 800),
          height: 56,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey[900]!.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.grey[700]!.withValues(alpha: 0.5)
                  : Colors.grey[300]!.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.grey[400]!)
                    .withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 4),
              if (widget.showAttach)
                _IconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Attach files, folders, pictures, video, audio',
                  onPressed: _onAttach,
                ),
              if (widget.showAttach) const SizedBox(width: 2),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  autofocus: widget.autofocus,
                  textInputAction: widget.textInputAction,
                  onSubmitted: widget.onSubmitted,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: _listening ? 'Listening...' : widget.hintText,
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              if (widget.isLoading)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              if (widget.showCamera)
                _IconButton(
                  icon: Icons.camera_alt_outlined,
                  tooltip: 'Ask with camera',
                  onPressed: _onCamera,
                ),
              if (widget.showVoice)
                _IconButton(
                  icon: _listening
                      ? Icons.mic_rounded
                      : Icons.mic_outlined,
                  tooltip: _listening ? 'Stop listening' : 'Voice search',
                  highlight: _listening,
                  onPressed: _onVoice,
                ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 1,
                color: isDark ? Colors.grey[700] : Colors.grey[300],
              ),
              _SubmitButton(
                isLoading: widget.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentChips() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._attachments.asMap().entries.map((e) {
              final att = e.value;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      att.isFolder
                          ? Icons.folder_outlined
                          : Icons.attach_file_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 140),
                      child: Text(
                        att.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _removeAttachment(e.key),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool highlight;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: highlight
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 22,
              color: highlight
                  ? Theme.of(context).colorScheme.error
                  : isDark
                      ? Colors.grey[400]
                      : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.arrow_forward,
          size: 20,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
