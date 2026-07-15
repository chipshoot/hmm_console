# Sync Safety & Persistent Home/Sync Access — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink the "created but not yet off-device" window for `cloudStorage` notes (and gas logs, which are notes) from ~10 minutes to seconds, make unsynced state visible on every screen, and never silently strand data when auto-sync is blocked or failing — fixing the OneDrive-tier data-loss incident described in `docs/superpowers/specs/2026-07-15-sync-safety-persistent-access-design.md`.

**Architecture:** Layer three small pieces on the existing sync engine (no rewrite): (1) a debounced `notifyLocalChange()` signal on `SyncController` fired from the note-write chokepoint so bursts of edits collapse into one auto-sync; (2) a cheap reactive `pendingSyncCountProvider` (COUNT of notes changed since the last-pushed cursor) driving a status pill and a blocked/failed anti-loss prompt; (3) a single global Home+Sync control cluster mounted once above the router (`MaterialApp.router`'s `builder`) so every screen — including the Dashboard's raw `Scaffold` — gets it with zero per-screen edits.

**Tech Stack:** Flutter/Dart, Riverpod (`flutter_riverpod` 3.0.3, plain `Provider`/`StreamProvider`, no codegen used here), Drift/SQLite (`drift` 2.24), `go_router` 17, `connectivity_plus` 7.

## Global Constraints

- **Riverpod only** for DI/state — no `GetIt`/`ServiceLocator`. New reactive state is a plain `Provider`/`StreamProvider`, matching the rest of `lib/core/data/`.
- **`.value`, not `.valueOrNull`, on `AsyncValue`** — this project's `flutter_riverpod: ^3.0.3` has no `.valueOrNull`.
- **`flutter_platform_widgets` for buttons/switches/dialogs/text fields per CLAUDE.md** — **caveat, verified against the repo:** `flutter_platform_widgets` is **not a dependency** in `pubspec.yaml` and is used **nowhere** in `lib/`. Existing adaptive code (e.g. `lib/core/widgets/app_scaffold.dart`, `dashboard_screen.dart::_showUserMenu`) hand-rolls platform branches via `Theme.of(context).platform`. This plan follows the codebase's actual established pattern (manual `Theme.of(context).platform` branching / plain Material widgets with `CircleBorder`/`Material`+`InkWell`) rather than introducing a new dependency mid-plan; flagged here rather than silently ignored.
- **iOS-primary, Material-secondary adaptivity** — new widgets must not look wrong on either platform; keep controls small/neutral (icons + text) rather than platform-specific chrome.
- **The overlay must never block primary content** — small, bottom-trailing, `SafeArea`-respecting, clear of bottom nav / FABs / the note editor's media toolbar.
- **Save stays separate from Sync** — `MutateNote`/`LocalHmmNoteRepository` writes are instant and always succeed offline; sync is async/best-effort and only auto-triggers, never blocks, a save.
- **`local` and `cloudApi` modes: Sync control is neutral/disabled in Phase 1** — full per-tier behavior (Cloud API note routing, Local "not backed up" state) is explicitly **out of scope**, deferred to Phase 2.
- **No Phase 2 scope** — do not touch `hmmNoteRepositoryProvider`'s `cloudApi` branch (still `throw UnimplementedError`), do not build local-mode "Not backed up"/Export/Backup UI.

---

## Findings from reading the current code (read before executing any task)

1. **Gas logs do NOT go through `MutateNote.createGeneral`/`updateGeneral`.** `LocalGasLogRepository.createGasLog`/`updateGasLog` (`lib/core/data/local/local_gas_log_repository.dart`) call `IHmmNoteRepository.createNote`/`updateNote` **directly** (constructor-injected `_noteRepo`), never through `lib/features/notes/states/mutate_note_state.dart`. The spec's claim "gas logs are notes, so no separate gas-log wiring is needed" is only true if the `notifyLocalChange()` hook sits **below** `MutateNote`, at the shared repository chokepoint (`LocalHmmNoteRepository.createNote`/`updateNote`) — both `MutateNote` and `LocalGasLogRepository` resolve the exact same singleton instance via `ref.watch(localHmmNoteRepositoryProvider)`. **This plan deliberately wires Task 2 at `LocalHmmNoteRepository`, not at `mutate_note_state.dart`**, to actually satisfy the spec's coverage claim. Wiring only in `MutateNote` (the literal reading of the spec's Architecture §1) would silently miss gas logs.
2. **`hmmNoteRepositoryProvider` already throws for `cloudApi`** (`lib/core/data/repository_providers.dart:31`: `throw UnimplementedError('API note repository not yet implemented')`). So in `cloudApi` mode no note or gas-log write can succeed today — Task 2's "only when a sync orchestrator is active" gate is moot for `cloudApi` because writes never reach it. Confirms the spec's tier table (Phase 2 fixes this).
3. **The pending-count query is cheap but not exact.** `SyncOrchestrator._collectChangedNotes(cursor)` filters `lastModifiedDate > cursor`. It does **not** cover the self-healing "missing from remote" backfill (`_collectMissingFromRemote`), which requires pulling the remote manifest (a network call) to compute — not "cheap". `pendingChangeCount()` (Task 3) therefore mirrors only the `lastModifiedDate > cursor` leg and can **under-count** immediately after a rare cursor-drift event (see `findings.md` 2026-05-25 referenced in the orchestrator's comments) until the next real sync self-heals it. Documented in code and in Task 3 below rather than silently assumed away.
4. **No `ShellRoute`/`builder` exists today.** `lib/main.dart`'s `MaterialApp.router` has no `builder` param, and the Dashboard (`lib/features/dashboard/presentation/screens/dashboard_screen.dart:91`) builds a raw `Scaffold`, not `AppScaffold`. Mounting the overlay via `MaterialApp.router(builder: ...)` wrapping `child` in a `Stack` covers both cases with zero per-screen edits (verified: `Positioned` returned from a plain widget's `build()` is valid as a direct `Stack` child in Flutter's parent-data resolution).
5. **BuildContext ancestry problem for the overlay's dialogs/navigation.** `MaterialApp.router`'s `builder(context, child)` receives a `context` that sits **above** the Router/Navigator (the routed `child` contains the `Navigator`, not the other way around) — so `context.go(...)` (needs `GoRouter.of(context)`) and `showDialog`/`showModalBottomSheet` (need a `Navigator` ancestor) **do not work** from a widget stacked as a sibling of `child`. Fix used throughout this plan: (a) navigate via the `GoRouter` **instance method** `ref.read(AppRouter.config).go(...)` (works regardless of context position — no `BuildContext` needed), and (b) add a `rootNavigatorKey` to `GoRouter(...)` in `router_config.dart` and pass `rootNavigatorKey.currentContext!` as the `BuildContext` to `showDialog`/`showModalBottomSheet`/the existing `confirmManualSyncIfOnCellular(context, ref)` helper. This is a deliberate, simpler alternative to a literal `Overlay`/`OverlayEntry` construct — it satisfies "mount above the router, zero per-screen edits, top z-order" identically, is far easier to test, and is called out explicitly rather than silently reinterpreting the spec's wording.
6. **`Notes.lastModifiedDate` is nullable** (`lib/core/data/local/database.dart:68`) and has an index (`idx_notes_last_modified`) — `isBiggerThanValue(cursor)` already excludes null-mtime rows consistently with the orchestrator's existing push-collection query, so `pendingChangeCount()` reuses the identical comparison.

---

## Task 1: `SyncController.notifyLocalChange()` + `SyncTriggerReason.localChange` + debounce

**Files:**
- Modify: `lib/core/data/sync/sync_controller.dart`
- Test: `test/core/data/sync/sync_controller_test.dart`

**Interfaces:**
- Consumes: nothing new (pure addition to the existing `SyncController` class read at `lib/core/data/sync/sync_controller.dart:131-333`).
- Produces:
  - `SyncTriggerReason.localChange` (new enum value, `lib/core/data/sync/sync_controller.dart:15-29`).
  - `SyncController({..., this.localChangeDebounce = const Duration(seconds: 8)})` (new named constructor param).
  - `void SyncController.notifyLocalChange()` — (re)starts an 8s debounce timer that calls `triggerAutoSync(SyncTriggerReason.localChange)`. Consumed by Task 2.

- [ ] **Step 1: Write the failing tests**

Append to `test/core/data/sync/sync_controller_test.dart`, inside `void main() { ... }`, as a new top-level `group` (after the existing `group('SyncStatus updates', ...)` block, before the closing `}` of `main()`):

```dart
  group('notifyLocalChange (Part A — debounced auto-sync on write)', () {
    test('debounce coalesces N rapid calls into exactly one sync', () async {
      final c = SyncController(
        syncAction: action.call,
        now: clock.now,
        localChangeDebounce: const Duration(milliseconds: 30),
      );

      c.notifyLocalChange();
      c.notifyLocalChange();
      c.notifyLocalChange();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(action.callCount, equals(1),
          reason: 'three rapid notifyLocalChange calls should collapse '
              'into a single sync');
      expect(c.status.lastReason, equals(SyncTriggerReason.localChange));
      c.dispose();
    });

    test('a fresh call restarts the window (no fire until quiet for the '
        'full debounce)', () async {
      final c = SyncController(
        syncAction: action.call,
        now: clock.now,
        localChangeDebounce: const Duration(milliseconds: 40),
      );

      c.notifyLocalChange();
      await Future<void>.delayed(const Duration(milliseconds: 25));
      c.notifyLocalChange(); // restarts the 40ms window
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(action.callCount, equals(0),
          reason: 'still inside the restarted window');

      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(action.callCount, equals(1));
      c.dispose();
    });

    test('stop() cancels a pending debounce so it never fires', () async {
      final c = SyncController(
        syncAction: action.call,
        now: clock.now,
        localChangeDebounce: const Duration(milliseconds: 20),
      );
      c.start();
      c.notifyLocalChange();
      c.stop();

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(action.callCount, equals(0));
      c.dispose();
    });

    test('app-background flushes a pending debounce immediately', () async {
      final c = SyncController(
        syncAction: action.call,
        now: clock.now,
        localChangeDebounce: const Duration(seconds: 8), // long — must NOT wait
      );
      c.start();
      c.notifyLocalChange();

      _emitLifecycle(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(action.callCount, equals(1),
          reason: 'backgrounding should flush the debounce instead of '
              'waiting the full 8s');
      expect(c.status.lastReason, equals(SyncTriggerReason.localChange));
      c.dispose();
    });
  });
```

Delete the placeholder first test above (`'fires triggerAutoSync(localChange) after the debounce elapses'`) — it was scaffolding to think through the API and duplicates the coverage of the "coalesces" test. Final group has 4 tests: coalesces, restarts window, `stop()` cancels, background flushes. Rewrite the group body to:

```dart
  group('notifyLocalChange (Part A — debounced auto-sync on write)', () {
    test('debounce coalesces N rapid calls into exactly one sync', () async {
      final c = SyncController(
        syncAction: action.call,
        now: clock.now,
        localChangeDebounce: const Duration(milliseconds: 30),
      );

      c.notifyLocalChange();
      c.notifyLocalChange();
      c.notifyLocalChange();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(action.callCount, equals(1),
          reason: 'three rapid notifyLocalChange calls should collapse '
              'into a single sync');
      expect(c.status.lastReason, equals(SyncTriggerReason.localChange));
      c.dispose();
    });

    test('a fresh call restarts the window (no fire until quiet for the '
        'full debounce)', () async {
      final c = SyncController(
        syncAction: action.call,
        now: clock.now,
        localChangeDebounce: const Duration(milliseconds: 40),
      );

      c.notifyLocalChange();
      await Future<void>.delayed(const Duration(milliseconds: 25));
      c.notifyLocalChange(); // restarts the 40ms window
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(action.callCount, equals(0),
          reason: 'still inside the restarted window');

      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(action.callCount, equals(1));
      c.dispose();
    });

    test('stop() cancels a pending debounce so it never fires', () async {
      final c = SyncController(
        syncAction: action.call,
        now: clock.now,
        localChangeDebounce: const Duration(milliseconds: 20),
      );
      c.start();
      c.notifyLocalChange();
      c.stop();

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(action.callCount, equals(0));
      c.dispose();
    });

    test('app-background flushes a pending debounce immediately', () async {
      final c = SyncController(
        syncAction: action.call,
        now: clock.now,
        localChangeDebounce: const Duration(seconds: 8), // long — must NOT wait
      );
      c.start();
      c.notifyLocalChange();

      _emitLifecycle(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(action.callCount, equals(1),
          reason: 'backgrounding should flush the debounce instead of '
              'waiting the full 8s');
      expect(c.status.lastReason, equals(SyncTriggerReason.localChange));
      c.dispose();
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/data/sync/sync_controller_test.dart`
Expected: FAIL — `The named parameter 'localChangeDebounce' isn't defined` / `The method 'notifyLocalChange' isn't defined for the type 'SyncController'`.

- [ ] **Step 3: Add `SyncTriggerReason.localChange` and `notifyLocalChange()` to `SyncController`**

In `lib/core/data/sync/sync_controller.dart`, edit the enum (currently ends `periodic,\n}` around line 29):

```dart
enum SyncTriggerReason {
  /// User tapped the Sync Now button — bypasses the throttle window.
  manual,

  /// App returned to the foreground (debounced — see
  /// [SyncController.foregroundDebounce]).
  appForeground,

  /// App is going to the background — best-effort push of pending edits
  /// before the OS may suspend us.
  appBackground,

  /// 10-minute safety-net timer while the app is in `resumed`.
  periodic,

  /// A note (or gas log — gas logs are notes, see
  /// `LocalHmmNoteRepository`) was successfully written locally.
  /// Debounced by [SyncController.localChangeDebounce] so a burst of
  /// edits collapses into one sync. Fired via
  /// [SyncController.notifyLocalChange].
  localChange,
}
```

Edit the constructor (currently `lib/core/data/sync/sync_controller.dart:132-141`):

```dart
  SyncController({
    required SyncAction syncAction,
    CanAutoSyncCheck? canAutoSync,
    this.throttle = const Duration(seconds: 30),
    this.periodicInterval = const Duration(minutes: 10),
    this.foregroundDebounce = const Duration(milliseconds: 250),
    this.localChangeDebounce = const Duration(seconds: 8),
    ClockNow now = _defaultNow,
  })  : _syncAction = syncAction,
        _canAutoSync = canAutoSync ?? _alwaysAllow,
        _now = now;
```

Add the field next to `foregroundDebounce` (currently `lib/core/data/sync/sync_controller.dart:147`):

```dart
  final Duration foregroundDebounce;

  /// Debounce window for [notifyLocalChange] — a burst of note/gas-log
  /// writes within this window collapses into a single auto-sync. See
  /// Architecture §1 in `docs/superpowers/specs/2026-07-15-sync-safety-persistent-access-design.md`.
  final Duration localChangeDebounce;
  final ClockNow _now;
```

Add the timer field next to `_foregroundDebounceTimer` (currently `lib/core/data/sync/sync_controller.dart:153`):

```dart
  Timer? _periodicTimer;
  Timer? _foregroundDebounceTimer;
  Timer? _localChangeDebounceTimer;
```

Add the method (place after `triggerManualSync`, before `_executeWithGate`, i.e. after `lib/core/data/sync/sync_controller.dart:266`):

```dart
  /// Call after a successful local write to a note (or gas log — gas logs
  /// are notes, see `LocalHmmNoteRepository`) when a sync orchestrator is
  /// active. Callers are responsible for the "orchestrator active" gate
  /// (see `localHmmNoteRepositoryProvider` in
  /// `local_hmm_note_repository.dart`) — this method itself has no
  /// opinion on DataMode. (Re)starts [localChangeDebounce]; a burst of
  /// calls collapses into a single [triggerAutoSync]
  /// ([SyncTriggerReason.localChange]) call once the burst goes quiet.
  /// Flushed immediately (bypassing the wait) on app-background — see
  /// [didChangeAppLifecycleState] — and cancelled by [stop]/[dispose].
  void notifyLocalChange() {
    _localChangeDebounceTimer?.cancel();
    _localChangeDebounceTimer = Timer(localChangeDebounce, () {
      triggerAutoSync(SyncTriggerReason.localChange);
    });
  }
```

Update `stop()` (currently `lib/core/data/sync/sync_controller.dart:177-185`) to also cancel it:

```dart
  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _foregroundDebounceTimer?.cancel();
    _foregroundDebounceTimer = null;
    _localChangeDebounceTimer?.cancel();
    _localChangeDebounceTimer = null;
  }
```

Update the `AppLifecycleState.paused` case (currently `lib/core/data/sync/sync_controller.dart:207-216`) to flush a pending local-change debounce immediately instead of waiting:

```dart
      case AppLifecycleState.paused:
        // Cancel any pending foreground-debounce + the periodic timer
        // (no point running it while backgrounded). Best-effort fire
        // the background push.
        _foregroundDebounceTimer?.cancel();
        _foregroundDebounceTimer = null;
        _periodicTimer?.cancel();
        _periodicTimer = null;
        // Flush a pending localChange debounce NOW rather than waiting
        // out the full window — the OS may suspend us before it fires.
        // The resulting trigger still goes through the normal throttle +
        // network gate in triggerAutoSync.
        final hadPendingLocalChange = _localChangeDebounceTimer != null;
        _localChangeDebounceTimer?.cancel();
        _localChangeDebounceTimer = null;
        unawaited(triggerAutoSync(
          hadPendingLocalChange
              ? SyncTriggerReason.localChange
              : SyncTriggerReason.appBackground,
        ));
        break;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/data/sync/sync_controller_test.dart`
Expected: PASS (all tests, including the 4 new ones).

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/sync/sync_controller.dart test/core/data/sync/sync_controller_test.dart
git commit -m "$(cat <<'EOF'
feat(sync): add SyncController.notifyLocalChange debounced auto-sync

New SyncTriggerReason.localChange + notifyLocalChange() (Part A of the
sync-safety plan): an 8s debounce that coalesces bursts of local writes
into one auto-sync, flushed immediately on app-background.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Wire `notifyLocalChange()` from the note-write chokepoint (covers notes AND gas logs)

**Files:**
- Modify: `lib/core/data/local/local_hmm_note_repository.dart`
- Test: `test/core/data/local/local_hmm_note_repository_notify_test.dart` (new)

**Interfaces:**
- Consumes: `SyncController.notifyLocalChange()` (Task 1), `SyncOrchestrator.isActive` (existing getter, `lib/core/data/sync/sync_orchestrator.dart:67`), `syncOrchestratorProvider`/`syncControllerProvider` (existing providers).
- Produces: `LocalHmmNoteRepository({required HmmDatabase db, required Future<Author> Function() currentAuthor, void Function()? onLocalWrite})` — new optional named param, called after `createNote`/`updateNote` succeed. `localHmmNoteRepositoryProvider` wires it to `notifyLocalChange()` gated on `syncOrchestratorProvider.isActive`.

Per Finding 1 above: this task deliberately does **not** touch `lib/features/notes/states/mutate_note_state.dart` — `MutateNote.createGeneral`/`updateGeneral` already route through `hmmNoteRepositoryProvider` → `LocalHmmNoteRepository`, so hooking the repository covers both the notes editor AND `LocalGasLogRepository` (which calls the same repository instance directly) in one place. Hooking only `MutateNote` would miss gas logs, contradicting the spec's stated coverage.

- [ ] **Step 1: Write the failing test — repository fires the callback**

Create `test/core/data/local/local_hmm_note_repository_notify_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';

/// Regression coverage for the sync-safety incident: a successful local
/// write to a note (createNote/updateNote) must notify the caller-supplied
/// [LocalHmmNoteRepository.onLocalWrite] hook exactly once each — this is
/// the chokepoint both the notes editor (`MutateNote`) AND gas logs
/// (`LocalGasLogRepository`, which never goes through `MutateNote`) share,
/// so hooking here (not `MutateNote`) is what actually gives gas logs the
/// same auto-sync protection notes get. See Finding 1 in
/// `docs/superpowers/plans/2026-07-15-sync-safety-phase1.md`.
void main() {
  test('createNote and updateNote each call onLocalWrite once', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(authorId)))
        .getSingle();

    var writeCount = 0;
    final repo = LocalHmmNoteRepository(
      db,
      () async => author,
      onLocalWrite: () => writeCount++,
    );

    final created = await repo.createNote(
      const HmmNoteCreate(subject: 'Hi', catalogId: 1),
    );
    expect(writeCount, equals(1));

    await repo.updateNote(created.id, const HmmNoteUpdate(subject: 'Bye'));
    expect(writeCount, equals(2));
  });

  test('deleteNote and setParentNote do NOT call onLocalWrite (Phase 1 '
      'scope is create/update only — see spec §1)', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(authorId)))
        .getSingle();

    var writeCount = 0;
    final repo = LocalHmmNoteRepository(
      db,
      () async => author,
      onLocalWrite: () => writeCount++,
    );

    final created = await repo.createNote(
      const HmmNoteCreate(subject: 'Hi', catalogId: 1),
    );
    writeCount = 0; // ignore the create's own notification

    await repo.deleteNote(created.id);
    await repo.setParentNote(created.id, null);
    expect(writeCount, equals(0));
  });

  test('onLocalWrite is optional — omitting it is safe (existing call '
      'sites unaffected)', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(authorId)))
        .getSingle();

    final repo = LocalHmmNoteRepository(db, () async => author);
    await repo.createNote(const HmmNoteCreate(subject: 'Hi', catalogId: 1));
    // No throw = pass.
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/local/local_hmm_note_repository_notify_test.dart`
Expected: FAIL — `No named parameter with the name 'onLocalWrite'`.

- [ ] **Step 3: Add `onLocalWrite` to `LocalHmmNoteRepository`**

In `lib/core/data/local/local_hmm_note_repository.dart`, change the constructor (currently `lib/core/data/local/local_hmm_note_repository.dart:66`):

```dart
class LocalHmmNoteRepository implements IHmmNoteRepository {
  LocalHmmNoteRepository(this._db, this._currentAuthor, {void Function()? onLocalWrite})
      : _onLocalWrite = onLocalWrite;

  final HmmDatabase _db;
  final Future<Author> Function() _currentAuthor;

  /// Fired after `createNote`/`updateNote` complete a successful local
  /// write. Production wiring (`localHmmNoteRepositoryProvider`) points
  /// this at `SyncController.notifyLocalChange()`, gated on
  /// `syncOrchestratorProvider.isActive` — null (the default) makes this
  /// a no-op for tests and any future caller that doesn't care.
  final void Function()? _onLocalWrite;
```

Edit `createNote` (currently `lib/core/data/local/local_hmm_note_repository.dart:130-161`) to call it before returning:

```dart
  @override
  Future<HmmNote> createNote(HmmNoteCreate input) async {
    final author = await _currentAuthor();
    final now = DateTime.now().toUtc();
    final id = await _db.into(_db.notes).insert(NotesCompanion.insert(
          subject: input.subject,
          content: Value(input.content),
          authorId: author.id,
          catalogId: Value(input.catalogId),
          parentNoteId: Value(input.parentNoteId),
          description: Value(input.description),
          createDate: Value(now),
          noteDate: Value(input.noteDate ?? now),
          latitude: Value(
              input.location?.isEmpty == false ? input.location!.latitude : null),
          longitude: Value(
              input.location?.isEmpty == false ? input.location!.longitude : null),
          locationLabel: Value(
              input.location?.isEmpty == false ? input.location!.label : null),
          lastModifiedDate: Value(now),
          version: Value(_versionStamp()),
          uuid: input.uuid == null ? const Value.absent() : Value(input.uuid),
          attachments: Value(
            input.attachments == null
                ? null
                : NoteAttachmentsCodec.encode(input.attachments!),
          ),
        ));
    final note = (await getNoteById(id))!;
    _onLocalWrite?.call();
    return note;
  }
```

Edit `updateNote` (currently `lib/core/data/local/local_hmm_note_repository.dart:163-199`) the same way:

```dart
  @override
  Future<HmmNote> updateNote(int id, HmmNoteUpdate patch) async {
    if (patch.isEmpty) return (await getNoteById(id))!;
    final author = await _currentAuthor();
    final now = DateTime.now().toUtc();
    await (_db.update(_db.notes)
          ..where((n) => n.id.equals(id) & n.authorId.equals(author.id)))
        .write(NotesCompanion(
      subject: patch.subject != null ? Value(patch.subject!) : const Value.absent(),
      content: patch.content != null ? Value(patch.content) : const Value.absent(),
      description: patch.description != null
          ? Value(patch.description)
          : const Value.absent(),
      attachments: patch.attachments != null
          ? Value(NoteAttachmentsCodec.encode(patch.attachments!))
          : const Value.absent(),
      noteDate: patch.noteDate != null
          ? Value(patch.noteDate)
          : const Value.absent(),
      latitude: patch.location == null
          ? const Value.absent()
          : Value(patch.location!.latitude),
      longitude: patch.location == null
          ? const Value.absent()
          : Value(patch.location!.longitude),
      locationLabel: patch.location == null
          ? const Value.absent()
          : Value(patch.location!.label),
      lastModifiedDate: Value(now),
      version: Value(_versionStamp()),
    ));
    final note = (await getNoteById(id))!;
    _onLocalWrite?.call();
    return note;
  }
```

Leave `deleteNote` and `setParentNote` untouched (Phase 1 scope is create/update only, per the spec's Architecture §1 and §5 — "Save is unchanged in spirit... triggers the debounced auto-sync"; delete/re-parent auto-sync coverage is a documented Phase 1 gap, not a bug).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/data/local/local_hmm_note_repository_notify_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing test — provider wiring gates on `isActive`**

Create `test/core/data/local/local_hmm_note_repository_provider_wiring_test.dart`:

```dart
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../sync/onedrive_test_fakes.dart' show noopVaultStore;

/// Verifies `localHmmNoteRepositoryProvider`'s production wiring: writing
/// a note through the Riverpod-resolved repository calls
/// `SyncController.notifyLocalChange()` ONLY when a sync orchestrator is
/// active, and does nothing (no throw, no crash) when it isn't.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an active orchestrator: writing a note eventually triggers a sync',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));

    final fakeProvider = _FakeCloudSyncProvider();
    final orchestrator = SyncOrchestrator(
      provider: fakeProvider,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: noopVaultStore,
    );
    var syncCalls = 0;
    final controller = SyncController(
      syncAction: () async {
        syncCalls++;
        return SyncResult(
          pulledNotes: 0,
          pulledAttachments: 0,
          pushedNotes: 0,
          pushedAttachments: 0,
          completedAt: DateTime.now().toUtc(),
        );
      },
      localChangeDebounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWithValue(orchestrator),
      syncControllerProvider.overrideWithValue(controller),
    ]);
    addTearDown(container.dispose);

    await container.read(localHmmNoteRepositoryProvider).createNote(
          const HmmNoteCreate(subject: 'Hi', catalogId: 1),
        );

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(syncCalls, equals(1));
  });

  test('no active orchestrator (local mode): writing a note never triggers '
      'a sync', () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));

    final orchestrator = SyncOrchestrator(
      provider: null, // DataMode.local
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: noopVaultStore,
    );
    var syncCalls = 0;
    final controller = SyncController(
      syncAction: () async {
        syncCalls++;
        return SyncResult(
          pulledNotes: 0,
          pulledAttachments: 0,
          pushedNotes: 0,
          pushedAttachments: 0,
          completedAt: DateTime.now().toUtc(),
        );
      },
      localChangeDebounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWithValue(orchestrator),
      syncControllerProvider.overrideWithValue(controller),
    ]);
    addTearDown(container.dispose);

    await container.read(localHmmNoteRepositoryProvider).createNote(
          const HmmNoteCreate(subject: 'Hi', catalogId: 1),
        );

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(syncCalls, equals(0));
  });
}

class _FakeCloudSyncProvider extends CloudSyncProvider {
  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async => null;
  @override
  Future<void> pushManifest(SyncManifest manifest) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/core/data/local/local_hmm_note_repository_provider_wiring_test.dart`
Expected: FAIL — `syncCalls` stays `0` in the "active orchestrator" test (the provider doesn't wire `onLocalWrite` yet).

- [ ] **Step 7: Wire `localHmmNoteRepositoryProvider`**

In `lib/core/data/local/local_hmm_note_repository.dart`, add imports and edit the bottom provider (currently `lib/core/data/local/local_hmm_note_repository.dart:255-260`):

```dart
import '../sync/sync_controller.dart';
import '../sync/sync_orchestrator.dart';
```

```dart
final localHmmNoteRepositoryProvider = Provider<IHmmNoteRepository>((ref) {
  return LocalHmmNoteRepository(
    ref.watch(hmmDatabaseProvider),
    () => ref.read(currentAuthorProvider.future),
    // Debounced auto-sync on write (Part A of the sync-safety plan). Gate
    // on `isActive` so local/cloudApi modes stay no-ops in Phase 1 — read
    // (not watch) both providers since this closure runs later, at write
    // time, not during this provider's build.
    onLocalWrite: () {
      if (ref.read(syncOrchestratorProvider).isActive) {
        ref.read(syncControllerProvider).notifyLocalChange();
      }
    },
  );
});
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/core/data/local/local_hmm_note_repository_provider_wiring_test.dart`
Expected: PASS.

- [ ] **Step 9: Run the full existing note + gas-log + sync suites for regressions**

Run: `flutter test test/core/data/local/ test/core/data/sync/ test/features/notes/ test/features/gas_log/`
Expected: PASS (no regressions — `LocalHmmNoteRepository`'s public behavior is unchanged for callers that don't pass `onLocalWrite`).

- [ ] **Step 10: Commit**

```bash
git add lib/core/data/local/local_hmm_note_repository.dart test/core/data/local/local_hmm_note_repository_notify_test.dart test/core/data/local/local_hmm_note_repository_provider_wiring_test.dart
git commit -m "$(cat <<'EOF'
feat(sync): wire notifyLocalChange at the note-write chokepoint

LocalHmmNoteRepository.createNote/updateNote now call an optional
onLocalWrite hook, wired in localHmmNoteRepositoryProvider to
SyncController.notifyLocalChange() gated on syncOrchestratorProvider
.isActive. Hooked at the repository (not MutateNote) so gas logs —
which write notes directly via LocalGasLogRepository, bypassing
MutateNote — get the same debounced auto-sync protection as the notes
editor.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `pendingSyncCountProvider`

**Files:**
- Modify: `lib/core/data/sync/sync_orchestrator.dart`
- Create: `lib/core/data/sync/pending_sync_count_provider.dart`
- Test: `test/core/data/sync/sync_orchestrator_pending_count_test.dart` (new), `test/core/data/sync/pending_sync_count_provider_test.dart` (new)

**Interfaces:**
- Consumes: `SyncOrchestrator.provider`/`isActive` (existing), `SyncMetaRepository.getLastPushedAt` (existing, `lib/core/data/sync/sync_meta_repository.dart:17`), `hmmDatabaseProvider`, `syncOrchestratorProvider`, `syncControllerProvider` (existing).
- Produces: `Future<int> SyncOrchestrator.pendingChangeCount()`. `final pendingSyncCountProvider = StreamProvider.autoDispose<int>(...)` — consumed by Tasks 4/5/6 as `ref.watch(pendingSyncCountProvider)` (an `AsyncValue<int>`; use `.value ?? 0`, never `.valueOrNull`).

- [ ] **Step 1: Write the failing test for `SyncOrchestrator.pendingChangeCount()`**

Create `test/core/data/sync/sync_orchestrator_pending_count_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'onedrive_test_fakes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coverage for the "cheap COUNT of notes changed since the last-pushed
/// cursor" query (Finding 3 in the Phase 1 plan: this mirrors ONLY the
/// `lastModifiedDate > cursor` leg of `syncNow()`'s push collection — it
/// does NOT run the missing-from-remote self-healing check, which needs a
/// network round-trip and isn't "cheap").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _FakeCloudSyncProvider provider;
  late SyncOrchestrator orchestrator;
  late SyncMetaRepository meta;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    provider = _FakeCloudSyncProvider();
    meta = SyncMetaRepository();
    orchestrator = SyncOrchestrator(
        provider: provider, db: db, meta: meta, vaultStore: noopVaultStore);
  });

  tearDown(() async => db.close());

  test('0 when nothing has ever been synced and no notes exist', () async {
    expect(await orchestrator.pendingChangeCount(), equals(0));
  });

  test('counts notes modified after the cursor', () async {
    final cursor = DateTime.utc(2026, 5, 25, 12);
    await meta.setLastPushedAt(provider.providerId, cursor);

    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'after cursor',
          authorId: 1,
          createDate: Value(cursor.add(const Duration(minutes: 1))),
          lastModifiedDate: Value(cursor.add(const Duration(minutes: 1))),
        ));
    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'before cursor',
          authorId: 1,
          createDate: Value(cursor.subtract(const Duration(minutes: 1))),
          lastModifiedDate: Value(cursor.subtract(const Duration(minutes: 1))),
        ));

    expect(await orchestrator.pendingChangeCount(), equals(1));
  });

  test('0 when a provider is not active (DataMode.local)', () async {
    final noSyncOrchestrator = SyncOrchestrator(
        provider: null, db: db, meta: meta, vaultStore: noopVaultStore);
    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'irrelevant', authorId: 1));
    expect(await noSyncOrchestrator.pendingChangeCount(), equals(0));
  });
}

