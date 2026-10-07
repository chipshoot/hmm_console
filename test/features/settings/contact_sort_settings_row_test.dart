// test/features/settings/contact_sort_settings_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/contacts/domain/contact_sort_by.dart';
import 'package:hmm_console/features/settings/presentation/screens/settings_screen.dart';
import 'package:hmm_console/features/settings/providers/contact_sort_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Same harness as quick_panel_settings_row_test.dart: databasePathProvider
/// is overridden because path_provider hangs in a widget test.
Future<ProviderContainer> _pump(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    databasePathProvider.overrideWith((ref) async => '/tmp/hmm-test.db'),
  ]);
  addTearDown(container.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('Sort contacts by defaults to Family name and switches',
      (t) async {
    final container = await _pump(t);
    final row = find.byKey(const Key('settings-contact-sort'));
    expect(row, findsOneWidget);
    expect(find.text('Sort contacts by'), findsOneWidget);
    expect(find.text('Family name'), findsOneWidget);

    await t.ensureVisible(row);
    await t.tap(row);
    await t.pumpAndSettle();
    await t.tap(find.text('Given name').last);
    await t.pumpAndSettle();

    expect(container.read(contactSortByProvider), ContactSortBy.given);
  });
}
