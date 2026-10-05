import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contact_edit_screen.dart';
import 'package:hmm_console/features/contacts/states/device_region_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../data/contact_repository_fakes.dart';

AppLocalizations get _l => lookupAppLocalizations(const Locale('en'));

Contact _seed(List<ContactPhone> phones, {List<ContactEmail>? emails}) =>
    Contact(
      id: 'p1',
      contactType: ContactType.person,
      firstName: 'Pat',
      phones: phones,
      emails: emails ?? const [],
    );

Future<InMemoryContactRepository> _mount(
  WidgetTester tester, {
  Contact? seed,
  String? region,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  final repo = InMemoryContactRepository();
  if (seed != null) repo.seed(seed);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contactRepositoryModeProvider.overrideWithValue(repo),
        deviceRegionProvider.overrideWithValue(region),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Navigator(
          pages: [
            const MaterialPage(child: Scaffold(body: Text('previous'))),
            MaterialPage(
              child: ContactEditScreen(contactId: seed == null ? null : 'p1'),
            ),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _scrollTo(WidgetTester tester, Finder f) => tester
    .scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('contact-save')));
  await tester.pumpAndSettle();
}

Future<void> _addPhone(WidgetTester tester) async {
  await _scrollTo(tester, find.text(_l.contactAddPhone));
  await tester.tap(find.text(_l.contactAddPhone));
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String search, String rowText) async {
  await tester.tap(find.byKey(const Key('phones-code-0')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('calling-code-search')), search);
  await tester.pumpAndSettle();
  await tester.tap(find.text(rowText).first);
  await tester.pumpAndSettle();
}

void main() {
  const chip0 = Key('phones-code-0');

  testWidgets('pick +86 then type national -> one stored string', (
    tester,
  ) async {
    final repo = await _mount(tester, seed: _seed(const []), region: null);
    await _addPhone(tester);
    expect(
      find.descendant(
        of: find.byKey(chip0),
        matching: find.text(_l.contactCountryCodePlaceholder),
      ),
      findsOneWidget,
    );
    await _pick(tester, '+86', 'China');
    expect(
      find.descendant(
        of: find.byKey(chip0),
        matching: find.text('\u{1F1E8}\u{1F1F3} +86'),
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('phones-value-0')),
      '13800138000',
    );
    await _save(tester);
    expect(
      (await repo.getContact('p1'))!.phones.single.number,
      '+86 13800138000',
    );
  });

  testWidgets('picking a code on its own (no digits) saves nothing', (
    tester,
  ) async {
    final repo = await _mount(tester, seed: _seed(const []), region: null);
    await _addPhone(tester);
    await _pick(tester, '86', 'China');
    await _save(tester);
    expect((await repo.getContact('p1'))!.phones, isEmpty);
  });

  testWidgets('pasting +44 moves the code into the picker', (tester) async {
    final repo = await _mount(tester, seed: _seed(const []), region: null);
    await _addPhone(tester);
    await tester.enterText(
      find.byKey(const Key('phones-value-0')),
      '+44 20 7946 0958',
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(chip0),
        matching: find.text('\u{1F1EC}\u{1F1E7} +44'),
      ),
      findsOneWidget,
    );
    expect(find.text('20 7946 0958'), findsOneWidget);
    await _save(tester);
    expect(
      (await repo.getContact('p1'))!.phones.single.number,
      '+44 20 7946 0958',
    );
  });

  testWidgets('a new row defaults to the injected region', (tester) async {
    await _mount(tester, seed: _seed(const []), region: 'CN');
    await _addPhone(tester);
    expect(
      find.descendant(
        of: find.byKey(chip0),
        matching: find.text('\u{1F1E8}\u{1F1F3} +86'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an unmapped region leaves the code empty', (tester) async {
    await _mount(tester, seed: _seed(const []), region: 'ZZ');
    await _addPhone(tester);
    expect(find.text(_l.contactCountryCodePlaceholder), findsOneWidget);
  });

  testWidgets('untouched phones are written back byte-identical', (
    tester,
  ) async {
    final raws = ['+1-555-0100', '(555) 010-0100', '+999 123'];
    final repo = await _mount(
      tester,
      seed: _seed([
        for (final r in raws) ContactPhone(label: 'mobile', number: r),
      ]),
      region: 'CN',
    );
    // Stored +1 is split for display; a no-+ number shows no code.
    expect(find.text('555-0100'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('contact-first-name')), 'Pat2');
    await _save(tester);
    expect((await repo.getContact('p1'))!.phones.map((p) => p.number), raws);
  });

  testWidgets('only the edited row is recomposed', (tester) async {
    final repo = await _mount(
      tester,
      seed: _seed(const [
        ContactPhone(label: 'mobile', number: '+1-555-0100'),
        ContactPhone(label: 'work', number: '+1-555-0200'),
      ]),
    );
    await tester.enterText(find.byKey(const Key('phones-value-1')), '555-0299');
    await _save(tester);
    expect((await repo.getContact('p1'))!.phones.map((p) => p.number), [
      '+1-555-0100',
      '+1 555-0299',
    ]);
  });

  testWidgets('emails and addresses rows have no picker', (tester) async {
    await _mount(
      tester,
      seed: _seed(
        const [],
        emails: const [ContactEmail(label: 'home', address: 'a@b.c')],
      ),
    );
    expect(find.byKey(const Key('emails-code-0')), findsNothing);
    expect(find.byKey(const Key('addresses-code-0')), findsNothing);
  });

  testWidgets('number field filters letters and stray +', (tester) async {
    await _mount(
      tester,
      seed: _seed(const [ContactPhone(label: 'mobile', number: '')]),
    );
    final f = find.byKey(const Key('phones-value-0'));
    await tester.enterText(f, '+9a9 (1)-2.3+');
    // +99 is not a calling code, so the leading + stays in the field.
    expect(tester.widget<TextField>(f).controller!.text, '+99 (1)-2.3');
  });

  testWidgets('keyboard differs per platform for phones only', (tester) async {
    await _mount(
      tester,
      seed: _seed(const [ContactPhone(label: 'mobile', number: '')]),
      platform: TargetPlatform.android,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('phones-value-0')))
          .keyboardType,
      TextInputType.phone,
    );
    await _mount(
      tester,
      seed: _seed(const [ContactPhone(label: 'mobile', number: '')]),
      platform: TargetPlatform.iOS,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('phones-value-0')))
          .keyboardType,
      const TextInputType.numberWithOptions(signed: true),
    );
  });

  testWidgets('iOS opens a Cupertino popup picker', (tester) async {
    await _mount(
      tester,
      seed: _seed(const [ContactPhone(label: 'mobile', number: '')]),
      platform: TargetPlatform.iOS,
    );
    await tester.tap(find.byKey(chip0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calling-code-search')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('the picker can clear the code', (tester) async {
    final repo = await _mount(
      tester,
      seed: _seed(const [ContactPhone(label: 'mobile', number: '+86 138')]),
    );
    await tester.tap(find.byKey(chip0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l.contactCountryCodeNone));
    await tester.pumpAndSettle();
    await _save(tester);
    expect((await repo.getContact('p1'))!.phones.single.number, '138');
  });
}
