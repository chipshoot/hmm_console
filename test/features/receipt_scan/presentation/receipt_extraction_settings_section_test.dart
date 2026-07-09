import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/receipt_scan/presentation/receipt_extraction_settings_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host() => const ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: ReceiptExtractionSettingsSection()),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first Cloud AI selection prompts consent and persists on confirm',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(_host());
    await t.pump();

    await t.tap(find.text('Cloud AI (more accurate)'));
    await t.pumpAndSettle();
    expect(find.text('Enable Cloud AI'), findsOneWidget);

    await t.tap(find.text('Enable Cloud AI'));
    await t.pumpAndSettle();

    final blob = (await SharedPreferences.getInstance()).getString('app_settings')!;
    expect(blob, contains('"receiptExtractorMode":"cloudAi"'));
    expect(blob, contains('"receiptCloudConsent":true'));
  });

  testWidgets('cancelling consent leaves the mode unset (stays on-device)',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(_host());
    await t.pump();

    await t.tap(find.text('Cloud AI (more accurate)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();

    // Cancelled: the mode stays on-device in the settings blob.
    final blob = (await SharedPreferences.getInstance()).getString('app_settings')!;
    expect(blob, contains('"receiptExtractorMode":"onDevice"'));
  });

  testWidgets('after consent given, switching does not re-prompt', (t) async {
    SharedPreferences.setMockInitialValues({'receipt_cloud_consent': true});
    await t.pumpWidget(_host());
    await t.pump();

    await t.tap(find.text('Cloud AI (more accurate)'));
    await t.pumpAndSettle();

    expect(find.text('Enable Cloud AI'), findsNothing);
    final blob = (await SharedPreferences.getInstance()).getString('app_settings')!;
    expect(blob, contains('"receiptExtractorMode":"cloudAi"'));
  });
}
