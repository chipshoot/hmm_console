// test/features/contacts/presentation/contact_edit_name_options_test.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contact_edit_screen.dart';
import 'package:hmm_console/features/contacts/states/pinyin_transcriber_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../data/contact_repository_fakes.dart';
import '../fake_pinyin_transcriber.dart';

AppLocalizations get _l => lookupAppLocalizations(const Locale('en'));

const _zh = Contact(
  id: 'zh',
  contactType: ContactType.person,
  lastName: '张',
  firstName: '伟',
);
const _latin = Contact(
  id: 'lt',
  contactType: ContactType.person,
  lastName: 'Zhang',
  firstName: 'Wei',
);

Future<InMemoryContactRepository> _mount(
  WidgetTester tester, {
  Contact? seed,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  final repo = InMemoryContactRepository();
  if (seed != null) repo.seed(seed);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contactRepositoryModeProvider.overrideWithValue(repo),
        pinyinTranscriberProvider.overrideWithValue(FakePinyinTranscriber()),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Navigator(
          pages: [
            const MaterialPage(child: Scaffold(body: Text('previous'))),
            MaterialPage(child: ContactEditScreen(contactId: seed?.id)),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

double _top(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(Key(key))).dy;

void main() {
  testWidgets('a Chinese name opens the options, flips the fields and shows '
      'pinyin hints', (tester) async {
    await _mount(tester, seed: _zh);
    expect(
      _top(tester, 'contact-last-name'),
      lessThan(_top(tester, 'contact-first-name')),
    );
    expect(find.text(_l.contactShownAs('张伟')), findsOneWidget);
    expect(find.byKey(const Key('contact-phonetic-family')), findsOneWidget);
    expect(find.text('zhang'), findsOneWidget); // hint
    expect(find.text('wei'), findsOneWidget); // hint
  });

  testWidgets('a Latin name keeps given above family; options collapsed', (
    tester,
  ) async {
    await _mount(tester, seed: _latin);
    expect(
      _top(tester, 'contact-first-name'),
      lessThan(_top(tester, 'contact-last-name')),
    );
    expect(find.byKey(const Key('contact-phonetic-family')), findsNothing);
    expect(find.text(_l.contactShownAs('Wei Zhang')), findsOneWidget);
  });

  testWidgets('typing Chinese opens the options and the debounced hint '
      'follows; focus survives the field flip', (tester) async {
    await _mount(tester);
    await tester.enterText(find.byKey(const Key('contact-first-name')), '伟');
    await tester.pump();
    expect(find.byKey(const Key('contact-phonetic-given')), findsOneWidget);
    final given = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('contact-first-name')),
        matching: find.byType(EditableText),
      ),
    );
    expect(given.focusNode.hasFocus, isTrue);
    expect(find.text('wei'), findsNothing); // not yet: debounced
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('wei'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('contact-last-name')), '曾');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('zeng'), findsOneWidget);
    expect(find.text(_l.contactShownAs('曾伟')), findsOneWidget);
  });

  testWidgets('Android: the order control is a SegmentedButton and changes '
      'the preview and the saved order', (tester) async {
    final repo = await _mount(tester, seed: _latin);
    await tester.tap(find.byKey(const Key('contact-name-options')));
    await tester.pumpAndSettle();
    expect(find.byType(SegmentedButton<ContactNameOrder>), findsOneWidget);
    await tester.ensureVisible(find.text(_l.contactNameOrderFamilyFirst));
    await tester.tap(find.text(_l.contactNameOrderFamilyFirst));
    await tester.pumpAndSettle();
    expect(find.text(_l.contactShownAs('Zhang Wei')), findsOneWidget);
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect(
      (await repo.getContact('lt'))!.nameOrder,
      ContactNameOrder.familyFirst,
    );
  });

  testWidgets('iOS: the order control is a CupertinoSlidingSegmentedControl', (
    tester,
  ) async {
    await _mount(tester, seed: _zh, platform: TargetPlatform.iOS);
    expect(
      find.byType(CupertinoSlidingSegmentedControl<ContactNameOrder>),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text(_l.contactNameOrderGivenFirst));
    await tester.tap(find.text(_l.contactNameOrderGivenFirst));
    await tester.pumpAndSettle();
    expect(find.text(_l.contactShownAs('伟 张')), findsOneWidget);
  });

  testWidgets('an invalid phonetic shows inline, refuses save with a '
      'SnackBar', (tester) async {
    final repo = await _mount(tester, seed: _zh);
    await tester.enterText(
      find.byKey(const Key('contact-phonetic-family')),
      'zh4ng',
    );
    await tester.pump();
    expect(find.text(_l.contactPhoneticInvalid), findsOneWidget);
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pump();
    expect(find.text(_l.contactPhoneticFixToSave), findsOneWidget);
    expect(repo.saveCalls, 0);
    expect(find.text('previous'), findsNothing);
  });

  testWidgets('a valid phonetic is saved trimmed', (tester) async {
    final repo = await _mount(tester, seed: _zh);
    await tester.enterText(
      find.byKey(const Key('contact-phonetic-family')),
      ' Zhāng ',
    );
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect((await repo.getContact('zh'))!.phoneticFamily, 'Zhāng');
  });
}
