// Regression test for the auto-sync "dies after a DataMode switch" bug.
//
// syncControllerProvider watches the sync orchestrator, so switching
// DataMode rebuilds it into a NEW SyncController. The root widget only
// start()ed the FIRST instance, so the recreated one never registered
// its lifecycle observer + periodic timer → background/periodic
// auto-sync silently stopped until app restart. The fix re-starts each
// recreated instance via a ref.listen in MainApp.build (replicated here
// by _AutoSyncHost). We trigger the recreation by invalidating the real
// orchestrator provider — the same effect a setMode() has.

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirror of `MainApp`'s auto-sync wiring: start the first instance in
/// initState, re-start every recreated instance via ref.listen in build.
class _AutoSyncHost extends ConsumerStatefulWidget {
  const _AutoSyncHost();

  @override
  ConsumerState<_AutoSyncHost> createState() => _AutoSyncHostState();
}

class _AutoSyncHostState extends ConsumerState<_AutoSyncHost> {
  @override
  void initState() {
    super.initState();
    ref.read(syncControllerProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SyncController>(syncControllerProvider, (previous, next) {
      next.start();
    });
    return const SizedBox.shrink();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'recreated SyncController (DataMode switch) is re-started, not left dead',
      (tester) async {
    // Empty prefs → DataMode.local, so the orchestrator builds without
    // any cloud-provider graph.
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const _AutoSyncHost(),
    ));

    final first = container.read(syncControllerProvider);
    expect(first.isStarted, isTrue,
        reason: 'the first controller is started by initState');

    // Simulate a DataMode switch: setMode() ultimately rebuilds the
    // orchestrator, which rebuilds syncControllerProvider into a new
    // instance. Invalidating the orchestrator reproduces that exactly.
    container.invalidate(syncOrchestratorProvider);
    await tester.pump();

    final second = container.read(syncControllerProvider);
    expect(identical(first, second), isFalse,
        reason: 'a DataMode switch recreates the controller');
    expect(second.isStarted, isTrue,
        reason:
            'the recreated controller must be re-started — the bug was that '
            'it never was, so background/periodic auto-sync went dead');
    expect(first.isStarted, isFalse,
        reason: 'the old controller is stopped on dispose');

    // Cancel the live controller's periodic timer before the test ends
    // so the framework's "no pending timers" invariant passes (the
    // UncontrolledProviderScope doesn't own/dispose the container).
    second.stop();
  });
}