class _FakeCloudSyncProvider extends CloudSyncProvider {
  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async => null;
  @override
  Future<void> pushManifest(SyncManifest manifest) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/sync/sync_orchestrator_pending_count_test.dart`
Expected: FAIL — `The method 'pendingChangeCount' isn't defined for the type 'SyncOrchestrator'`.

- [ ] **Step 3: Add `pendingChangeCount()` to `SyncOrchestrator`**

In `lib/core/data/sync/sync_orchestrator.dart`, add a new method right after the `syncNow()` method ends (after `lib/core/data/sync/sync_orchestrator.dart:277`, before `// ==================== PULL helpers ====================`):

```dart
  /// Cheap COUNT of local notes changed since the last-pushed cursor for
  /// the active provider — the same `lastModifiedDate > cursor` leg
  /// `syncNow()` uses to collect its push queue (`_collectChangedNotes`),
  /// but without materialising the rows. Drives
  /// `pendingSyncCountProvider`'s pill badge + blocked/failed prompt.
  ///
  /// NOT exact: does not include the `_collectMissingFromRemote`
  /// self-healing set (that requires pulling the remote manifest — a
  /// network call, not "cheap"). Immediately after a rare cursor-drift
  /// event this can under-report until the next real sync self-heals it.
  /// Returns 0 when no provider is active ([isActive] is false).
  Future<int> pendingChangeCount() async {
    final p = provider;
    if (p == null) return 0;
    final cursor = await _meta.getLastPushedAt(p.providerId) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final countExp = _db.notes.id.count();
    final query = _db.selectOnly(_db.notes)
      ..addColumns([countExp])
      ..where(_db.notes.lastModifiedDate.isBiggerThanValue(cursor));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/data/sync/sync_orchestrator_pending_count_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing test for the reactive provider**

Create `test/core/data/sync/pending_sync_count_provider_test.dart`:

```dart
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/pending_sync_count_provider.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('0 when no orchestrator is active', () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final orchestrator = SyncOrchestrator(
      provider: null,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: () async => throw UnimplementedError(),
    );
    final controller = SyncController(syncAction: () async {
      throw StateError('should never be called — no provider');
    });
    addTearDown(controller.dispose);

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWithValue(orchestrator),
      syncControllerProvider.overrideWithValue(controller),
    ]);
    addTearDown(container.dispose);

    final value = await container.read(pendingSyncCountProvider.future);
    expect(value, equals(0));
  });

  test('recomputes when the notes table changes', () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));

    final fakeProvider = _FakeCloudSyncProvider();
    final orchestrator = SyncOrchestrator(
      provider: fakeProvider,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: () async => throw UnimplementedError(),
    );
    final controller = SyncController(syncAction: () async {
      throw StateError('not exercised in this test');
    });
    addTearDown(controller.dispose);

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWithValue(orchestrator),
      syncControllerProvider.overrideWithValue(controller),
      localHmmNoteRepositoryProvider.overrideWith(
        (ref) => _NoHookNoteRepoForTest(db),
      ),
    ]);
    addTearDown(container.dispose);

    final completer = Completer<int>();
    final sub = container.listen<AsyncValue<int>>(
      pendingSyncCountProvider,
      (prev, next) {
        final v = next.value;
        if (v != null && v > 0 && !completer.isCompleted) {
          completer.complete(v);
        }
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final initial = await container.read(pendingSyncCountProvider.future);
    expect(initial, equals(0));

    await container
        .read(hmmNoteRepositoryProvider)
        .createNote(const HmmNoteCreate(subject: 'new', catalogId: 1));

    final after = await completer.future.timeout(const Duration(seconds: 2));
    expect(after, equals(1));
  });

  test('recomputes to 0 after a sync completes (cursor advances) even '
      'though the note row itself did not change', () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    await db
        .into(db.notes)
        .insert(NotesCompanion.insert(subject: 'pending', authorId: 1));

    final fakeProvider = _FakeCloudSyncProvider();
    final meta = SyncMetaRepository();
    final orchestrator = SyncOrchestrator(
      provider: fakeProvider,
      db: db,
      meta: meta,
      vaultStore: () async => throw UnimplementedError(),
    );
    // Real syncAction = orchestrator.syncNow, so a successful sync
    // actually advances the meta cursor — the effect under test.
    final controller = SyncController(syncAction: orchestrator.syncNow);
    addTearDown(controller.dispose);

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWithValue(orchestrator),
      syncControllerProvider.overrideWithValue(controller),
    ]);
    addTearDown(container.dispose);

    final before = await container.read(pendingSyncCountProvider.future);
    expect(before, equals(1));

    final result = await controller.triggerManualSync();
    expect(result!.success, isTrue);

    final completer = Completer<int>();
    final sub = container.listen<AsyncValue<int>>(
      pendingSyncCountProvider,
      (prev, next) {
        final v = next.value;
        if (v != null && v == 0 && !completer.isCompleted) {
          completer.complete(v);
        }
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final after = await completer.future.timeout(const Duration(seconds: 2));
    expect(after, equals(0));
  });
}

