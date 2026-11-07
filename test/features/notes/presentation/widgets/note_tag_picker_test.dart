import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_tag_picker.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  late HmmDatabase db;
  late ITagRepository repo;
  late Map<String, int> ids;
  TagPickResult? result;
  var resolved = false;

  Future<int> tag(String name) => db
      .into(db.tags)
      .insert(
        TagsCompanion.insert(
          name: name,
          lastModified: Value(DateTime.utc(2026)),
        ),
      );

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    repo = LocalTagRepository(db);
    result = null;
    resolved = false;
    ids = {'A': await tag('A'), 'B': await tag('B'), 'C': await tag('C')};
  });
  tearDown(() => db.close());

  Future<void> open(
    WidgetTester t,
    Map<int, TagMark> initial, {
    TargetPlatform? platform,
  }) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [tagRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showNoteTagPicker(context, initial: initial);
                resolved = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  /// Drift's stream cleanup schedules a timer; tear the tree down and run
  /// it inside the test so none is left pending.
  void pickerTest(String name, Future<void> Function(WidgetTester t) body) =>
      testWidgets(name, (t) async {
        await body(t);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(milliseconds: 50));
      });

  Finder row(String name) => find.widgetWithText(CheckboxListTile, name);
  bool? value(WidgetTester t, String name) =>
      t.widget<CheckboxListTile>(row(name)).value;

  pickerTest('shows live tags with their marks', (t) async {
    await open(t, {ids['A']!: TagMark.all, ids['B']!: TagMark.some});
    expect(value(t, 'A'), isTrue);
    expect(value(t, 'B'), isNull);
    expect(value(t, 'C'), isFalse);
  });

  pickerTest('tapping cycles marks; Done returns only changes', (t) async {
    await open(t, {ids['A']!: TagMark.all, ids['B']!: TagMark.some});
    await t.tap(row('A'));
    await t.tap(row('B'));
    await t.tap(row('C'));
    await t.pumpAndSettle();
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(result!.add, {ids['B']!, ids['C']!});
    expect(result!.remove, {ids['A']!});
  });

  pickerTest('Done with no taps returns empty add/remove', (t) async {
    await open(t, {ids['A']!: TagMark.all, ids['B']!: TagMark.some});
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(result!.add, isEmpty);
    expect(result!.remove, isEmpty);
  });

  pickerTest('Cancel returns null', (t) async {
    await open(t, {ids['A']!: TagMark.all});
    await t.tap(row('B'));
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(resolved, isTrue);
    expect(result, isNull);
  });

  pickerTest('typing filters; Create row creates and marks the tag', (t) async {
    await open(t, {});
    await t.enterText(find.byType(TextField), 'Trip');
    await t.pumpAndSettle();
    expect(row('A'), findsNothing);
    await t.tap(find.text('Create “Trip”'));
    await t.pumpAndSettle();
    final created = await (db.select(
      db.tags,
    )..where((x) => x.name.equals('Trip'))).getSingle();
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(result!.add, contains(created.id));
  });

  pickerTest('Create row hidden on case-insensitive match', (t) async {
    await tag('Work');
    await open(t, {});
    await t.enterText(find.byType(TextField), '  work ');
    await t.pumpAndSettle();
    expect(find.textContaining('Create'), findsNothing);
    expect(row('Work'), findsOneWidget);
  });

  pickerTest('Create row hidden for an overlong name', (t) async {
    await open(t, {});
    await t.enterText(find.byType(TextField), 'x' * 51);
    await t.pumpAndSettle();
    expect(find.textContaining('Create'), findsNothing);
  });

  Finder createRow(String name) => find.text('Create “$name”');

  pickerTest('create failure shows an inline error in the sheet', (t) async {
    repo = _FlakyTags(db)..fail = true;
    await open(t, {});
    await t.enterText(find.byType(TextField), 'Trip');
    await t.pumpAndSettle();
    await t.tap(createRow('Trip'));
    await t.pumpAndSettle();
    expect(find.text("Couldn't create the tag"), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  pickerTest('second Create tap while in flight creates once', (t) async {
    final flaky = _FlakyTags(db)..gate = Completer<void>();
    repo = flaky;
    await open(t, {});
    await t.enterText(find.byType(TextField), 'Trip');
    await t.pumpAndSettle();
    await t.tap(createRow('Trip'));
    await t.pump();
    await t.tap(createRow('Trip'));
    await t.pump();
    flaky.gate!.complete();
    await t.pumpAndSettle();
    expect(flaky.ensureCalls, 1);
  });

  pickerTest('Done is disabled while a create is in flight', (t) async {
    final flaky = _FlakyTags(db)..gate = Completer<void>();
    repo = flaky;
    await open(t, {});
    await t.enterText(find.byType(TextField), 'Trip');
    await t.pumpAndSettle();
    await t.tap(createRow('Trip'));
    await t.pump();
    expect(
      t.widget<TextButton>(find.widgetWithText(TextButton, 'Done')).onPressed,
      isNull,
    );
    flaky.gate!.complete();
    await t.pumpAndSettle();
    expect(
      t.widget<TextButton>(find.widgetWithText(TextButton, 'Done')).onPressed,
      isNotNull,
    );
  });

  pickerTest('Cancel after Create returns null and keeps the tag', (t) async {
    await open(t, {});
    await t.enterText(find.byType(TextField), 'Trip');
    await t.pumpAndSettle();
    await t.tap(createRow('Trip'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(result, isNull);
    expect(resolved, isTrue);
    final rows = await (db.select(
      db.tags,
    )..where((x) => x.name.equals('Trip'))).get();
    expect(rows, hasLength(1));
  });
}

class _FlakyTags extends LocalTagRepository {
  _FlakyTags(super.db);
  bool fail = false;
  Completer<void>? gate;
  int ensureCalls = 0;

  @override
  Future<Tag> ensureTag(String name) async {
    ensureCalls++;
    if (fail) throw StateError('boom');
    await gate?.future;
    return super.ensureTag(name);
  }
}
