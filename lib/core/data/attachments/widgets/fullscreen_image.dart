import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../attachment_ref.dart';
import '../attachment_providers.dart';
import 'attachment_image.dart';

/// Opens [ref] full-screen in a zoomable, tap-to-dismiss dialog. Shared by the
/// note editor, the note review screen, and the vehicle screen so they all
/// view photos the same way.
void showFullscreenImage(BuildContext context, AttachmentRef ref) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => Consumer(builder: (context, ref2, _) {
      final resolverAsync = ref2.watch(attachmentResolverProvider);
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: resolverAsync.when(
              data: (resolver) => InteractiveViewer(
                child: AttachmentImage(ref: ref, resolver: resolver),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Could not load photo: $e',
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
      );
    }),
  );
}
