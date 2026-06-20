import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_location_card.dart';
import 'package:hmm_console/features/notes/providers/note_location_capture.dart';
import 'package:hmm_console/features/settings/providers/geo_capture_provider.dart';

class _EnabledGeo extends GeoCaptureNotifier {
  @override
  Future<bool> build() async => true;
}

void main() {
  testWidgets('new note shows a location card when capture is enabled',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
                path: 'editor', builder: (c, s) => const NoteEditorScreen()),
          ],
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        geoCaptureEnabledProvider.overrideWith(() => _EnabledGeo()),
        noteLocationCaptureProvider.overrideWith((ref) async =>
            const NoteLocation(
                latitude: 47.6, longitude: -122.3, label: 'Seattle, WA')),
      ],
      child: MaterialApp.router(
        theme: ThemeData(extensions: const [AppColors.light]),
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NoteLocationCard), findsOneWidget);
    expect(find.text('Seattle, WA'), findsOneWidget);
  });
}
