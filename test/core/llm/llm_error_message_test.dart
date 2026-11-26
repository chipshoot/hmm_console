import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/contract/contract.dart';
import 'package:hmm_console/core/llm/engines/engine_presets.dart';
import 'package:hmm_console/core/llm/engines/llm_engine.dart';
import 'package:hmm_console/core/llm/ui/llm_consent_sheet.dart';
import 'package:hmm_console/core/llm/ui/llm_error_message.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../../features/settings/presentation/ai_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final all = <LlmException>[
    const LlmKeyMissing(engineLabel: 'Claude (work)'),
    const LlmInvalidKey(engineLabel: 'Claude (work)'),
    const LlmRateLimited(
      retryAfter: Duration(seconds: 3),
      engineLabel: 'Claude (work)',
    ),
    const LlmQuotaExceeded(engineLabel: 'Claude (work)'),
    const LlmUnreachable(engineLabel: 'Claude (work)'),
    const LlmTimeout(engineLabel: 'Claude (work)'),
    const LlmRefused(engineLabel: 'Claude (work)'),
    const LlmUnsupported(LlmCapability.pdf, engineLabel: 'Claude (work)'),
    const LlmBadResponse('SECRET-DETAIL', engineLabel: 'Claude (work)'),
    const LlmSensitiveRefused(engineLabel: 'Claude (work)'),
    const LlmConsentRequired(engineLabel: 'Claude (work)'),
    const LlmCancelled(engineLabel: 'Claude (work)'),
  ];

  for (final code in ['en', 'zh']) {
    test('every LlmException has a distinct labelled message ($code)', () {
      final l = lookupAppLocalizations(Locale(code));
      final seen = <String>{};
      for (final e in all) {
        final m = llmErrorMessage(e, l);
        expect(m, contains('Claude (work)'), reason: '$e');
        expect(m, isNot(contains('SECRET-DETAIL')));
        expect(seen.add(m), isTrue, reason: 'duplicate for $e');
      }
    });
  }

  test('en messages', () {
    final l = lookupAppLocalizations(const Locale('en'));
    expect(
      llmErrorMessage(const LlmInvalidKey(engineLabel: 'Claude (work)'), l),
      'Claude (work): the key was rejected — check it in Settings → AI providers.',
    );
    expect(llmErrorMessage(const LlmTimeout(), l), startsWith('AI provider: '));
  });

  test('unsupported names the capability', () {
    final l = lookupAppLocalizations(const Locale('en'));
    expect(
      llmErrorMessage(
        const LlmUnsupported(LlmCapability.pdf, engineLabel: 'X'),
        l,
      ),
      contains('PDF'),
    );
  });

  group('consent sheet', () {
    final engine = presetEngine(
      LlmEngineKind.anthropic,
      id: 'a',
      label: 'Claude (work)',
      model: 'm',
    );

    Future<(AiHarness, Future<bool>)> open(WidgetTester t) async {
      late BuildContext ctx;
      final h = await pumpAi(
        t,
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      );
      final f = showLlmConsentSheet(ctx, engine);
      await t.pumpAndSettle();
      return (h, f);
    }

    platformTest(
      'accept stores consent (Android dialog)',
      TargetPlatform.android,
      (t) async {
        final (h, f) = await open(t);
        expect(
          find.text(
            'Content you send goes to Claude (work) at api.anthropic.com. '
            'Sensitive notes are never sent. Continue?',
          ),
          findsOneWidget,
        );
        await t.tap(find.text('Continue'));
        await t.pumpAndSettle();
        expect(await f, isTrue);
        expect(h.keys.consent, {'a'});
      },
    );

    platformTest('cancel does not store consent', TargetPlatform.android, (
      t,
    ) async {
      final (h, f) = await open(t);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(await f, isFalse);
      expect(h.keys.consent, isEmpty);
    });

    platformTest('iOS shows an action sheet', TargetPlatform.iOS, (t) async {
      final (h, f) = await open(t);
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(await f, isTrue);
      expect(h.keys.consent, {'a'});
    });
  });
}
