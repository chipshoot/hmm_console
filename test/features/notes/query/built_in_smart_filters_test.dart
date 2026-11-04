import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/query/built_in_smart_filters.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/query/smart_query.dart';
import 'package:hmm_console/features/notes/states/saved_searches_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

NoteQuery _resolved(String id) => resolveSmartQuery(
  NoteQuery(source: SmartSource(savedId: id)),
  builtInSmartFilters,
);

void main() {
  test('the three built-ins expand to their tokens', () {
    expect(_resolved('builtin.withPhotos').tokens, [const HasPhotoToken()]);
    expect(_resolved('builtin.withPlace').tokens, [const HasPlaceToken()]);
    expect(_resolved('builtin.last7d').tokens, [
      const RelativeDateToken(RelativeRange.last7d),
    ]);
  });

  test('built-ins are recognised by id', () {
    expect(isBuiltInSmartFilter('builtin.last7d'), isTrue);
    expect(isBuiltInSmartFilter('abc'), isFalse);
    for (final f in builtInSmartFilters) {
      expect(isBuiltInSmartFilter(f.id), isTrue);
    }
  });

  test('a built-in is never missing', () {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final found = savedSearchFor(
      const SmartSource(savedId: 'builtin.last7d'),
      c.read(notesSmartFiltersProvider),
    );
    expect(found, isNotNull);
  });

  test('names are localized', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final zh = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(builtInSmartFilterName('builtin.withPhotos', en), 'With photos');
    expect(builtInSmartFilterName('builtin.withPhotos', zh), '含照片');
    expect(builtInSmartFilterName('builtin.withPlace', en), 'With place');
    expect(builtInSmartFilterName('builtin.last7d', zh), '最近 7 天');
  });
}
