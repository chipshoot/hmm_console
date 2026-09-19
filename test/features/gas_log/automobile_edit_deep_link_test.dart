// The hub pushes /automobiles/manage/:id/edit directly, so the screen can now
// mount while the vehicle list is still loading. It used to read the list
// once in initState and show "vehicle not found" forever in that case.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_edit_screen.dart';
import 'package:hmm_console/features/gas_log/states/automobiles_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _StubResolver implements IAttachmentResolver {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalMode extends DataModeNotifier {
  @override
  DataMode build() => DataMode.local;
}

/// Resolves only after a delay, so the screen's initState sees a loading list.
class _SlowAutomobiles extends AutomobilesState {
  @override
  Future<List<Automobile>> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return [
      Automobile(
        id: 1,
        year: 2020,
        maker: 'Honda',
        model: 'Civic',
        plate: 'REG-1',
        meterReading: 100,
        isActive: true,
        registrationNumber: 'REG-NUMBER-1',
      ),
    ];
  }
}

void main() {
  testWidgets('the form fills in once the vehicle list lands', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(_LocalMode.new),
        automobilesStateProvider.overrideWith(_SlowAutomobiles.new),
        attachmentResolverProvider.overrideWith((_) async => _StubResolver()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AutomobileEditScreen(automobileId: 1),
      ),
    ));
    await tester.pump();

    // Still loading: the old code is already stuck here.
    expect(find.text('REG-NUMBER-1'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('REG-NUMBER-1'), findsOneWidget,
        reason: 'the list resolved after initState; the form must catch up');
  });
}
