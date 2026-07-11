// Tests use an in-process fake resolver so the FutureBuilder
// resolves synchronously — driving the widget against the real
// LocalVaultStore proved flaky under flutter_test (the future's I/O
// runs in real time, but pumpAndSettle only waits for frames).

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/attachment_image.dart';

class _FakeResolver implements IAttachmentResolver {
  const _FakeResolver(this.result);
  final Uint8List? result;
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => result;
}

// 1x1 transparent PNG so Image.memory has something decodable to
// chew on; smallest valid PNG payload.
final Uint8List _pngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

const _ref = VaultRef(
  path: 'attachments/note-1/x.png',
  contentType: 'image/png',
  byteSize: 1,
);

// Static placeholder so pumpAndSettle converges — the default
// CircularProgressIndicator animates indefinitely and traps the
// pump loop.
const _loading = SizedBox.shrink(key: ValueKey('test-loading'));

void main() {
  testWidgets('shows the loading placeholder on first frame',
      (tester) async {
    // A resolver whose Future never completes — guarantees we stay
    // in the "loading" state for this frame.
    final neverResolves = _NeverResolves();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AttachmentImage(
          ref: _ref,
          resolver: neverResolves,
          loadingPlaceholder: _loading,
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('test-loading')), findsOneWidget);
  });

  testWidgets('renders Image.memory when bytes resolve', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: AttachmentImage(
            ref: _ref,
            resolver: _FakeResolver(_pngBytes),
            loadingPlaceholder: _loading,
          ),
        ),
      ),
    ));

    // FakeResolver's future completes on the next microtask. Pump
    // once to flush microtasks, then a second pump to render the
    // post-Future state.
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('defaults to center alignment', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: AttachmentImage(
            ref: _ref,
            resolver: _FakeResolver(_pngBytes),
            loadingPlaceholder: _loading,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.alignment, Alignment.center);
  });

  testWidgets('threads the alignment through to Image.memory (topCenter)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: AttachmentImage(
            ref: _ref,
            resolver: _FakeResolver(_pngBytes),
            alignment: Alignment.topCenter,
            loadingPlaceholder: _loading,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.alignment, Alignment.topCenter);
  });

  testWidgets('renders the error placeholder when bytes are missing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: AttachmentImage(
            ref: _ref,
            resolver: const _FakeResolver(null),
            loadingPlaceholder: _loading,
            errorPlaceholder: const Text('missing'),
          ),
        ),
      ),
    ));

    await tester.pump();
    await tester.pump();
    expect(find.text('missing'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renders the error placeholder when ref is null',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: AttachmentImage(
            ref: null,
            resolver: const _FakeResolver(null),
            errorPlaceholder: const Text('no-photo'),
          ),
        ),
      ),
    ));

    expect(find.text('no-photo'), findsOneWidget);
  });
}

/// Resolver whose Future never completes — used to assert the
/// loading state without triggering a rebuild.
class _NeverResolves implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) {
    return Completer<Uint8List?>().future;
  }
}
