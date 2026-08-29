import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/auto_insurance_policy.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/insurance_policies_screen.dart';
import 'package:hmm_console/features/automobile_records/states/insurance_policies_state.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/states/automobiles_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _StubPolicies extends InsurancePoliciesState {
  @override
  Future<List<AutoInsurancePolicy>> build() async => const [];
}

class _StubAutos extends AutomobilesState {
  @override
  Future<List<Automobile>> build() async => const [];
}

void main() {
  Future<void> pumpOn(WidgetTester tester, TargetPlatform platform) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        insurancePoliciesStateProvider.overrideWith(_StubPolicies.new),
        automobilesStateProvider.overrideWith(_StubAutos.new),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const InsurancePoliciesScreen(automobileId: 7),
      ),
    ));
    await tester.pump();
  }

  testWidgets('on iOS the add action sits in the app bar, not on a FAB',
      (tester) async {
    await pumpOn(tester, TargetPlatform.iOS);

    expect(find.byKey(const Key('addPolicyAction')), findsOneWidget);
    // The project's UI rules say to avoid a FAB on iOS; the add belongs in the
    // navigation bar where the platform's own apps put it.
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('on Android the FAB stays and the app-bar action does not appear',
      (tester) async {
    await pumpOn(tester, TargetPlatform.android);

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byKey(const Key('addPolicyAction')), findsNothing);
  });
}
