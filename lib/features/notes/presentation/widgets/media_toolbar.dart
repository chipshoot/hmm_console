import 'package:flutter/material.dart';

import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/theme/app_colors.dart';

/// Bottom media toolbar (Apple-Journal style). Phase 1: Photos + Camera. More
/// buttons (voice, location, PDF) are added in later phases.
class MediaToolbar extends StatelessWidget {
  const MediaToolbar({super.key, required this.onPick, this.enabled = true});

  final void Function(AttachmentPickSource source) onPick;
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
          ],
        ),
      ),
    );
  }
}
