import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/link_preview.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/features/notes/presentation/widgets/video_link_card.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('card shows title, site label and length', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VideoLinkCard(
          data: LinkCardData(
            url: 'https://www.bilibili.com/video/BV1',
            provider: LinkProvider.bilibili,
            title: 'A bilibili clip',
            durationSeconds: 125,
            thumbnailBytes: _png,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('A bilibili clip'), findsOneWidget);
    expect(find.text('Bilibili'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
  });

  testWidgets('no thumbnail falls back to the title row', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const VideoLinkCard(
          data: LinkCardData(
            url: 'https://www.bilibili.com/video/BV1',
            provider: LinkProvider.bilibili,
            title: 'A bilibili clip',
            durationSeconds: 125,
          ),
        ),
      ),
    );
    expect(find.text('A bilibili clip'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('length badge shows over a thumbnail', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VideoLinkCard(
          data: LinkCardData(
            url: 'https://www.bilibili.com/video/BV1',
            provider: LinkProvider.bilibili,
            title: 'A bilibili clip',
            durationSeconds: 125,
            thumbnailBytes: _png,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('2:05'), findsOneWidget);
  });

  testWidgets('long length uses h:mm:ss', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VideoLinkCard(
          data: LinkCardData(
            url: 'https://youtu.be/x',
            provider: LinkProvider.youtube,
            title: 't',
            durationSeconds: 3725,
            thumbnailBytes: _png,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('1:02:05'), findsOneWidget);
  });

  testWidgets('youtube card hides length when null', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VideoLinkCard(
          data: LinkCardData(
            url: 'https://youtu.be/x',
            provider: LinkProvider.youtube,
            title: 'A clip',
            thumbnailBytes: _png,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.textContaining(':'), findsNothing);
  });

  testWidgets('a thumbnail that fails to resolve gives the title-only row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        VideoLinkCard(
          resolver: _FailingResolver(),
          data: const LinkCardData(
            url: 'https://youtu.be/x',
            provider: LinkProvider.youtube,
            title: 'A clip',
            durationSeconds: 60,
            thumbnail: VaultRef(
              path: 'attachments/n/t.jpg',
              contentType: 'image/jpeg',
              byteSize: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.text('1:00'), findsNothing);
    expect(find.text('A clip'), findsOneWidget);
  });

  testWidgets('tap launches the original url externally', (tester) async {
    Uri? launched;
    await tester.pumpWidget(
      _wrap(
        VideoLinkCard(
          data: const LinkCardData(
            url: 'https://youtu.be/x',
            provider: LinkProvider.youtube,
            title: 'A clip',
          ),
          launch: (u) async {
            launched = u;
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.text('A clip'));
    await tester.pump();
    expect(launched, Uri.parse('https://youtu.be/x'));
    expect(find.text('May no longer be available'), findsNothing);
  });

  testWidgets('failed launch shows unavailable text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VideoLinkCard(
          data: const LinkCardData(
            url: 'https://youtu.be/x',
            provider: LinkProvider.youtube,
            title: 'A clip',
          ),
          launch: (_) async => false,
        ),
      ),
    );
    await tester.tap(find.text('A clip'));
    await tester.pump();
    expect(find.text('May no longer be available'), findsOneWidget);
  });

  testWidgets('throwing launch shows unavailable text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VideoLinkCard(
          data: const LinkCardData(
            url: 'https://youtu.be/x',
            provider: LinkProvider.youtube,
            title: 'A clip',
          ),
          launch: (_) async => throw Exception('no handler'),
        ),
      ),
    );
    await tester.tap(find.text('A clip'));
    await tester.pump();
    expect(find.text('May no longer be available'), findsOneWidget);
  });
}

class _FailingResolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async =>
      throw Exception('boom');
}

final _png = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0,
  0,
  0,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0,
  0,
  0,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0,
  1,
  0,
  0,
  5,
  0,
  1,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0,
  0,
  0,
  0,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
