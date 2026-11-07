import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_tag_field.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  late HmmDatabase db;
  late List<String> names;
  late StateSetter rebuild;

  Future<void> seed(WidgetTester t, List<String> v) async {
    rebuild(() => names = v);
    await t.pump();
  }

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    names = [];
    for (final n in ['Work', 'Network', 'Home', 'Wonder']) {
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              name: n,
              lastModified: Value(DateTime.utc(2026)),
            ),
          );
    }
  });
  tearDown(() => db.close());

  void fieldTest(String name, Future<void> Function(WidgetTester t) body) =>
      testWidgets(name, (t) async {
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              tagRepositoryProvider.overrideWithValue(LocalTagRepository(db)),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (c, set) {
                    rebuild = set;
                    return NoteTagField(
                      names: names,
                      onChanged: (v) => set(() => names = v),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await body(t);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(milliseconds: 50));
      });

  fieldTest('suggests live names, excluding chosen', (t) async {
    await seed(t, ['Wonder']);
    await t.enterText(find.byType(TextField), 'wo');
    await t.pumpAndSettle();
    // prefix match first, then contains; chosen name excluded.
    expect(find.widgetWithText(ActionChip, 'Work'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Network'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Wonder'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Home'), findsNothing);
    await t.tap(find.widgetWithText(ActionChip, 'Network'));
    await t.pumpAndSettle();
    expect(names, ['Wonder', 'Network']);
  });

  fieldTest('Enter and comma commit a chip', (t) async {
    await t.enterText(find.byType(TextField), 'alpha');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(names, ['alpha']);
    await t.enterText(find.byType(TextField), 'beta,');
    await t.pumpAndSettle();
    expect(names, ['alpha', 'beta']);
    expect(find.widgetWithText(InputChip, 'beta'), findsOneWidget);
  });

  fieldTest('duplicate and blank input ignored', (t) async {
    await seed(t, ['Alpha']);
    await t.enterText(find.byType(TextField), ' alpha ');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '   ');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(names, ['Alpha']);
  });

  fieldTest('chip delete removes', (t) async {
    await seed(t, ['A', 'B']);
    await t.tap(find.byTooltip('Remove tag A'));
    await t.pumpAndSettle();
    expect(names, ['B']);
  });
}
