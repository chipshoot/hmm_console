import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/file_byte_source.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/attachments_section.dart';

class _FakeResolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final resolver = _FakeResolver();

  testWidgets('editable shows add buttons; read-only hides them',
      (tester) async {
    await tester.pumpWidget(_host(AttachmentsSection(
      items: const [],
      resolver: _FakeResolver(),
      editable: true,
      onAddImage: () {},
      onAddPdf: () {},
    )));
    expect(find.byKey(const Key('att-add-image')), findsOneWidget);
    expect(find.byKey(const Key('att-add-pdf')), findsOneWidget);

    await tester.pumpWidget(_host(AttachmentsSection(
      items: const [],
      resolver: _FakeResolver(),
      editable: false,
    )));
    expect(find.byKey(const Key('att-add-image')), findsNothing);
    expect(find.byKey(const Key('att-add-pdf')), findsNothing);
  });

  testWidgets('renders a pdf file card with its name', (tester) async {
    final item = PendingFileItem(PickedFileBytes(
      bytes: Uint8List.fromList([1, 2, 3]),
      originalName: 'invoice.pdf',
      contentType: 'application/pdf',
    ));
    await tester.pumpWidget(_host(AttachmentsSection(
      items: [item],
      resolver: resolver,
      editable: true,
      onAddImage: () {},
      onAddPdf: () {},
    )));
    expect(find.text('invoice.pdf'), findsOneWidget);
  });

  testWidgets('remove button invokes onRemove with the item', (tester) async {
    AttachmentItem? removed;
    final item = PendingFileItem(PickedFileBytes(
      bytes: Uint8List.fromList([1]),
      originalName: 'a.pdf',
      contentType: 'application/pdf',
    ));
    await tester.pumpWidget(_host(AttachmentsSection(
      items: [item],
      resolver: resolver,
      editable: true,
      onAddImage: () {},
      onAddPdf: () {},
      onRemove: (i) => removed = i,
    )));
    await tester.tap(find.byKey(const Key('att-remove-0')));
    expect(removed, same(item));
  });

  testWidgets('add-image button invokes onAddImage', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(AttachmentsSection(
      items: const [],
      resolver: resolver,
      editable: true,
      onAddImage: () => tapped = true,
      onAddPdf: () {},
    )));
    await tester.tap(find.byKey(const Key('att-add-image')));
    expect(tapped, isTrue);
  });
}
