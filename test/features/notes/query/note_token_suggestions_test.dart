import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/query/note_token_labels.dart';
import 'package:hmm_console/features/notes/query/note_token_suggestions.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

HmmNote _n(int id, String subject, {int? parent, int catalog = 1}) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: subject,
  authorId: 1,
  catalogId: catalog,
  parentNoteId: parent,
  createDate: DateTime(2026, 1, 1),
);

final l = lookupAppLocalizations(const Locale('en'));
String _title(HmmNote n) => n.subject;

NotesListData _c({
  List<HmmNote>? all,
  Map<int, List<NoteTagLabel>> tags = const {},
  Map<int, String>? live,
  Map<int, String> domains = const {1: 'General'},
}) => NotesListData(
  all: all ?? [_n(1, 'One')],
  catalogsById: const {},
  catalogDomainById: domains,
  tagsByNoteId: tags,
  liveTagNames: live,
);

List<NoteToken> _s(
  String text,
  NotesListData c, [
  List<NoteToken> existing = const [],
]) => [
  for (final s in suggestTokens(text, c, existing, l, titleOf: _title)) s.token,
];

void main() {
  test('suggests a tag by a substring, case- and accent-insensitive', () {
    final c = _c(
      tags: {
        1: [(id: 5, name: 'café')],
      },
      live: {5: 'café'},
    );
    expect(_s('CAFE', c), [const TagToken(5)]);
  });

  test('suggests a Chinese tag by one character', () {
    final c = _c(
      tags: {
        1: [(id: 6, name: '保养')],
      },
    );
    expect(_s('保', c), [const TagToken(6)]);
  });

  test('suggests a domain by its localized label', () {
    final c = _c(
      all: [_n(1, 'a'), _n(2, 'b', catalog: 2)],
      domains: {1: 'General', 2: 'AutomobileMan'},
    );
    expect(_s('auto', c), [const DomainToken('AutomobileMan')]);
  });

  test('suggests flag colours by name', () {
    expect(_s('red', _c()), [const FlagToken(0)]);
  });

  test('suggests a parent note by its title, at most 3', () {
    final all = [
      _n(1, 'Civic'),
      _n(2, 'Civic spare'),
      _n(3, 'Civic old'),
      _n(4, 'Civic third'),
      for (var i = 0; i < 4; i++) _n(10 + i, 'child$i', parent: 1 + i),
    ];
    final r = _s('civic', _c(all: all));
    expect(r.whereType<ParentToken>().length, 3);
    expect(r.first, const ParentToken('u1'));
  });

  test('suggests attributes and date ranges', () {
    expect(_s('photo', _c()), [const HasPhotoToken()]);
    expect(_s('7', _c()), [const RelativeDateToken(RelativeRange.last7d)]);
  });

  test('excludes tokens already applied', () {
    expect(_s('red', _c(), [const FlagToken(0)]), isEmpty);
  });

  test('never more than 8', () {
    // 'a' matches many: tags, flags? (no), attributes, dates (Last...)
    final tags = {
      1: [for (var i = 0; i < 12; i++) (id: i, name: 'tag$i')],
    };
    expect(_s('tag', _c(tags: tags)).length, 8);
  });

  test('empty text suggests nothing', () {
    expect(_s('  ', _c()), isEmpty);
  });

  test('tokenLabel marks a removed tag', () {
    final c = _c(live: {1: 'x'});
    final t = tokenLabel(
      const TagToken(9),
      c,
      l,
      titleOf: _title,
      dateFormat: DateFormat.yMd(),
    );
    expect(t.removed, isTrue);
    expect(t.text, contains('(removed)'));
  });

  test('tokenLabel names a flag', () {
    final t = tokenLabel(
      const FlagToken(0),
      _c(),
      l,
      titleOf: _title,
      dateFormat: DateFormat.yMd(),
    );
    expect(t, (text: 'Red flag', removed: false));
  });
}
