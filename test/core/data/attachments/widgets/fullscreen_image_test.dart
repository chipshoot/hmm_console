import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/attachment_image.dart';
import 'package:hmm_console/core/data/attachments/widgets/fullscreen_image.dart';

/// Resolver stub so the provider yields `data` (no path_provider in tests).
class _FakeResolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}

void main() {
  testWidgets('opens a zoomable dialog with the image', (t) async {
    const ref = VaultRef(
        path: 'attachments/note-1/a.jpg', contentType: 'image/jpeg', byteSize: 10);
    await t.pumpWidget(ProviderScope(
      overrides: [
        attachmentResolverProvider.overrideWith((ref) async => _FakeResolver()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showFullscreenImage(ctx, ref),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle(); // open the dialog + resolve the resolver future
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(AttachmentImage), findsOneWidget);
  });
}
