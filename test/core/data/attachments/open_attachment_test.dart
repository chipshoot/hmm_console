import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/open_attachment.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';

class _UnavailableResolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}

void main() {
  testWidgets('openAttachment returns a message when bytes are unavailable',
      (tester) async {
    late WidgetRef capturedRef;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachmentResolverProvider
            .overrideWith((ref) async => _UnavailableResolver()),
      ],
      child: Consumer(builder: (c, ref, _) {
        capturedRef = ref;
        return const SizedBox();
      }),
    ));

    final msg = await openAttachment(
      capturedRef,
      const VaultRef(
        path: 'attachments/note-1/x.pdf',
        contentType: 'application/pdf',
        byteSize: 1,
      ),
    );
    expect(msg, 'File is not available on this device.');
  });
}
