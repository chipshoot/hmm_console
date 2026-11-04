import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/features/notes/states/note_bulk_actions.dart';
import 'package:hmm_console/l10n/gen/app_localizations_en.dart';

class _FakeMutate extends MutateNote {
  _FakeMutate(super.ref, {this.throwFor = const {}});
  final Set<int> throwFor;
  final calls = <String>[];

  void _maybeThrow(int id) {
    if (throwFor.contains(id)) throw StateError('boom $id');
  }

  @override
  Future<NoteState> setPinned(int id, bool pinned) async {
    calls.add('pin:$id:$pinned');
    _maybeThrow(id);
    return NoteState.none('x');
  }

  @override
  Future<NoteState> setFlagColor(int id, int? flagColor) async {
    calls.add('flag:$id:$flagColor');
    _maybeThrow(id);
    return NoteState.none('x');
  }

  @override
  Future<void> delete(int id) async {
    calls.add('delete:$id');
    _maybeThrow(id);
  }

  @override
  Future<HmmNote> restore(int id) async {
    calls.add('restore:$id');
    _maybeThrow(id);
    return HmmNote(
      id: id,
      uuid: 'u$id',
      subject: 's',
      authorId: 1,
      createDate: DateTime(2026),
    );
  }
}

(NoteBulkActions, _FakeMutate) _make({Set<int> throwFor = const {}}) {
  late _FakeMutate fake;
  final c = ProviderContainer();
  addTearDown(c.dispose);
  final p = Provider<_FakeMutate>(
    (ref) => fake = _FakeMutate(ref, throwFor: throwFor),
  );
  c.read(p);
  return (NoteBulkActions(fake), fake);
}

void main() {
  test('togglePinned pins all when any is unpinned', () async {
    final (bulk, fake) = _make();
    final (pinned, out) = await bulk.togglePinned(
      [1, 2, 3],
      {1: true, 2: false, 3: true},
    );
    expect(pinned, true);
    expect(fake.calls, ['pin:1:true', 'pin:2:true', 'pin:3:true']);
    expect(out.succeeded, [1, 2, 3]);
  });

  test('togglePinned unpins all when all are pinned', () async {
    final (bulk, fake) = _make();
    final (pinned, out) = await bulk.togglePinned([1, 2], {1: true, 2: true});
    expect(pinned, false);
    expect(fake.calls, ['pin:1:false', 'pin:2:false']);
    expect(out.succeeded, [1, 2]);
  });

  test('setFlag keeps going after a failure', () async {
    final (bulk, _) = _make(throwFor: {2});
    final out = await bulk.setFlag([1, 2, 3], 4);
    expect(out.succeeded, [1, 3]);
    expect(out.failed, [2]);
    expect(out.total, 3);
  });

  test('restore keeps going after a failure', () async {
    final (bulk, fake) = _make(throwFor: {1});
    final out = await bulk.restore([1, 2]);
    expect(out.failed, [1]);
    expect(out.succeeded, [2]);
    expect(fake.calls, ['restore:1', 'restore:2']);
  });

  test('delete skips entity notes without writing them', () async {
    final (bulk, fake) = _make();
    final out = await bulk.delete([1, 2, 3, 4, 5], (id) => id <= 3);
    expect(out.deleted, [1, 2, 3]);
    expect(out.skipped, [4, 5]);
    expect(out.failed, isEmpty);
    expect(fake.calls, ['delete:1', 'delete:2', 'delete:3']);
  });

  test('delete with only entity notes writes nothing', () async {
    final (bulk, fake) = _make();
    final out = await bulk.delete([4, 5], (_) => false);
    expect(out.deleted, isEmpty);
    expect(out.failed, isEmpty);
    expect(out.skipped, [4, 5]);
    expect(fake.calls, isEmpty);
  });

  test('delete records failures and continues', () async {
    final (bulk, _) = _make(throwFor: {2});
    final out = await bulk.delete([1, 2, 3], (_) => true);
    expect(out.deleted, [1, 3]);
    expect(out.failed, [2]);
  });

  group('bulkDeleteMessage', () {
    final l = AppLocalizationsEn();
    BulkDeleteOutcome o(int d, int s) => BulkDeleteOutcome(
      deleted: List.generate(d, (i) => i),
      skipped: List.generate(s, (i) => 100 + i),
      failed: const [],
    );
    test(
      'plain',
      () => expect(bulkDeleteMessage(o(3, 0), l), 'Deleted 3 notes'),
    );
    test(
      'with skipped',
      () => expect(bulkDeleteMessage(o(3, 2), l), 'Deleted 3 · 2 skipped'),
    );
    test(
      'singular',
      () => expect(bulkDeleteMessage(o(1, 0), l), 'Deleted 1 note'),
    );
    test(
      'nothing eligible',
      () => expect(bulkDeleteMessage(o(0, 2), l), isNull),
    );
  });
}
