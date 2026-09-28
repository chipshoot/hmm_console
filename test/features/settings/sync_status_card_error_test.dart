// A sync error was clipped to two lines on the card, which cut off Graph's
// error body — the one part that says what went wrong. The user had to
// retype what they could see. The full text must be readable and copyable.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/features/settings/presentation/widgets/sync_status_card.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _FakeSync extends SyncController {
  _FakeSync(this._s) : super(syncAction: () async => throw UnimplementedError());
  final SyncStatus _s;
  @override
  SyncStatus get status => _s;
}

const _longError = 'Failed to pull manifest: OneDriveGraphException(400): '
    'Bad Request\n'
    'GET https://graph.microsoft.com/v1.0/me/drive/special/approot:/users/'
    'SUB-1/manifest.json:/content\n'
    '{error: {code: invalidRequest, message: Invalid request.}}';

void main() {
  String? clipboard;

  setUp(() {
    clipboard = null;
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        syncControllerProvider.overrideWithValue(_FakeSync(SyncStatus(
          consecutiveFailures: 1,
          lastResult: SyncResult.failed(
            at: DateTime.utc(2026, 9, 25),
            error: const SyncError(
              recordType: 'manifest',
              recordId: '-',
              message: _longError,
            ),
          ),
        ))),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SyncStatusCard()),
      ),
    ));
    await tester.pump();
  }

  testWidgets('tapping the clipped error shows all of it', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('syncErrorLine')));
    await tester.pumpAndSettle();

    final detail =
        tester.widget<SelectableText>(find.byKey(const Key('syncErrorDetail')));
    expect(detail.data, _longError);
  });

  testWidgets('Copy puts the whole error on the clipboard', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('syncErrorLine')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(clipboard, _longError);
  });
}
