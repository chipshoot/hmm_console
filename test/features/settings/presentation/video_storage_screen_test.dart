import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache.dart';
import 'package:hmm_console/core/data/sync/video_upload_scheduler.dart';
import 'package:hmm_console/core/data/attachments/video/video_platform.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:hmm_console/core/theme/theme.dart';
import 'package:hmm_console/features/settings/presentation/screens/video_storage_screen.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/attachments/video/fake_video_platform.dart';

const _gb = 1024 * 1024 * 1024;
const _mb = 1024 * 1024;

class _FakeCache implements VideoCache {
  int downloaded = (1.2 * _gb).round();
  int cleared = 0;
  int kept = 2;
  Object? clearError;
  Completer<void>? clearGate;
  @override
  Future<VideoCacheUsage> usage() async => VideoCacheUsage(
    downloadedBytes: downloaded,
    keptCount: kept,
    keptBytes: 300 * _mb,
  );
  @override
  Future<int> clearDownloaded() async {
    cleared++;
    if (clearGate != null) await clearGate!.future;
    if (clearError != null) throw clearError!;
    final freed = downloaded;
    downloaded = 0;
    return freed;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeScheduler extends VideoUploadScheduler {
  _FakeScheduler(VideoPlatform p)
    : super(
        resolveUploader: () async => null,
        isSyncing: () => false,
        platform: p,
      );
  int runs = 0;
  @override
  Future<void> maybeRun() async => runs++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(_FakeCache, _FakeScheduler, ProviderContainer)> pump(
    WidgetTester t, {
    Widget? below,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final cache = _FakeCache();
    final sched = _FakeScheduler(FakeVideoPlatform());
    final c = ProviderContainer(
      overrides: [
        videoCacheProvider.overrideWith((ref) async => cache),
        videoUploadSchedulerProvider.overrideWithValue(sched),
      ],
    );
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.lightThemeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: below == null
              ? const VideoStorageScreen()
              : Column(
                  children: [
                    Expanded(child: const VideoStorageScreen()),
                    below,
                  ],
                ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return (cache, sched, c);
  }

  testWidgets('shows downloaded and kept-offline usage', (t) async {
    await pump(t);
    expect(find.text('1.2 GB of 2 GB'), findsOneWidget);
    expect(find.text('2 videos · 300 MB'), findsOneWidget);
  });

  testWidgets('one kept video is singular', (t) async {
    final (cache, _, c) = await pump(t);
    cache.kept = 1;
    c.invalidate(videoCacheUsageProvider);
    await t.pumpAndSettle();
    expect(find.text('1 video · 300 MB'), findsOneWidget);
  });

  testWidgets('the toggle sets the setting and kicks the scheduler', (t) async {
    final (_, sched, c) = await pump(t);
    final tile = find.widgetWithText(SwitchListTile, 'Upload on mobile data');
    expect(t.widget<SwitchListTile>(tile).value, isFalse);
    await t.tap(tile);
    await t.pumpAndSettle();
    expect(c.read(settingsProvider).value!.videoUploadOnMobileData, isTrue);
    expect(sched.runs, 1);
  });

  testWidgets('Clear asks, then clears and shows the freed size', (t) async {
    final (cache, _, _) = await pump(t);
    await t.tap(find.text('Clear downloaded videos'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('Remove 1.2 GB of downloaded videos'),
      findsOneWidget,
    );
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Clear downloaded videos'),
      ),
    );
    await t.pumpAndSettle();
    expect(cache.cleared, 1);
    expect(find.text('Cleared 1.2 GB'), findsOneWidget);
    expect(find.text('0 MB of 2 GB'), findsOneWidget);
  });

  Future<void> confirmClear(WidgetTester t) async {
    await t.tap(find.text('Clear downloaded videos'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Clear downloaded videos'),
      ),
    );
  }

  testWidgets('a failed Clear says so', (t) async {
    final (cache, _, _) = await pump(t);
    cache.clearError = StateError('disk');
    await confirmClear(t);
    await t.pumpAndSettle();
    expect(find.text("Couldn't clear downloaded videos"), findsOneWidget);
    expect(find.text('1.2 GB of 2 GB'), findsOneWidget);
  });

  testWidgets('Clear cannot start again while it runs', (t) async {
    final (cache, _, _) = await pump(t);
    cache.clearGate = Completer<void>();
    await confirmClear(t);
    await t.pumpAndSettle();
    await t.tap(find.text('Clear downloaded videos'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    cache.clearGate!.complete();
    await t.pumpAndSettle();
    expect(cache.cleared, 1);
  });

  testWidgets('Clear refreshes the shared usage the Settings row shows', (
    t,
  ) async {
    await pump(
      t,
      below: Consumer(
        builder: (context, ref, _) {
          final u = ref.watch(videoCacheUsageProvider).value;
          return Text('row ${u?.downloadedBytes}');
        },
      ),
    );
    expect(find.text('row ${(1.2 * _gb).round()}'), findsOneWidget);
    await confirmClear(t);
    await t.pumpAndSettle();
    expect(find.text('row 0'), findsOneWidget);
  });

  testWidgets('Cancel clears nothing', (t) async {
    final (cache, _, _) = await pump(t);
    await t.tap(find.text('Clear downloaded videos'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(cache.cleared, 0);
  });

  testWidgets('has a help button', (t) async {
    await pump(t);
    expect(find.byType(HelpButton), findsOneWidget);
  });
}
