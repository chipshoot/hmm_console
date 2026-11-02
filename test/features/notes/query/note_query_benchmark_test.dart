// A timing test: kept out of the default run (see dart_test.yaml), because
// every core is busy there. Run it alone:
//   flutter test --tags benchmark --run-skipped
@Tags(['benchmark'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart' hide Tags;
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/features/contacts/data/contact_codec.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';
import 'package:hmm_console/features/contacts/states/pinyin_transcriber_provider.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/features/notes/states/notes_results_provider.dart';

class _Pinyin implements PinyinTranscriber {
  @override
  List<String> given(String text) => [for (final r in text.runes) 'p${r % 7}'];
  @override
  List<String> family(String text) => given(text);
}

class _FakeList extends NotesListState {
  _FakeList(this.data);
  final NotesListData data;
  @override
  Future<NotesListData> build() async => data;
}

const _n = 5000;

const _general = NoteCatalog(
  id: 1,
  name: 'General',
  schema: '{}',
  formatType: 0,
  isDefault: false,
);
const _contacts = NoteCatalog(
  id: 2,
  name: 'Hmm.ContactMan.Contact',
  schema: '{}',
  formatType: 0,
  isDefault: false,
);

/// 4,500 markdown notes and 500 contact notes (10%), every note tagged and
/// versioned, so keys, titles and entity decoding all cost what they do in
/// the app.
NotesListData _corpus() {
  final notes = <HmmNote>[];
  final tags = <int, List<NoteTagLabel>>{};
  final states = <String, NoteState>{};
  for (var i = 1; i <= _n; i++) {
    final version = Uint8List.fromList([for (var b = 0; b < 8; b++) i + b]);
    final HmmNote n;
    if (i % 10 == 5) {
      final c = Contact(
        id: 'c$i',
        contactType: ContactType.person,
        firstName: 'Given$i',
        lastName: 'Family',
        phones: [ContactPhone(label: 'mobile', number: '+1 555 ${i % 9999}')],
        notes: 'met at the oil change shop $i',
      );
      n = HmmNote(
        id: i,
        uuid: 'u$i',
        subject: 'Contact:c$i',
        authorId: 1,
        catalogId: _contacts.id,
        createDate: DateTime(2026, 1, 1).add(Duration(hours: i)),
        version: version,
        content: jsonEncode({
          'note': {
            'content': {'Contact': ContactCodec.toMap(c)},
          },
        }),
      );
    } else {
      final han = i % 10 == 0;
      final body = StringBuffer();
      while (body.length < 300) {
        body.write(
          han
              ? '**今天** 换机油 oil change $i 保养 记录 [link](http://x/$i) '
              : '**Did** an oil change ${i % 3} at the shop, '
                    '[link](http://x/$i) plus filter and wiper notes for '
                    'car $i. ',
        );
      }
      n = HmmNote(
        id: i,
        uuid: 'u$i',
        subject: han ? '换机油 $i' : 'Oil change $i',
        authorId: 1,
        catalogId: _general.id,
        createDate: DateTime(2026, 1, 1).add(Duration(hours: i)),
        version: version,
        content: body.toString(),
      );
    }
    notes.add(n);
    tags[i] = [
      (id: i % 20, name: 'tag${i % 20}'),
      (id: 100 + i % 7, name: 'area${i % 7}'),
    ];
    if (i % 25 == 0) {
      states[n.uuid] = NoteState(
        noteUuid: n.uuid,
        isPinned: i % 50 == 0,
        flagColor: i % 7,
        lastModifiedDate: DateTime(2026),
      );
    }
  }
  return NotesListData(
    all: notes,
    catalogsById: const {1: _general, 2: _contacts},
    tagsByNoteId: tags,
    statesByUuid: states,
  );
}

void main() {
  test(
    '5,000 notes evaluate in <= 50 ms per keystroke with a warm index',
    () async {
      final c = ProviderContainer(
        overrides: [
          notesListStateProvider.overrideWith(() => _FakeList(_corpus())),
          pinyinTranscriberProvider.overrideWithValue(_Pinyin()),
        ],
      );
      addTearDown(c.dispose);
      await c.read(notesListStateProvider.future);
      c.listen(notesResultsProvider, (_, _) {});
      c.read(notesViewEnvProvider.notifier).set((
        locale: const Locale('en'),
        firstDayOfWeek: 1,
      ));
      c.read(notesResultsProvider);

      // Wait (by condition, not a fixed delay) for the warmer to finish.
      final cache = c.read(noteTextIndexCacheProvider);
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (cache.length < _n && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(cache.length, _n);

      final list = c.read(notesListStateProvider.notifier);
      list.setText('oil');
      c.read(notesResultsProvider).requireValue; // JIT

      // Each keystroke is timed on its own; the median is held to the bound,
      // so one slow call (a GC pause) does not fail it and one lucky call
      // does not pass it. The bound itself is never relaxed.
      const runs = 15;
      final times = <int>[];
      for (var i = 0; i < runs; i++) {
        final sw = Stopwatch()..start();
        list.setText(i.isEven ? 'oil change ${i % 3}' : 'oil chan');
        c.read(notesResultsProvider).requireValue;
        times.add(sw.elapsedMicroseconds);
      }
      times.sort();
      final median = times[runs ~/ 2] / 1000;
      // ignore: avoid_print
      print(
        'notes results per keystroke: median '
        '${median.toStringAsFixed(1)} ms, fastest '
        '${(times.first / 1000).toStringAsFixed(1)} ms of $runs',
      );
      expect(median, lessThanOrEqualTo(50));
    },
  );
}
