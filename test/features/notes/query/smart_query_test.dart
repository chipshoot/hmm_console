import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/query/saved_search.dart';
import 'package:hmm_console/features/notes/query/smart_query.dart';

SavedSearch _s(NoteQuery q) =>
    SavedSearch(id: 's1', name: 'S', order: 0, query: q);

void main() {
  test('non-smart queries pass through', () {
    const live = NoteQuery(text: 'x');
    expect(identical(resolveSmartQuery(live, const []), live), isTrue);
  });

  test('expands to the saved source, text and tokens', () {
    final saved = _s(
      const NoteQuery(
        source: DomainSource(key: 'AutomobileMan'),
        text: 'oil',
        tokens: [HasPhotoToken()],
      ),
    );
    const live = NoteQuery(
      source: SmartSource(savedId: 's1'),
      text: 'filter',
      tokens: [PinnedToken()],
      sort: NoteSort.subjectAZ,
      scope: NoteScope.all,
    );
    final r = resolveSmartQuery(live, [saved]);
    expect(r.source, const DomainSource(key: 'AutomobileMan'));
    expect(r.text, 'oil filter');
    expect(r.tokens, [const HasPhotoToken(), const PinnedToken()]);
    expect(r.sort, NoteSort.subjectAZ);
    expect(r.scope, NoteScope.all);
  });

  test('empty text parts leave no stray space', () {
    final saved = _s(const NoteQuery(text: 'oil'));
    final r = resolveSmartQuery(
      const NoteQuery(source: SmartSource(savedId: 's1')),
      [saved],
    );
    expect(r.text, 'oil');
  });

  test('a duplicated live token is not repeated', () {
    final saved = _s(const NoteQuery(tokens: [HasPhotoToken()]));
    final r = resolveSmartQuery(
      const NoteQuery(
        source: SmartSource(savedId: 's1'),
        tokens: [HasPhotoToken(), PinnedToken()],
      ),
      [saved],
    );
    expect(r.tokens, [const HasPhotoToken(), const PinnedToken()]);
  });

  test('a nested smart source becomes All', () {
    final saved = _s(const NoteQuery(source: SmartSource(savedId: 'other')));
    final r = resolveSmartQuery(
      const NoteQuery(source: SmartSource(savedId: 's1')),
      [saved],
    );
    expect(r.source, const AllSource());
  });

  test('a missing id passes the live query through', () {
    const live = NoteQuery(source: SmartSource(savedId: 'gone'));
    expect(identical(resolveSmartQuery(live, const []), live), isTrue);
    expect(savedSearchFor(live.source, const []), isNull);
  });
}