class _FakeCloudSyncProvider extends CloudSyncProvider {
  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async => null;
  @override
  Future<void> pushManifest(SyncManifest manifest) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}
}
```

`_NoHookNoteRepoForTest` isn't actually needed — `hmmNoteRepositoryProvider`/`localHmmNoteRepositoryProvider` already work fine with the default (no `onLocalWrite`) `LocalHmmNoteRepository` built by the real provider (Task 2's `onLocalWrite` closure reads `syncOrchestratorProvider`/`syncControllerProvider`, both overridden here, so it's harmless — it will call `controller.notifyLocalChange()` too, which is fine since this test's `controller.syncAction` throws only if actually invoked within THIS test's assertions window; the debounce default is 8s, far outside the test's `Future.delayed`/`Completer.timeout` windows, so it never fires). Remove the `localHmmNoteRepositoryProvider.overrideWith(...)` override and the unused class from the "recomputes when the notes table changes" test — simplify to:

```dart
    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWithValue(orchestrator),
      syncControllerProvider.overrideWithValue(controller),
    ]);
    addTearDown(container.dispose);
```

(Same three overrides as the other two tests — delete the `_NoHookNoteRepoForTest` class entirely.)

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/core/data/sync/pending_sync_count_provider_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:hmm_console/core/data/sync/pending_sync_count_provider.dart'`.

