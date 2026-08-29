// The registration card must carry the three new fields, and must NOT offer
// them in cloudApi mode: the automobile API DTO does not have them, so a save
// there would report success and discard what the user typed. The existing
// expiry picker stays in every mode - the API does carry that one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_edit_screen.dart';
import 'package:hmm_console/features/gas_log/states/automobiles_state.dart';
import 'package:hmm_console/features/gas_log/states/update_automobile_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

/// Records what the screen actually hands to the repository, which is the
/// only place a dropped field shows up.
class _CapturingUpdate extends UpdateAutomobileState {
  static Automobile? captured;

  @override
  Future<void> updateAutomobile(int id, Automobile automobile) async {
    captured = automobile;
    state = const AsyncValue.data(null);
  }
}

class _StubAutomobiles extends AutomobilesState {
  _StubAutomobiles(this._items);
  final List<Automobile> _items;
  @override
  Future<List<Automobile>> build() async => _items;
}

Automobile _auto() => Automobile(
      id: 1,
      year: 2020,
      maker: 'Honda',
      model: 'Civic',
      plate: 'REG-1',
      meterReading: 100,
      isActive: true,
      registrationNumber: 'REG-NUMBER-1',
      registrationJurisdiction: 'Ontario',
      registrationIssuedDate: DateTime.utc(2026, 1, 1),
      registrationExpiryDate: DateTime.utc(2027, 1, 1),
    );

void main() {
  Future<void> pump(WidgetTester tester, DataMode mode) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _StubMode(mode)),
        automobilesStateProvider
            .overrideWith(() => _StubAutomobiles([_auto()])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The screen reads the automobile list ONCE, synchronously, in
        // initState - if it has not resolved by then, _original stays null
        // and the screen renders "vehicle not found" forever. Mounting behind
        // this gate mirrors how the app reaches the screen: from a list that
        // has already loaded. (That fragility is pre-existing and worth
        // fixing separately.)
        home: Consumer(builder: (context, ref, _) {
          final autos = ref.watch(automobilesStateProvider);
          return autos.hasValue
              ? const AutomobileEditScreen(automobileId: 1)
              : const SizedBox.shrink();
        }),
      ),
    ));
    // pump, not pumpAndSettle: in cloudApi the screen's other cards fire real
    // HTTP for insurance and services, and settling would wait on the network.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  testWidgets('local mode shows the registration details', (tester) async {
    await pump(tester, DataMode.local);

    expect(find.text('REG-NUMBER-1'), findsOneWidget);
    expect(find.text('Ontario'), findsOneWidget);
  });

  testWidgets('cloudApi hides the three new fields', (tester) async {
    // They would be accepted and then dropped, so they must not be offered.
    await pump(tester, DataMode.cloudApi);

    expect(find.text('REG-NUMBER-1'), findsNothing);
    expect(find.text('Ontario'), findsNothing);
  });

  testWidgets('the expiry row survives in cloudApi', (tester) async {
    // The API carries registrationExpiryDate, so hiding it too would be wrong.
    await pump(tester, DataMode.cloudApi);

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.vehicleRegistrationExpiry), findsWidgets);
  });

  testWidgets('saving a card keeps the vehicle\'s scans', (tester) async {
    // _cloneWith rebuilds the whole Automobile from _original. It listed
    // `images` but not `files`, so `files` fell back to its empty default and
    // every card save wrote an empty set — the repository writes
    // _attachmentsFor(automobile) verbatim, so the refs left the note and the
    // vault would collect the bytes on its next pass.
    // The screen is taller than the default 600px test viewport, so the card
    // being driven here sits off-screen and cannot be tapped.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    _CapturingUpdate.captured = null;
    const scan = VaultRef(
      path: 'v/1/registration.pdf',
      originalName: 'registration.pdf',
      contentType: 'application/pdf',
      byteSize: 10,
    );
    final auto = Automobile(
      id: 1,
      year: 2020,
      maker: 'Honda',
      model: 'Civic',
      plate: 'REG-1',
      meterReading: 100,
      isActive: true,
      registrationNumber: 'REG-NUMBER-1',
      files: const [scan],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _StubMode(DataMode.local)),
        automobilesStateProvider.overrideWith(() => _StubAutomobiles([auto])),
        updateAutomobileStateProvider.overrideWith(_CapturingUpdate.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(builder: (context, ref, _) {
          final autos = ref.watch(automobilesStateProvider);
          return autos.hasValue
              ? const AutomobileEditScreen(automobileId: 1)
              : const SizedBox.shrink();
        }),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pump();
    await tester.tap(find.text('Save changes').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(_CapturingUpdate.captured, isNotNull,
        reason: 'the save never reached the notifier');
    expect(_CapturingUpdate.captured!.files, [scan]);
  });
}
