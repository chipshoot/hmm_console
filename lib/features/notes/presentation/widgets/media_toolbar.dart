import 'package:flutter/material.dart';

import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/theme/app_colors.dart';

/// Bottom media toolbar (Apple-Journal style). Phase 1: Photos + Camera. More
/// buttons (voice, location, PDF) are added in later phases.
class MediaToolbar extends StatelessWidget {
  const MediaToolbar({
    super.key,
    required this.onPick,
    required this.onPickFile,
    required this.onRecord,
    this.onLinkToNote,
    this.onDismissKeyboard,
    this.enabled = true,
  });

  final void Function(AttachmentPickSource source) onPick;
  final VoidCallback onPickFile;
  final VoidCallback onRecord;

  /// When non-null, a "link to a note" toolbar action is shown.
  final VoidCallback? onLinkToNote;

  /// When non-null, a trailing keyboard-hide button is shown. The editor
  /// passes this only while the keyboard is up, so the control never appears
  /// as a dead button when there's nothing to dismiss.
  final VoidCallback? onDismissKeyboard;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    Widget btn(IconData icon, AttachmentPickSource source) => IconButton(
      icon: Icon(icon),
      color: c.accent,
      onPressed: enabled ? () => onPick(source) : null,
    );
    return SafeArea(
      top: false,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: c.groupedBackground,
          border: Border(top: BorderSide(color: c.separator)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 8),
            btn(Icons.photo_library_outlined, AttachmentPickSource.gallery),
            btn(Icons.camera_alt_outlined, AttachmentPickSource.camera),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              color: c.accent,
              onPressed: enabled ? onPickFile : null,
            ),
            IconButton(
              icon: const Icon(Icons.mic_none_outlined),
              color: c.accent,
              onPressed: enabled ? onRecord : null,
            ),
            if (onLinkToNote != null)
              IconButton(
                icon: const Icon(Icons.link),
                color: c.accent,
                tooltip: 'Link to a note',
                onPressed: enabled ? onLinkToNote : null,
              ),
            if (onDismissKeyboard != null) ...[
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.keyboard_hide_outlined),
                color: c.accent,
                tooltip: 'Hide keyboard',
                // Always tappable: dismissing the keyboard is harmless even
                // mid-save, and it's the whole point of the control.
                onPressed: onDismissKeyboard,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}
