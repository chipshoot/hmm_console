import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/service_record_form_screen.dart';
import 'package:hmm_console/features/automobile_records/states/mutate_service_record_state.dart';

class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

/// Returns canned image bytes without the platform picker.
class _FakeImageSource implements ImageByteSource {
  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async =>
      PickedImageBytes(
        bytes: Uint8List.fromList(_png1x1),
        originalName: 'shot.png',
        contentType: 'image/png',
      );
}

// A valid 1x1 transparent PNG so the preview's Image.memory has real bytes.
const _png1x1 = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

void main() {
  testWidgets(
      'inserting an inline image stages a pending placeholder + preview image',
      (tester) async {
    final container = ProviderContainer(overrides: [
      imageByteSourceProvider.overrideWithValue(_FakeImageSource()),
      // cloudApi so the attachments section (needs a vault resolver) is
      // skipped — the notes field, insert action, and preview are mode-agnostic.
      dataModeProvider.overrideWith(() => _StubMode(DataMode.cloudApi)),
    ]);
    addTearDown(container.dispose);
    // Settle the mutate provider to AsyncData up front so the form's
    // "record saved -> pop" listener doesn't fire on a loading->data transition.
    await container.read(mutateServiceRecordStateProvider.future);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const ServiceRecordFormScreen(automobileId: 7),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Reveal the notes section, then insert an image into it. The form is long,
    // so scroll the insert action into view before tapping.
    await tester.enterText(
        find.widgetWithText(TextField, 'Notes'), 'Before shot');
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Insert image into notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Insert image into notes'));
    await tester.pumpAndSettle();

    // The Notes controller now holds a pending inline-image placeholder.
    final editables = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(
      editables
          .any((e) => e.controller.text.contains('hmm-attachment://pending/')),
      isTrue,
    );
    // The live preview renders the staged bytes as an image.
    expect(find.byType(Image), findsWidgets);
  });
}
