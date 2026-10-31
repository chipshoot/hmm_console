import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_note_state_repository.dart';
import 'package:hmm_console/core/data/sync/note_state_sync_service.dart';
import 'package:hmm_console/core/notes/note_state.dart';

void main() {
  late HmmDatabase db;
  late LocalNoteStateRepository repo;
  late NoteStateSyncService service;
  final t1 = DateTime.utc(2026, 10, 1, 9);
  final t2 = t1.add(const Duration(hours: 1));
  final now = DateTime.utc(2026, 10, 2);

  setUp(() {
    db = HmmDatabase(NativeDatabase.memory());
    repo = LocalNoteStateRepository(db);
    service = NoteStateSyncService(repo);
  });

  tearDown(() => db.close());

  Map<String, dynamic> doc(List<Map<String, dynamic>> states) => {
    'version': 1,
    'states': states,
  };

  Map<String, dynamic> entry(
    String uuid, {
    bool pinned = false,
    int? flag,
    required DateTime at,
  }) => {
    'noteUuid': uuid,
    'isPinned': pinned,
    'flagColor': flag,
    'lastModified': at.toIso8601String(),
  };

  Future<NoteStateMerge> merge(
    Map<String, dynamic>? remote, {
    Set<String> known = const {'n1', 'n2'},
  }) =>
      service.merge(remote, knownNoteUuids: known, deviceId: 'dev-a', now: now);

  Map<String, dynamic>? pushed(NoteStateMerge m, String uuid) =>
      (m.document['states'] as List)
          .cast<Map<String, dynamic>>()
          .where((s) => s['noteUuid'] == uuid)
          .firstOrNull;

  test(
    'a newer remote state is applied and the merged document carries it',
    () async {
      final m = await merge(doc([entry('n1', pinned: true, flag: 2, at: t2)]));

      final s = await repo.getState('n1');
      expect(s.isPinned, isTrue);
      expect(s.flagColor, 2);
      expect(m.localWins, isEmpty);
      expect(pushed(m, 'n1')!['isPinned'], isTrue);
      expect(m.document['version'], 1);
      expect(m.document['device_id'], 'dev-a');
    },
  );

  test('a newer local unpin beats an older remote pin', () async {
    await repo.putState(
      NoteState(noteUuid: 'n1', isPinned: false, lastModifiedDate: t2),
    );

    final m = await merge(doc([entry('n1', pinned: true, at: t1)]));

    expect((await repo.getState('n1')).isPinned, isFalse);
    expect(m.localWins, {'n1'});
    expect(
      pushed(m, 'n1')!['isPinned'],
      isFalse,
      reason: 'unpin travels as a row with false, not as a missing row',
    );
  });

  test('a newer remote unpin is applied as a false row', () async {
    await repo.putState(
      NoteState(
        noteUuid: 'n1',
        isPinned: true,
        flagColor: 4,
        lastModifiedDate: t1,
      ),
    );

    await merge(doc([entry('n1', pinned: false, flag: null, at: t2)]));

    final rows = await db.select(db.noteStates).get();
    expect(rows, hasLength(1));
    expect(rows.single.isPinned, isFalse);
    expect(rows.single.flagColor, isNull);
  });

  test('a tie keeps local and is not a local win', () async {
    await repo.putState(
      NoteState(noteUuid: 'n1', isPinned: true, lastModifiedDate: t1),
    );

    final m = await merge(doc([entry('n1', pinned: false, at: t1)]));

    expect((await repo.getState('n1')).isPinned, isTrue);
    expect(m.localWins, isEmpty);
  });

  test('a local state absent remotely is a local win', () async {
    await repo.putState(
      NoteState(noteUuid: 'n2', flagColor: 0, lastModifiedDate: t1),
    );

    final m = await merge(null);

    expect(m.localWins, {'n2'});
    expect(pushed(m, 'n2')!['flagColor'], 0);
  });

  test(
    'an entry for a note that no longer exists is ignored and not pushed back',
    () async {
      final m = await merge(doc([entry('gone', pinned: true, at: t2)]));

      expect(await repo.getAllStates(), isEmpty);
      expect(pushed(m, 'gone'), isNull);
    },
  );

  test('a local state for a note that no longer exists is dropped', () async {
    await repo.putState(
      NoteState(noteUuid: 'gone', isPinned: true, lastModifiedDate: t2),
    );

    final m = await merge(null);

    expect(await repo.getAllStates(), isEmpty);
    expect(m.localWins, isEmpty);
  });

  test(
    'an unknown flag colour is kept; malformed entries are skipped',
    () async {
      final m = await merge(
        doc([
          entry('n1', flag: 42, at: t2),
          {'isPinned': true, 'lastModified': t2.toIso8601String()}, // no uuid
          {'noteUuid': 'n2', 'isPinned': true, 'lastModified': 'not a date'},
          {
            'noteUuid': 'n2',
            'isPinned': true,
            'flagColor': 'red',
            'lastModified': t2.toIso8601String(),
          },
        ]),
      );

      expect((await repo.getState('n1')).flagColor, 42);
      final n2 = await repo.getState('n2');
      expect(
        n2.isPinned,
        isTrue,
        reason: 'a non-numeric flag reads as unflagged',
      );
      expect(n2.flagColor, isNull);
      expect(pushed(m, 'n1')!['flagColor'], 42);
    },
  );
}
