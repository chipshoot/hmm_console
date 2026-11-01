import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/attachment_image.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_markdown_body.dart';

class _FakeResolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}

/// Regression (2026-10-31, iPhone/iPad): the first note opened after launch
/// showed a broken-image box instead of its photo; reopening it worked. The
/// attachment resolver was still loading on the first frame, MarkdownBody
/// built the placeholder, and flutter_markdown only re-parses when the text
/// changes — so the resolver arriving a moment later was never used.
void main() {
  testWidgets('an inline image appears once a late resolver is ready',
      (tester) async {
    final ready = Completer<IAttachmentResolver>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachmentResolverProvider.overrideWith((ref) => ready.future),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: MarkdownView(
              '![p](hmm-attachment://attachments/note-1/a.jpg)'),
        ),
      ),
    ));
    expect(find.byType(AttachmentImage), findsNothing,
        reason: 'no resolver yet: placeholder');

    ready.complete(_FakeResolver());
    await tester.pump();
    await tester.pump();

    expect(find.byType(AttachmentImage), findsOneWidget);
  });
}
