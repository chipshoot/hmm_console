import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/attached_notes_section.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';

void main() {
  testWidgets('lists attached notes; empty state otherwise', (tester) async {
    final note = HmmNote(
        id: 1, uuid: 'u1', subject: 'Oil change receipt', authorId: 1,
        catalogId: 1, createDate: DateTime(2026, 1, 1));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachedNotesProvider(7).overrideWith((ref) async => [note]),
      ],
      child: const MaterialApp(
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
      child: MaterialApp.router(routerConfig: router),
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
