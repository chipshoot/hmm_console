import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// The last four features carried no display/storage coupling — but
/// [ReceiptExtractorMode] is the one place a mistake would still be possible,
/// because it is a persisted preference whose two values are also shown as
/// radio labels.
///
/// It already keeps them apart: `wire` is the stored value and the labels live
/// in the widget. These tests pin that, so a future "tidy-up" that moves the
/// label onto the enum — the exact shape of the settings-units bug — fails here
/// rather than silently writing a translated word into settings.
void main() {
  late AppLocalizations en;
  late AppLocalizations zh;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    zh = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  test('the persisted wire value is a stable literal', () {
    expect(ReceiptExtractorMode.onDevice.wire, 'onDevice');
    expect(ReceiptExtractorMode.cloudAi.wire, 'cloudAi');
  });

  test('every mode round-trips through its wire value', () {
    for (final m in ReceiptExtractorMode.values) {
      expect(ReceiptExtractorMode.fromWire(m.wire), m);
    }
  });

  test('an unknown stored value falls back rather than throwing', () {
    // Tolerant by design: a preference written by a newer client must not
    // brick the settings screen.
    expect(ReceiptExtractorMode.fromWire('somethingNew'),
        ReceiptExtractorMode.onDevice);
    expect(ReceiptExtractorMode.fromWire(null), ReceiptExtractorMode.onDevice);
  });

  test('the labels translate and are not the wire values', () {
    expect(zh.receiptOnDevice, '本机识别（私密）');
    expect(zh.receiptCloudAi, '云端 AI（更准确）');
    expect(zh.receiptOnDevice, isNot(en.receiptOnDevice));
    // The guard that matters: no label may equal a wire value, or the two
    // concepts have been collapsed again.
    for (final m in ReceiptExtractorMode.values) {
      expect(zh.receiptOnDevice, isNot(m.wire));
      expect(zh.receiptCloudAi, isNot(m.wire));
    }
  });
}