- [ ] **Step 7: Create `pendingSyncCountProvider`**

Create `lib/core/data/sync/pending_sync_count_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database.dart';
import 'sync_controller.dart';
import 'sync_orchestrator.dart';

/// Cheap "how many local notes haven't reached the cloud yet" count.
/// Drives the persistent Sync pill's badge (`SyncPill`) and the
/// blocked/failed anti-loss prompt (`pending_sync_prompt.dart`). See
/// `docs/superpowers/specs/2026-07-15-sync-safety-persistent-access-design.md`.
///
/// Recomputes whenever:
///   - the Notes table changes (any write, from any feature — mirrors the
///     same drift `.watch()` reactivity `notesListStateProvider` relies
///     on), or
///   - a sync completes (the SyncController ChangeNotifier fires — this
///     catches the case a push advances the cursor without the local Notes
///     row's `lastModifiedDate` changing).
///
/// 0 when no sync orchestrator is active (`local`/`cloudApi` in Phase 1 —
/// see `SyncOrchestrator.isActive`).
final pendingSyncCountProvider = StreamProvider.autoDispose<int>((ref) {
  final orchestrator = ref.watch(syncOrchestratorProvider);
  final controller = ref.watch(syncControllerProvider);
  final db = ref.watch(hmmDatabaseProvider);

  if (!orchestrator.isActive) {
    return Stream.value(0);
  }

  final out = StreamController<int>();

  Future<void> emit() async {
    if (out.isClosed) return;
    out.add(await orchestrator.pendingChangeCount());
  }

  final dbSub = db.select(db.notes).watch().listen((_) => emit());
  void onControllerChange() => emit();
  controller.addListener(onControllerChange);

  ref.onDispose(() {
    dbSub.cancel();
    controller.removeListener(onControllerChange);
    out.close();
  });

  emit(); // Seed the first value without waiting for a table event.

  return out.stream;
});
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/core/data/sync/pending_sync_count_provider_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/core/data/sync/sync_orchestrator.dart lib/core/data/sync/pending_sync_count_provider.dart test/core/data/sync/sync_orchestrator_pending_count_test.dart test/core/data/sync/pending_sync_count_provider_test.dart
git commit -m "$(cat <<'EOF'
feat(sync): add pendingSyncCountProvider (pending-changes signal)

SyncOrchestrator.pendingChangeCount() is a cheap COUNT of notes changed
since the last-pushed cursor (mirrors the lastModifiedDate > cursor leg
of syncNow()'s push collection — NOT the missing-from-remote
self-healing set, which needs a network round trip). Exposed reactively
via pendingSyncCountProvider, recomputing on notes-table writes and on
sync completion, gated to 0 when no orchestrator is active.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Blocked/failed prompt — pure decision function

**Files:**
- Create: `lib/core/data/sync/pending_sync_prompt.dart`
- Test: `test/core/data/sync/pending_sync_prompt_test.dart` (new)

**Interfaces:**
- Consumes: nothing (pure function — no Riverpod, no Flutter).
- Produces: `bool shouldPromptPendingSync({required int pendingCount, required bool autoSyncSkippedForNetwork, required bool lastSyncFailed})` and `const int pendingSyncPromptThreshold`. Consumed by Task 6's `HomeSyncOverlay`.

- [ ] **Step 1: Write the failing test**

Create `test/core/data/sync/pending_sync_prompt_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/pending_sync_prompt.dart';

