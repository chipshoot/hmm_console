import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/video/keep_offline.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache_index.dart';
import 'package:hmm_console/core/data/attachments/video/video_downloads.dart';
import 'package:hmm_console/core/data/attachments/video_attachment.dart';
import 'package:hmm_console/features/notes/presentation/widgets/video_menu.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

VideoAttachment _video() => const VideoAttachment(
  video: VaultRef(path: 'v/a.mp4', contentType: 'video/mp4', byteSize: 10),
);

void main() {
  late VideoCacheIndex index;
  late List<String> fetched;

  Future<void> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    index = VideoCacheIndex(await SharedPreferences.getInstance());
    fetched = [];
    final keep = KeepOffline(
      index: index,
      fetch: (p) async {
        fetched.add(p);
        return const VideoFetchResult(VideoFetchOutcome.failed);
      },
      isLocal: (_) async => false,
      mayUseNetwork: () async => true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [keepOfflineProvider.overrideWith((ref) async => keep)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showVideoMenu(context, ref, noteId: 1, video: _video()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the menu lists Keep offline first, then the rest', (t) async {
    await open(t);
    final order = [
      'Keep offline',
      'Save to Photos',
      'Share…',
      'Remove from note',
    ].map((s) => t.getTopLeft(find.text(s)).dy).toList();
    expect(order, orderedEquals([...order]..sort()));
    expect(find.text('Keep offline'), findsOneWidget);
  });

  testWidgets('tapping Keep offline marks the video kept', (t) async {
    await open(t);
    await t.tap(find.text('Keep offline'));
    await t.pumpAndSettle();
    expect(index.isKept('v/a.mp4'), isTrue);
  });

  testWidgets('a kept video shows the tick', (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await VideoCacheIndex(prefs).setKept('v/a.mp4', true);
    final keep = KeepOffline(
      index: VideoCacheIndex(prefs),
      fetch: (_) async => const VideoFetchResult(VideoFetchOutcome.failed),
      isLocal: (_) async => true,
      mayUseNetwork: () async => true,
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [keepOfflineProvider.overrideWith((ref) async => keep)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showVideoMenu(context, ref, noteId: 1, video: _video()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
