// The sync card must SHOW where the time went, not just record it. A timing
// that lives only on the model answers nobody's "why is sync slow".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/features/settings/presentation/widgets/sync_status_card.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _FakeSync extends SyncController {
  _FakeSync(this._s) : super(syncAction: () async => throw UnimplementedError());
  final SyncStatus _s;
  @override
  SyncStatus get status => _s;
}

SyncResult _resultWith(SyncTiming? timing) => SyncResult(
      pulledNotes: 0, pulledAttachments: 0, pushedNotes: 0,
      pushedAttachments: 0, completedAt: DateTime.utc(2026, 9, 18),
      timing: timing,
    );

SyncTiming _timing({required SyncPhase slow, required Duration slowDur}) =>
    SyncTiming(
      phases: {
        for (final p in SyncPhase.values)
          p: p == slow ? slowDur : const Duration(milliseconds: 40),
      },
      total: const Duration(milliseconds: 3200),
    );

void main() {
  Future<void> pump(WidgetTester tester, SyncStatus status) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        syncControllerProvider.overrideWithValue(_FakeSync(status)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SyncStatusCard()),
      ),
    ));
    await tester.pump();
  }

  testWidgets('shows the total and names the slowest phase', (tester) async {
    await pump(
      tester,
      SyncStatus(
        lastSyncAt: DateTime.utc(2026, 9, 18),
        lastResult: _resultWith(_timing(
          slow: SyncPhase.attachments,
          slowDur: const Duration(milliseconds: 1900),
        )),
      ),
    );

    final line = tester.widget<Text>(find.byKey(const Key('syncTimingLine')));
    expect(line.data, contains('3.2s'));
    expect(line.data, contains('attachments'));
    expect(line.data, contains('1.9s'));
  });

  testWidgets('a fast phase reads in milliseconds, never 0.0s', (tester) async {
    await pump(
      tester,
      SyncStatus(
        lastSyncAt: DateTime.utc(2026, 9, 18),
        lastResult: _resultWith(SyncTiming(
          phases: {for (final p in SyncPhase.values) p: const Duration(milliseconds: 12)},
          total: const Duration(milliseconds: 180),
        )),
      ),
    );

    final line = tester.widget<Text>(find.byKey(const Key('syncTimingLine')));
    expect(line.data, contains('180ms'));
    expect(line.data, isNot(contains('0.0s')));
  });

  testWidgets('no timing yet (never synced) shows no timing line',
      (tester) async {
    await pump(tester, const SyncStatus());
    expect(find.byKey(const Key('syncTimingLine')), findsNothing);
  });
}
