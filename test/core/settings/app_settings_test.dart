import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/settings/app_settings.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';

void main() {
  test('defaults match the legacy per-setting defaults', () {
    const s = AppSettings.defaults;
    expect(s.dataMode, DataMode.local);
    expect(s.cloudProvider, CloudProvider.onedrive);
    expect(s.geoCaptureEnabled, false);
    expect(s.receiptExtractorMode, ReceiptExtractorMode.onDevice);
    expect(s.receiptCloudConsent, false);
    expect(s.launcherRecents, const <String>[]);
    expect(s.notesFilterUsage, const <String, int>{});
    expect(s.dashboardIntroCardSeen, false);
    expect(s.onboardingCompleted, false);
    expect(s.localDbPath, isNull);
    expect(s.cloudStorageVaultPath, isNull);
    expect(s.schemaVersion, 1);
  });

  test('round-trips through JSON', () {
    const s = AppSettings(
      dataMode: DataMode.cloudApi,
      cloudProvider: CloudProvider.onedrive,
      geoCaptureEnabled: true,
      receiptExtractorMode: ReceiptExtractorMode.cloudAi,
      receiptCloudConsent: true,
      launcherRecents: ['a', 'b'],
      notesFilterUsage: {'notes': 3},
      dashboardIntroCardSeen: true,
      onboardingCompleted: true,
      localDbPath: '/tmp/x.db',
      cloudStorageVaultPath: '/Vault',
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.dataMode, DataMode.cloudApi);
    expect(back.receiptExtractorMode, ReceiptExtractorMode.cloudAi);
    expect(back.launcherRecents, ['a', 'b']);
    expect(back.notesFilterUsage, {'notes': 3});
    expect(back.localDbPath, '/tmp/x.db');
    expect(back.cloudStorageVaultPath, '/Vault');
  });

  test('fromJson fills missing keys with defaults and ignores unknowns', () {
    final s = AppSettings.fromJson({'dataMode': 'cloudStorage', 'zzz': 1});
    expect(s.dataMode, DataMode.cloudStorage);
    expect(s.onboardingCompleted, false);
  });

  test('copyWith changes only the named field', () {
    final s = AppSettings.defaults.copyWith(onboardingCompleted: true);
    expect(s.onboardingCompleted, true);
    expect(s.dataMode, DataMode.local);
  });
}
