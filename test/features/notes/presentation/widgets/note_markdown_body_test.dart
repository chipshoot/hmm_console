import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_markdown_body.dart';

class _FakeResolver implements IAttachmentResolver {
  const _FakeResolver(this.bytes);
  final Uint8List? bytes;
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => bytes;
}

// Smallest valid PNG.
final Uint8List _png = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D, 0x49, 0x48,
  0x44, 0x52, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 0x1F, 0x15, 0xC4, 0x89,
  0, 0, 0, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0, 1, 0, 0, 5, 0,
  1, 0x0D, 0x0A, 0x2D, 0xB4, 0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

void main() {
  testWidgets('renders a real inline image via the resolver', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteMarkdownBody(
          data: '![x](hmm-attachment://attachments/note-1/a.png)',
          resolver: _FakeResolver(_png),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renders a pending inline image from the staged bytes map',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteMarkdownBody(
          data: '![x](hmm-attachment://pending/u1)',
          pendingBytes: {'u1': _png},
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renders plain markdown text with no inline image',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NoteMarkdownBody(data: 'hello **world**')),
    ));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });
}