void main() {
  group('shouldPromptPendingSync', () {
    test('false when nothing is pending', () {
      expect(
        shouldPromptPendingSync(
          pendingCount: 0,
          autoSyncSkippedForNetwork: true,
          lastSyncFailed: true,
        ),
        isFalse,
      );
    });

    test('false when pending but auto-sync is neither blocked nor failing',
        () {
      expect(
        shouldPromptPendingSync(
          pendingCount: 3,
          autoSyncSkippedForNetwork: false,
          lastSyncFailed: false,
        ),
        isFalse,
      );
    });

    test('true when pending AND blocked by the WiFi-only network policy',
        () {
      expect(
        shouldPromptPendingSync(
          pendingCount: 1,
          autoSyncSkippedForNetwork: true,
          lastSyncFailed: false,
        ),
        isTrue,
      );
    });

    test('true when pending AND the last sync failed', () {
      expect(
        shouldPromptPendingSync(
          pendingCount: 1,
          autoSyncSkippedForNetwork: false,
          lastSyncFailed: true,
        ),
        isTrue,
      );
    });

    test('true when both blocked and failed', () {
      expect(
        shouldPromptPendingSync(
          pendingCount: 5,
          autoSyncSkippedForNetwork: true,
          lastSyncFailed: true,
        ),
        isTrue,
      );
    });
  });

  test('pendingSyncPromptThreshold is a small positive constant', () {
    expect(pendingSyncPromptThreshold, greaterThan(0));
    expect(pendingSyncPromptThreshold, lessThanOrEqualTo(10));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/sync/pending_sync_prompt_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:hmm_console/core/data/sync/pending_sync_prompt.dart'`.

- [ ] **Step 3: Create `pending_sync_prompt.dart`**

Create `lib/core/data/sync/pending_sync_prompt.dart`:

```dart
/// Pure decision logic for the "blocked/failed safety net" prompt (Part A
/// anti-loss — see
/// `docs/superpowers/specs/2026-07-15-sync-safety-persistent-access-design.md`).
/// No Flutter/Riverpod imports so it's trivially unit-testable; the
/// widget layer (`HomeSyncOverlay`, Task 6) supplies the live values and
/// owns WHEN to call it (app-background, or a threshold crossing it
/// detects itself via `ref.listen` since that needs the previous value).
library;

/// Small pending-count threshold that, when crossed upward, is ALSO a
/// trigger for the prompt (independent of app-background) — see the
/// spec's Architecture §3: "on app-background (or when the count crosses
/// a small threshold)".
const int pendingSyncPromptThreshold = 5;

/// True when there's local data at risk (`pendingCount > 0`) AND
/// auto-sync is currently unable to reach the cloud on its own — either
/// gated by the WiFi-only network policy ([autoSyncSkippedForNetwork],
/// mirrors `SyncStatus.lastAutoTriggerSkippedForNetwork`) or the most
/// recent sync attempt failed ([lastSyncFailed], mirrors
/// `SyncStatus.lastResult != null && !SyncStatus.lastResult!.success`).
bool shouldPromptPendingSync({
  required int pendingCount,
  required bool autoSyncSkippedForNetwork,
  required bool lastSyncFailed,
}) {
  if (pendingCount <= 0) return false;
  return autoSyncSkippedForNetwork || lastSyncFailed;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/data/sync/pending_sync_prompt_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/sync/pending_sync_prompt.dart test/core/data/sync/pending_sync_prompt_test.dart
git commit -m "$(cat <<'EOF'
feat(sync): add shouldPromptPendingSync pure decision function

Part A anti-loss safety net: pending changes + (WiFi-gated OR last
sync failed) => prompt. Pure/no-Flutter so it's cheaply unit tested;
consumed by HomeSyncOverlay in Task 6.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `rootNavigatorKey` + `HomeButton` + `SyncPill` widgets

**Files:**
- Modify: `lib/core/navigation/router_config.dart`
- Create: `lib/core/widgets/home_button.dart`, `lib/core/widgets/sync_pill.dart`
- Test: `test/core/widgets/home_button_test.dart` (new), `test/core/widgets/sync_pill_test.dart` (new)

**Interfaces:**
- Consumes: `AppRouter.config` (existing, `lib/core/navigation/router.dart:18`), `dataModeProvider`, `syncControllerProvider`, `pendingSyncCountProvider` (Task 3), `confirmManualSyncIfOnCellular` (existing, `lib/features/settings/presentation/widgets/sync_status_card.dart:155`).
- Produces: `final rootNavigatorKey = GlobalKey<NavigatorState>();` (top-level in `router_config.dart`), `class HomeButton extends ConsumerWidget`, `class SyncPill extends ConsumerWidget`. Consumed by Task 6's `HomeSyncOverlay`.

Per Finding 5: `rootNavigatorKey` is needed because `MaterialApp.router`'s `builder`-level context has no `Navigator` ancestor, so `SyncPill`'s dialogs/sheets must target `rootNavigatorKey.currentContext` explicitly instead of the widget's own `context`.

- [ ] **Step 1: Add `rootNavigatorKey` to the router config**

In `lib/core/navigation/router_config.dart`, add an import and a top-level key, then wire it into `GoRouter(...)`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
```

```dart
/// Shared with `HomeSyncOverlay`/`SyncPill` (mounted above the router in
/// `main.dart`'s `MaterialApp.router(builder: ...)`) so they can show
/// dialogs/bottom sheets via `rootNavigatorKey.currentContext` — their own
/// `BuildContext` has no `Navigator` ancestor (see Finding 5 in
/// `docs/superpowers/plans/2026-07-15-sync-safety-phase1.md`).
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerConfig = Provider<GoRouter>(
  (ref) => GoRouter(
    navigatorKey: rootNavigatorKey,
    redirect: (context, state) {
```

(`redirect: (context, state) {` is the existing next line at `lib/core/navigation/router_config.dart:35` — insert `navigatorKey: rootNavigatorKey,` immediately before it, as the new first named argument to `GoRouter(`.)

This has no behavior to unit test on its own (it's plumbing consumed by Step 3+ below); proceed straight to `HomeButton`.

- [ ] **Step 2: Write the failing test for `HomeButton`**

Create `test/core/widgets/home_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/router.dart';
import 'package:hmm_console/core/widgets/home_button.dart';

void main() {
  testWidgets('tapping Home navigates the app GoRouter to "/"',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/other',
      routes: [
        GoRoute(path: '/', builder: (c, s) => const Text('dashboard')),
        GoRoute(
          path: '/other',
          builder: (c, s) => const Scaffold(body: HomeButton()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [AppRouter.config.overrideWithValue(router)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text('dashboard'), findsNothing);

    await tester.tap(find.byType(HomeButton));
    await tester.pumpAndSettle();

    expect(find.text('dashboard'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/widgets/home_button_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:hmm_console/core/widgets/home_button.dart'`.

- [ ] **Step 4: Create `HomeButton`**

Create `lib/core/widgets/home_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/router.dart';

/// Small floating control that jumps to the Dashboard from anywhere in
/// the app. Lives inside the persistent Home+Sync overlay (mounted once,
/// above the router, in `main.dart` — see `HomeSyncOverlay`), never
/// per-screen.
///
/// Uses the `GoRouter` INSTANCE's `.go()` method directly (not the
/// `context.go(...)` extension) because this widget's `BuildContext` sits
/// above the Router in the tree (see Finding 5 in
/// `docs/superpowers/plans/2026-07-15-sync-safety-phase1.md`), so it has
/// no `GoRouter` ancestor to resolve via `GoRouter.of(context)`.
class HomeButton extends ConsumerWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: const Icon(Icons.home_outlined),
        tooltip: 'Home',
        onPressed: () => ref.read(AppRouter.config).go('/'),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/widgets/home_button_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the failing tests for `SyncPill`**

Create `test/core/widgets/sync_pill_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/pending_sync_count_provider.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/navigation/router_config.dart' show rootNavigatorKey;
import 'package:hmm_console/core/widgets/sync_pill.dart';

Future<void> _pump(
  WidgetTester tester, {
  required DataMode mode,
  SyncController? controller,
  int pending = 0,
}) async {
  final c = controller ??
      SyncController(syncAction: () async => SyncResult(
            pulledNotes: 0,
            pulledAttachments: 0,
            pushedNotes: 0,
            pushedAttachments: 0,
            completedAt: DateTime.now().toUtc(),
          ));
  addTearDown(c.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _FixedDataMode(mode)),
        syncControllerProvider.overrideWithValue(c),
        pendingSyncCountProvider.overrideWith((ref) => Stream.value(pending)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Scaffold(body: SyncPill()),
      ),
    ),
  );
  await tester.pump();
}

class _FixedDataMode extends DataModeNotifier {
  _FixedDataMode(this._mode);
  final DataMode _mode;
  @override
  DataMode build() => _mode;
}

void main() {
  testWidgets('local mode renders a neutral/disabled chip', (tester) async {
    await _pump(tester, mode: DataMode.local);
    expect(find.text('Local only'), findsOneWidget);
  });

  testWidgets('cloudApi mode renders a neutral/disabled chip (Phase 1)',
      (tester) async {
    await _pump(tester, mode: DataMode.cloudApi);
    expect(find.text('Cloud (soon)'), findsOneWidget);
  });

  testWidgets('cloudStorage + synced renders "Synced"', (tester) async {
    final c = SyncController(syncAction: () async => SyncResult(
          pulledNotes: 0,
          pulledAttachments: 0,
          pushedNotes: 0,
          pushedAttachments: 0,
          completedAt: DateTime.now().toUtc(),
        ));
    await _pump(tester, mode: DataMode.cloudStorage, controller: c, pending: 0);
    expect(find.text('Synced'), findsOneWidget);
  });

  testWidgets('cloudStorage + pending renders "N unsynced"', (tester) async {
    await _pump(tester, mode: DataMode.cloudStorage, pending: 3);
    expect(find.text('3 unsynced'), findsOneWidget);
  });

  testWidgets('cloudStorage + syncing renders "Syncing…"', (tester) async {
    final c = SyncController(syncAction: () => Completer<SyncResult>().future);
    await _pump(tester, mode: DataMode.cloudStorage, controller: c);
    await c.triggerManualSync();
    await tester.pump();
    expect(find.text('Syncing…'), findsOneWidget);
  });
}
```

Fix the missing `Completer` import in that last test — add `import 'dart:async';` at the top of the file.

- [ ] **Step 7: Run test to verify it fails**

Run: `flutter test test/core/widgets/sync_pill_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:hmm_console/core/widgets/sync_pill.dart'`.

- [ ] **Step 8: Create `SyncPill`**

Create `lib/core/widgets/sync_pill.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_mode.dart';
import '../data/sync/pending_sync_count_provider.dart';
import '../data/sync/sync_controller.dart';
import '../navigation/router.dart';
import '../navigation/router_config.dart' show rootNavigatorKey;
import '../../features/settings/presentation/widgets/sync_status_card.dart'
    show confirmManualSyncIfOnCellular;

/// Mode-adaptive sync status chip. Part of the persistent Home+Sync
/// overlay (`HomeSyncOverlay`, Task 6).
///
/// - `local` / `cloudApi` (Phase 1): neutral/disabled — full per-tier
///   behavior lands in Phase 2 (design doc phasing).
/// - `cloudStorage`: live status (synced / syncing / N unsynced / error) —
///   tap = sync now (cellular-confirm, reusing the same helper as
///   Settings' `SyncStatusCard`); long-press = mini sheet with
///   last-synced + pending count + a jump to Settings.
class SyncPill extends ConsumerWidget {
  const SyncPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(dataModeProvider);
    final cs = Theme.of(context).colorScheme;

    if (mode != DataMode.cloudStorage) {
      return _Chip(
        icon: Icons.cloud_off,
        label: mode == DataMode.local ? 'Local only' : 'Cloud (soon)',
        color: cs.onSurfaceVariant,
        onTap: () {
          final navContext = rootNavigatorKey.currentContext;
          if (navContext == null) return;
          ScaffoldMessenger.maybeOf(navContext)?.showSnackBar(
            SnackBar(
              content: Text(
                mode == DataMode.local
                    ? 'Local mode has no cloud sync yet.'
                    : 'Cloud (API) sync is not available yet.',
              ),
            ),
          );
        },
      );
    }

    final controller = ref.watch(syncControllerProvider);
    final pendingAsync = ref.watch(pendingSyncCountProvider);
    final pending = pendingAsync.value ?? 0;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final status = controller.status;
        IconData icon;
        String label;
        Color color = cs.primary;

        if (status.isSyncing) {
          icon = Icons.sync;
          label = 'Syncing…';
        } else if (status.consecutiveFailures >= 3 ||
            (status.lastResult != null && !status.lastResult!.success)) {
          icon = Icons.error_outline;
          label = pending > 0 ? '$pending unsynced · error' : 'Sync error';
          color = cs.error;
        } else if (status.lastAutoTriggerSkippedForNetwork) {
          icon = Icons.wifi_off;
          label =
              pending > 0 ? '$pending unsynced · WiFi' : 'Waiting for WiFi';
          color = cs.tertiary;
        } else if (pending > 0) {
          icon = Icons.cloud_upload_outlined;
          label = '$pending unsynced';
          color = cs.tertiary;
        } else {
          icon = Icons.cloud_done_outlined;
          label = 'Synced';
        }

        return _Chip(
          icon: icon,
          label: label,
          color: color,
          onTap: status.isSyncing
              ? null
              : () async {
                  final navContext = rootNavigatorKey.currentContext;
                  if (navContext == null) return;
                  final proceed =
                      await confirmManualSyncIfOnCellular(navContext, ref);
                  if (!proceed) return;
                  await controller.triggerManualSync();
                },
          onLongPress: () => _showMiniSheet(ref, controller, pending),
        );
      },
    );
  }

  void _showMiniSheet(WidgetRef ref, SyncController controller, int pending) {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;
    final status = controller.status;
    showModalBottomSheet<void>(
      context: navContext,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.lastSyncAt == null
                    ? 'Never synced'
                    : 'Last synced: ${status.lastSyncAt}',
              ),
              const SizedBox(height: 4),
              Text('$pending change${pending == 1 ? '' : 's'} pending'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ref.read(AppRouter.config).push('/settings');
                },
                child: const Text('Open sync settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: Run test to verify it passes**

Run: `flutter test test/core/widgets/sync_pill_test.dart`
Expected: PASS.

- [ ] **Step 10: Run the full router/settings suite for regressions**

Run: `flutter test test/core/navigation/ test/features/settings/`
Expected: PASS (adding `navigatorKey` to `GoRouter(...)` is additive and does not change existing route behavior).

- [ ] **Step 11: Commit**

```bash
git add lib/core/navigation/router_config.dart lib/core/widgets/home_button.dart lib/core/widgets/sync_pill.dart test/core/widgets/home_button_test.dart test/core/widgets/sync_pill_test.dart
git commit -m "$(cat <<'EOF'
feat(sync): add rootNavigatorKey + HomeButton + SyncPill widgets

rootNavigatorKey lets widgets mounted above the router (Task 6's
HomeSyncOverlay) reach a Navigator-ancestored BuildContext for
dialogs/sheets. HomeButton uses the GoRouter instance's .go() method
directly (no context needed). SyncPill is the mode-adaptive status
chip: neutral/disabled in local/cloudApi (Phase 1), live status +
tap-to-sync + long-press mini sheet in cloudStorage.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `HomeSyncOverlay` — mount globally + blocked/failed prompt integration

**Files:**
- Create: `lib/core/widgets/home_sync_overlay.dart`
- Modify: `lib/main.dart`
- Test: `test/core/widgets/home_sync_overlay_test.dart` (new)

**Interfaces:**
- Consumes: `HomeButton`, `SyncPill` (Task 5), `pendingSyncCountProvider` (Task 3), `shouldPromptPendingSync`/`pendingSyncPromptThreshold` (Task 4), `syncControllerProvider`, `confirmManualSyncIfOnCellular`, `rootNavigatorKey`.
- Produces: `class HomeSyncOverlay extends ConsumerStatefulWidget` — mounted once in `main.dart`'s `MaterialApp.router(builder: ...)`.

- [ ] **Step 1: Write the failing tests**

Create `test/core/widgets/home_sync_overlay_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/pending_sync_count_provider.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/navigation/router_config.dart' show rootNavigatorKey;
import 'package:hmm_console/core/widgets/home_button.dart';
import 'package:hmm_console/core/widgets/home_sync_overlay.dart';
import 'package:hmm_console/core/widgets/sync_pill.dart';

class _FixedDataMode extends DataModeNotifier {
  _FixedDataMode(this._mode);
  final DataMode _mode;
  @override
  DataMode build() => _mode;
}

SyncController _idleController() {
  final c = SyncController(syncAction: () async => SyncResult(
        pulledNotes: 0,
        pulledAttachments: 0,
        pushedNotes: 0,
        pushedAttachments: 0,
        completedAt: DateTime.now().toUtc(),
      ));
  return c;
}

void main() {
  testWidgets('renders Home + Sync controls over a raw Scaffold '
      '(mimics DashboardScreen)', (tester) async {
    final c = _idleController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
          syncControllerProvider.overrideWithValue(c),
          pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: Stack(
            children: [
              Scaffold(body: const Center(child: Text('dashboard content'))),
              const HomeSyncOverlay(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('dashboard content'), findsOneWidget);
    expect(find.byType(HomeButton), findsOneWidget);
    expect(find.byType(SyncPill), findsOneWidget);
  });

  testWidgets('does not block taps on content behind it', (tester) async {
    final c = _idleController();
    addTearDown(c.dispose);
    var tapped = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.local)),
          syncControllerProvider.overrideWithValue(c),
          pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: Stack(
            children: [
              Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: TextButton(
                    onPressed: () => tapped = true,
                    child: const Text('top-left button'),
                  ),
                ),
              ),
              const HomeSyncOverlay(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('top-left button'));
    expect(tapped, isTrue,
        reason: 'overlay is bottom-trailing; must not intercept taps '
            'elsewhere on the screen');
  });

  testWidgets('a threshold-crossing pending count shows the anti-loss '
      'prompt', (tester) async {
    final c = SyncController(syncAction: () async => throw StateError('x'));
    addTearDown(c.dispose);
    // Force the "blocked" condition via a failed prior sync so
    // shouldPromptPendingSync's gate is satisfied once pending crosses
    // the threshold.
    await c.triggerAutoSync(SyncTriggerReason.periodic); // records a failure

    final controller = StreamController<int>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
          syncControllerProvider.overrideWithValue(c),
          pendingSyncCountProvider.overrideWith((ref) => controller.stream),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Stack(children: [HomeSyncOverlay()]),
        ),
      ),
    );
    await tester.pump();

    controller.add(0);
    await tester.pump();
    controller.add(10); // crosses pendingSyncPromptThreshold (5)
    await tester.pump();
    await tester.pump();

    expect(find.textContaining("haven't reached your cloud"), findsOneWidget);
  });
}
```

Add `import 'dart:async';` at the top for `StreamController`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/widgets/home_sync_overlay_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:hmm_console/core/widgets/home_sync_overlay.dart'`.

- [ ] **Step 3: Create `HomeSyncOverlay`**

Create `lib/core/widgets/home_sync_overlay.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/pending_sync_count_provider.dart';
import '../data/sync/pending_sync_prompt.dart';
import '../data/sync/sync_controller.dart';
import '../navigation/router_config.dart' show rootNavigatorKey;
import '../../features/settings/presentation/widgets/sync_status_card.dart'
    show confirmManualSyncIfOnCellular;
import 'home_button.dart';
import 'sync_pill.dart';

/// Persistent Home + Sync control cluster, mounted ONCE above the router
/// (`lib/main.dart`'s `MaterialApp.router(builder: ...)`) so it appears on
/// every screen with zero per-screen edits — including the Dashboard's raw
/// `Scaffold` (`dashboard_screen.dart:91`). Bottom-trailing, inside
/// `SafeArea`, small enough to clear bottom nav bars / FABs / the note
/// editor's media toolbar.
///
/// Also owns the "blocked/failed safety net" prompt (spec Architecture
/// §3): watches [pendingSyncCountProvider] for a threshold crossing and
/// listens for app-background, showing a one-tap "Sync now / Wait for
/// WiFi" prompt when [shouldPromptPendingSync] says the data is at risk.
class HomeSyncOverlay extends ConsumerStatefulWidget {
  const HomeSyncOverlay({super.key});

  @override
  ConsumerState<HomeSyncOverlay> createState() => _HomeSyncOverlayState();
}

class _HomeSyncOverlayState extends ConsumerState<HomeSyncOverlay>
    with WidgetsBindingObserver {
  bool _promptShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _maybePrompt();
    }
  }

  void _maybePrompt() {
    final pending = ref.read(pendingSyncCountProvider).value ?? 0;
    final status = ref.read(syncControllerProvider).status;
    final shouldPrompt = shouldPromptPendingSync(
      pendingCount: pending,
      autoSyncSkippedForNetwork: status.lastAutoTriggerSkippedForNetwork,
      lastSyncFailed:
          status.lastResult != null && !status.lastResult!.success,
    );
    if (!shouldPrompt || _promptShowing) return;
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;
    _promptShowing = true;
    showDialog<void>(
      context: navContext,
      builder: (ctx) => AlertDialog(
        title: Text(
          '$pending change${pending == 1 ? '' : 's'} '
          "haven't reached your cloud",
        ),
        content: const Text(
          'Sync now may use cellular data, or wait for WiFi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Wait for WiFi'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final proceed =
                  await confirmManualSyncIfOnCellular(navContext, ref);
              if (proceed) {
                await ref.read(syncControllerProvider).triggerManualSync();
              }
            },
            child: const Text('Sync now'),
          ),
        ],
      ),
    ).then((_) => _promptShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    // Threshold-crossing trigger: fire the same prompt when pending count
    // jumps from below to at/above pendingSyncPromptThreshold, independent
    // of app-background.
    ref.listen<AsyncValue<int>>(pendingSyncCountProvider, (prev, next) {
      final prevCount = prev?.value ?? 0;
      final nextCount = next.value ?? 0;
      if (prevCount < pendingSyncPromptThreshold &&
          nextCount >= pendingSyncPromptThreshold) {
        _maybePrompt();
      }
    });

    return Positioned(
      right: 16,
      bottom: 16,
      child: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            HomeButton(),
            SizedBox(width: 8),
            SyncPill(),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/widgets/home_sync_overlay_test.dart`
Expected: PASS.

- [ ] **Step 5: Mount `HomeSyncOverlay` in `main.dart`**

In `lib/main.dart`, add an import and the `builder` param to `MaterialApp.router` (currently `lib/main.dart:79-88`):

```dart
import 'package:hmm_console/core/widgets/home_sync_overlay.dart';
```

```dart
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      theme: AppTheme.lightThemeData,
      darkTheme: AppTheme.darkThemeData,
      themeMode: ThemeMode.system,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(AppRouter.config),
      // Mounts the persistent Home + Sync overlay above every routed
      // screen — including the Dashboard's raw Scaffold — with zero
      // per-screen edits. See Finding 5 in
      // docs/superpowers/plans/2026-07-15-sync-safety-phase1.md for why
      // this is a Stack (not a literal Overlay/OverlayEntry) and why
      // HomeButton/SyncPill route via rootNavigatorKey / the GoRouter
      // instance instead of `context`.
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          const HomeSyncOverlay(),
        ],
      ),
    );
```

- [ ] **Step 6: Run the full test suite for regressions**

Run: `flutter test`
Expected: PASS. (`main.dart` itself has no dedicated widget test in this repo — matches the existing convention where the app-boot wiring in `main.dart`, e.g. `ref.read(syncControllerProvider).start()`, isn't independently unit tested; `HomeSyncOverlay`'s own test in Step 1 already proves the "covers a raw Scaffold, doesn't block taps" claims that matter here.)

- [ ] **Step 7: Commit**

```bash
git add lib/core/widgets/home_sync_overlay.dart lib/main.dart test/core/widgets/home_sync_overlay_test.dart
git commit -m "$(cat <<'EOF'
feat(sync): mount persistent Home+Sync overlay above the router

HomeSyncOverlay composes HomeButton + SyncPill (Task 5) and owns the
blocked/failed anti-loss prompt: fires shouldPromptPendingSync on
app-background and on a pendingSyncCountProvider threshold crossing.
Mounted once via MaterialApp.router's builder in main.dart, so it
covers every screen (including the Dashboard's raw Scaffold) with no
per-screen edits.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**1. Spec coverage** (against `docs/superpowers/specs/2026-07-15-sync-safety-persistent-access-design.md`'s Phase 1 bullets):

- "`notifyLocalChange()` + `SyncTriggerReason.localChange` + debounced auto-sync, wired from the note mutate paths" → Task 1 (mechanism) + Task 2 (wiring). Deviates from the literal "note mutate paths" wording by hooking `LocalHmmNoteRepository` instead of `MutateNote` — documented as Finding 1, necessary for gas-log coverage, which the spec itself requires ("gas logs are notes, so no separate gas-log wiring is needed").
- "`pendingSyncCountProvider`" → Task 3, with the "cheap but not exact" caveat documented (Finding 3) rather than silently assumed.
- "Blocked/failed prompt" → Task 4 (pure decision) + Task 6 (wiring: app-background + threshold crossing).
- "Persistent Home + Sync overlay ... Home everywhere ... local/cloudApi neutral/disabled" → Task 5 (`HomeButton`, `SyncPill`) + Task 6 (mount, covers Dashboard's raw `Scaffold` — tested).
- "Note editor: Save vs Sync — Save writes locally AND triggers the debounced auto-sync via `notifyLocalChange()`" → satisfied transitively: the editor's Save calls `MutateNote.updateGeneral`/`createGeneral` → `hmmNoteRepositoryProvider` → `LocalHmmNoteRepository.updateNote`/`createNote` → `onLocalWrite` → `notifyLocalChange()` (Task 2). No editor-specific code needed.
- Non-goals respected: WiFi-only default policy untouched; attachment bytes untouched; Save/Sync stay separate actions; no Cloud API note-routing changes; no Local-mode "Not backed up" UI.

**2. Placeholder scan:** No "TBD"/"add appropriate X"/"similar to above" left in any step — every code block above is complete, copy-pasteable Dart matching the signatures read from the live files (verified via `Read` before each corresponding edit: `sync_controller.dart`, `local_hmm_note_repository.dart`, `sync_orchestrator.dart`, `router_config.dart`, `main.dart`, `sync_status_card.dart`, `hmm_note_input.dart`).

**3. Type consistency check across tasks:**
- `SyncController.notifyLocalChange()` (Task 1, no args, `void`) is called identically in Task 2's `localHmmNoteRepositoryProvider` closure and nowhere else.
- `LocalHmmNoteRepository(HmmDatabase, Future<Author> Function(), {void Function()? onLocalWrite})` (Task 2) — positional-arg order unchanged from the original 2-arg constructor (verified against existing call sites in `notes_list_reactive_test.dart` and `mutate_note_state_test.dart`, which don't pass the new named arg and remain valid).
- `SyncOrchestrator.pendingChangeCount()` (Task 3, `Future<int>`) is the sole data source for `pendingSyncCountProvider` (Task 3) and is not re-implemented elsewhere (Tasks 4–6 only ever read `pendingSyncCountProvider`, never call `pendingChangeCount()` directly).
- `shouldPromptPendingSync({required int pendingCount, required bool autoSyncSkippedForNetwork, required bool lastSyncFailed})` (Task 4) signature matches its single call site in `HomeSyncOverlow._maybePrompt` (Task 6) exactly — `pendingCount`/`autoSyncSkippedForNetwork`/`lastSyncFailed` argument names line up.
- `pendingSyncPromptThreshold` (Task 4, `int`) is read only in `HomeSyncOverlay.build`'s `ref.listen` (Task 6).
- `rootNavigatorKey` (Task 5, `GlobalKey<NavigatorState>`) is defined once in `router_config.dart` and imported with the same `show rootNavigatorKey` restriction everywhere it's used (`sync_pill.dart`, `home_sync_overlay.dart`, and the two widget test files), avoiding an accidental second definition.
- `AppRouter.config` (existing `Provider<GoRouter>`) is used for navigation in `HomeButton` (`.go('/')`) and `SyncPill`'s mini sheet (`.push('/settings')`) — both call sites use `ref.read`, never `ref.watch`, consistent with "navigate, don't rebuild on route change".

**Known Phase 1 gaps (explicitly out of scope, not oversights):** `deleteNote`/`setParentNote` don't trigger `notifyLocalChange` (Task 2, Step 3 note); `pendingChangeCount()` can under-count immediately after a rare cursor-drift event (Finding 3); `local`/`cloudApi` Sync control is informational-only, no backup/export flow (Task 5); no draggable repositioning of the overlay (spec explicitly defers this).
