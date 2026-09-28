import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/attached_notes_section.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

class _FakeMutate extends MutateNote {
  _FakeMutate(super.ref, {this.failDetach = false});
  final bool failDetach;
  final calls = <String>[];
  static final n = HmmNote(
      id: 1, uuid: 'u1', subject: 'Oil change receipt', authorId: 1,
      catalogId: 1, createDate: DateTime(2026, 1, 1));

  @override
  Future<HmmNote> detachNote(int noteId) async {
    calls.add('detach $noteId');
    if (failDetach) throw StateError('offline');
    return n;
  }

  @override
  Future<HmmNote> setParent(int noteId, int? parentNoteId) async {
    calls.add('parent $noteId -> $parentNoteId');
    return n;
  }
}

/// The fake is built lazily (on first read of mutateNoteProvider), so the
/// helper returns the list it lands in.
Future<List<_FakeMutate>> _pumpWithNote(WidgetTester tester,
    {bool failDetach = false}) async {
  final fakes = <_FakeMutate>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      attachedNotesProvider(7).overrideWith((ref) async => [_FakeMutate.n]),
      mutateNoteProvider.overrideWith(
          (ref) => _FakeMutate(ref, failDetach: failDetach)..also(fakes.add)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AttachedNotesSection(parentId: 7)),
    ),
  ));
  await tester.pumpAndSettle();
  return fakes;
}

extension<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}

void main() {
  testWidgets('buttons carry localized tooltips', (tester) async {
    await _pumpWithNote(tester);
    expect(find.byTooltip('Attach existing note'), findsOneWidget);
    expect(find.byTooltip('Add note'), findsOneWidget);
    expect(find.byTooltip('Detach note'), findsOneWidget);
  });

  testWidgets('Detach says where the note went and Undo puts it back',
      (tester) async {
    final fakes = await _pumpWithNote(tester);
    await tester.tap(find.byTooltip('Detach note'));
    await tester.pumpAndSettle();
    expect(find.text('Note moved to General'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(fakes.single.calls, ['detach 1', 'parent 1 -> 7']);
    expect(find.text('Note is back'), findsOneWidget);
  });

  testWidgets('a failed Detach says so and offers no Undo', (tester) async {
    await _pumpWithNote(tester, failDetach: true);
    await tester.tap(find.byTooltip('Detach note'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't detach the note"), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Oil change receipt'), findsOneWidget);
  });

  testWidgets('lists attached notes; empty state otherwise', (tester) async {
    final note = HmmNote(
        id: 1, uuid: 'u1', subject: 'Oil change receipt', authorId: 1,
        catalogId: 1, createDate: DateTime(2026, 1, 1));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachedNotesProvider(7).overrideWith((ref) async => [note]),
      ],
      child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      
          home: Scaffold(body: AttachedNotesSection(parentId: 7))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Oil change receipt'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
  });

  testWidgets('shows empty state when no attached notes', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachedNotesProvider(7).overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      
          home: Scaffold(body: AttachedNotesSection(parentId: 7))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No notes yet'), findsOneWidget);
  });

  testWidgets('Add note button re-reads attachedNotesProvider after pop',
      (tester) async {
    var callCount = 0;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, state) =>
              const Scaffold(body: AttachedNotesSection(parentId: 42)),
          routes: [
            GoRoute(
              path: 'notes/new',
              builder: (ctx, state) => const _AutoPopScreen(),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachedNotesProvider(42).overrideWith((ref) async {
          callCount++;
          return const [];
        }),
      ],
      child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
    ));
    await tester.pumpAndSettle();

    // At this point the provider was called at least once during initial build.
    final countBeforeTap = callCount;

    // Tap "Add note" — navigates to /notes/new, which auto-pops immediately.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // The invalidation should have triggered at least one additional read.
    expect(callCount, greaterThan(countBeforeTap));
  });
}

/// A stub screen that immediately pops itself, simulating the user saving a
/// note and returning to the section.
class _AutoPopScreen extends StatefulWidget {
  const _AutoPopScreen();

  @override
  State<_AutoPopScreen> createState() => _AutoPopScreenState();
}

class _AutoPopScreenState extends State<_AutoPopScreen> {
  @override
  void initState() {
    super.initState();
    // Pop on the first frame after build so GoRouter has settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('New note editor stub'));
  }
}
