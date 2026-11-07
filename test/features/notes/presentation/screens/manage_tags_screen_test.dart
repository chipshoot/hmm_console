import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/presentation/screens/manage_tags_screen.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _Repo implements ITagRepository {
  _Repo(this.usage);
  List<TagUsage> usage;
  final calls = <String>[];
  int? takenBy;
  bool failNext = false;
  final _c = StreamController<List<TagUsage>>.broadcast();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  Stream<List<TagUsage>> watchTagUsage() async* {
    yield usage;
    yield* _c.stream;
  }

  void _maybeFail() {
    if (failNext) {
      failNext = false;
      throw StateError('boom');
    }
  }

  @override
  Future<void> renameTag(int id, String newName) async {
    calls.add('rename $id $newName');
    if (takenBy != null) throw TagNameTaken(takenBy!);
    _maybeFail();
  }

  @override
  Future<void> mergeTags({required int keepId, required int mergeId}) async {
    calls.add('merge keep $keepId merge $mergeId');
    _maybeFail();
  }

  @override
  Future<void> deleteTag(int id) async {
    calls.add('delete $id');
    _maybeFail();
  }
}

const _tags = <TagUsage>[
  (id: 1, name: 'Work', noteCount: 3),
  (id: 2, name: 'Home', noteCount: 1),
  (id: 3, name: 'Unused', noteCount: 0),
];

Future<_Repo> _pump(
  WidgetTester t, {
  List<TagUsage> tags = _tags,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  final repo = _Repo(tags);
  await t.pumpWidget(
    ProviderScope(
      overrides: [tagRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          platform: platform,
          extensions: const [AppColors.light],
        ),
        home: const ManageTagsScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  return repo;
}

Future<void> _openActions(WidgetTester t, String name) async {
  await t.tap(find.text(name));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('lists tags with totals including zero-note tags', (t) async {
    await _pump(t);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('3 notes'), findsOneWidget);
    expect(find.text('1 note'), findsOneWidget);
    expect(find.text('Unused'), findsOneWidget);
    expect(find.text('No notes'), findsOneWidget);
  });

  testWidgets('rename saves through renameTag', (t) async {
    final repo = await _pump(t);
    await _openActions(t, 'Work');
    await t.tap(find.text('Rename…'));
    await t.pumpAndSettle();
    final field = find.byType(TextField);
    expect(tester(t, field).controller!.text, 'Work');
    // Unchanged: Save disabled.
    expect(
      t.widget<TextButton>(find.widgetWithText(TextButton, 'Save')).onPressed,
      isNull,
    );
    await t.enterText(field, '   ');
    await t.pump();
    expect(
      t.widget<TextButton>(find.widgetWithText(TextButton, 'Save')).onPressed,
      isNull,
    );
    await t.enterText(field, '  Job  ');
    await t.pump();
    await t.tap(find.widgetWithText(TextButton, 'Save'));
    await t.pumpAndSettle();
    expect(repo.calls, ['rename 1 Job']);
  });

  testWidgets('rename to an existing name offers merge', (t) async {
    final repo = await _pump(t);
    repo.takenBy = 2;
    await _openActions(t, 'Work');
    await t.tap(find.text('Rename…'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'home');
    await t.pump();
    await t.tap(find.widgetWithText(TextButton, 'Save'));
    await t.pumpAndSettle();
    expect(
      find.text('A tag named “home” already exists. Merge into it?'),
      findsOneWidget,
    );
    await t.tap(find.widgetWithText(TextButton, 'Merge'));
    await t.pumpAndSettle();
    expect(repo.calls.last, 'merge keep 2 merge 1');
  });

  testWidgets('merge confirms then merges', (t) async {
    final repo = await _pump(t);
    await _openActions(t, 'Work');
    await t.tap(find.text('Merge into…'));
    await t.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Work')),
      findsNothing,
    ); // the picker excludes the tag itself
    await t.tap(find.descendant(of: sheet, matching: find.text('Home')));
    await t.pumpAndSettle();
    expect(
      find.text('Move 3 notes from “Work” to “Home” and delete “Work”?'),
      findsOneWidget,
    );
    expect(repo.calls, isEmpty);
    await t.tap(find.widgetWithText(TextButton, 'Merge'));
    await t.pumpAndSettle();
    expect(repo.calls, ['merge keep 2 merge 1']);
  });

  testWidgets('delete confirms; cancel writes nothing', (t) async {
    final repo = await _pump(t);
    await _openActions(t, 'Work');
    await t.tap(find.text('Delete…'));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Delete the tag “Work”? It is removed from 3 notes. The notes stay.',
      ),
      findsOneWidget,
    );
    await t.tap(find.widgetWithText(TextButton, 'Cancel'));
    await t.pumpAndSettle();
    expect(repo.calls, isEmpty);

    await _openActions(t, 'Work');
    await t.tap(find.text('Delete…'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await t.pumpAndSettle();
    expect(repo.calls, ['delete 1']);
  });

  testWidgets('a failing write shows the failure snackbar', (t) async {
    final repo = await _pump(t);
    repo.failNext = true;
    await _openActions(t, 'Work');
    await t.tap(find.text('Delete…'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await t.pumpAndSettle();
    expect(find.text("Couldn't change the tag"), findsOneWidget);
  });

  testWidgets('empty state', (t) async {
    await _pump(t, tags: const []);
    expect(
      find.text(
        "No tags yet. Add tags in a note's editor or from its long-press menu.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('has a help button', (t) async {
    await _pump(t);
    expect(find.byType(HelpButton), findsOneWidget);
  });

  testWidgets('iOS opens a Cupertino action sheet', (t) async {
    await _pump(t, platform: TargetPlatform.iOS);
    await _openActions(t, 'Work');
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.text('Rename…'), findsOneWidget);
  });
}

TextField tester(WidgetTester t, Finder f) => t.widget<TextField>(f);
