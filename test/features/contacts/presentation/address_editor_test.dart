import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/widgets/hmm_icon_button.dart';
import 'package:hmm_console/features/contacts/data/contact_codec.dart';
import 'package:hmm_console/features/contacts/domain/address_format.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contact_edit_screen.dart';
import 'package:hmm_console/features/contacts/states/device_region_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../data/contact_repository_fakes.dart';

AppLocalizations get _l => lookupAppLocalizations(const Locale('en'));

Contact _seed([List<ContactAddress> addresses = const []]) => Contact(
  id: 'a1',
  contactType: ContactType.person,
  firstName: 'Pat',
  addresses: addresses,
);

Future<InMemoryContactRepository> _mount(
  WidgetTester tester, {
  Contact? seed,
  String? region,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  // Tall surface: an address card is several fields high.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
              child: ContactEditScreen(contactId: seed == null ? null : 'a1'),
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

Finder _k(String key) => find.byKey(Key(key));

Future<void> _scrollTo(WidgetTester tester, Finder f) => tester
    .scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);

Future<void> _save(WidgetTester tester) async {
  await tester.tap(_k('contact-save'));
  await tester.pumpAndSettle();
}

Future<void> _addAddress(WidgetTester tester) async {
  await _scrollTo(tester, find.text(_l.contactAddAddress));
  await tester.tap(find.text(_l.contactAddAddress));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await _scrollTo(tester, _k(key));
  await tester.enterText(_k(key), text);
  await tester.pump();
}

Future<void> _pickRegion(
  WidgetTester tester,
  String search,
  String code, {
  int row = 0,
}) async {
  await _scrollTo(tester, _k('addresses-region-$row'));
  await tester.tap(_k('addresses-region-$row'));
  await tester.pumpAndSettle();
  await tester.enterText(_k('region-search'), search);
  await tester.pumpAndSettle();
  await tester.tap(_k('region-$code'));
  await tester.pumpAndSettle();
}

Future<void> _pickCountry(
  WidgetTester tester,
  String label, {
  int row = 0,
}) async {
  await _scrollTo(tester, _k('addresses-country-$row'));
  await tester.tap(_k('addresses-country-$row'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(_k(key)).controller!.text;

void main() {
  testWidgets('a new address defaults to the device region', (tester) async {
    await _mount(tester, seed: _seed(), region: 'CA');
    await _addAddress(tester);
    expect(_k('addresses-street1-0'), findsOneWidget);
    expect(find.text(_l.contactAddressProvinceTerritory), findsOneWidget);
    expect(find.text(_l.contactAddressCountryCA), findsOneWidget);
    expect(_k('addresses-value-0'), findsNothing);
  });

  testWidgets('a region outside US/CA/CN starts as Other free text', (
    tester,
  ) async {
    await _mount(tester, seed: _seed(), region: 'GB');
    await _addAddress(tester);
    expect(_k('addresses-value-0'), findsOneWidget);
    expect(_k('addresses-street1-0'), findsNothing);
    final f = tester.widget<TextField>(_k('addresses-value-0'));
    expect(f.maxLines, greaterThanOrEqualTo(4));
  });

  testWidgets('add a US address: exact saved parts and derived value', (
    tester,
  ) async {
    final repo = await _mount(tester, seed: _seed(), region: 'US');
    await _addAddress(tester);
    expect(find.text(_l.contactAddressZip), findsOneWidget);
    expect(find.text(_l.contactAddressState), findsOneWidget);
    await _enter(tester, 'addresses-street1-0', '1 Main St');
    await _enter(tester, 'addresses-street2-0', 'Apt 4B');
    await _enter(tester, 'addresses-city-0', 'Springfield');
    await _pickRegion(tester, 'illinois', 'IL');
    await _enter(tester, 'addresses-postal-0', '62701');
    await _save(tester);
    final a = (await repo.getContact('a1'))!.addresses.single;
    expect(a.label, 'home');
    expect(a.country, 'US');
    expect(a.street1, '1 Main St');
    expect(a.street2, 'Apt 4B');
    expect(a.city, 'Springfield');
    expect(a.region, 'IL');
    expect(a.postalCode, '62701');
    expect(a.district, isNull);
    expect(a.value, '1 Main St, Apt 4B, Springfield, IL 62701, United States');
  });

  testWidgets('a CN address picked by Chinese name saves in CN order', (
    tester,
  ) async {
    final repo = await _mount(tester, seed: _seed(), region: 'CN');
    await _addAddress(tester);
    expect(find.text(_l.contactAddressCnDetail), findsOneWidget);
    await _pickRegion(tester, '广东', 'GD');
    expect(find.text('广东省'), findsOneWidget, reason: 'button shows name');
    await _enter(tester, 'addresses-city-0', '深圳市');
    await _enter(tester, 'addresses-district-0', '南山区');
    await _enter(tester, 'addresses-street1-0', '科技园路1号 3栋 1201室');
    await _enter(tester, 'addresses-postal-0', '518000');
    expect(
      tester.widget<TextField>(_k('addresses-street1-0')).maxLines,
      greaterThan(1),
      reason: '详细地址 is multi-line',
    );
    await _save(tester);
    final a = (await repo.getContact('a1'))!.addresses.single;
    expect(a.country, 'CN');
    expect(a.region, 'GD');
    expect(a.street2, isNull);
    expect(a.value, '中国 广东省 深圳市 南山区 科技园路1号 3栋 1201室 邮编 518000');
  });

  testWidgets('an invalid ZIP shows an error and blocks the save', (
    tester,
  ) async {
    final repo = await _mount(tester, seed: _seed(), region: 'US');
    await _addAddress(tester);
    await _enter(tester, 'addresses-city-0', 'Springfield');
    await _enter(tester, 'addresses-postal-0', '1234');
    expect(find.text(_l.contactAddressInvalidZip), findsOneWidget);
    await _save(tester);
    expect(repo.saveCalls, 0);
    expect(find.byType(ContactEditScreen), findsOneWidget);
    await _enter(tester, 'addresses-postal-0', '12345-6789');
    expect(find.text(_l.contactAddressInvalidZip), findsNothing);
    await _save(tester);
    expect(repo.saveCalls, 1);
    expect(
      (await repo.getContact('a1'))!.addresses.single.postalCode,
      '12345-6789',
    );
  });

  testWidgets('a CA postal code is normalized on save', (tester) async {
    final repo = await _mount(tester, seed: _seed(), region: 'CA');
    await _addAddress(tester);
    await _enter(tester, 'addresses-city-0', 'Ottawa');
    await _pickRegion(tester, 'ON', 'ON');
    await _enter(tester, 'addresses-postal-0', 'k1m1m4');
    await _save(tester);
    final a = (await repo.getContact('a1'))!.addresses.single;
    expect(a.postalCode, 'K1M 1M4');
    expect(a.value, 'Ottawa ON K1M 1M4, Canada');
  });

  testWidgets('switching US to CN keeps city text and clears the region', (
    tester,
  ) async {
    final repo = await _mount(tester, seed: _seed(), region: 'US');
    await _addAddress(tester);
    await _enter(tester, 'addresses-city-0', 'Springfield');
    await _pickRegion(tester, 'IL', 'IL');
    await _enter(tester, 'addresses-postal-0', '62701');
    await _pickCountry(tester, _l.contactAddressCountryCN);
    expect(_text(tester, 'addresses-city-0'), 'Springfield');
    expect(_k('addresses-district-0'), findsOneWidget);
    expect(find.text('Illinois'), findsNothing);
    expect(find.text(_l.contactAddressRegionSelect), findsOneWidget);
    // 62701 is not a 6-digit CN code: re-validated.
    expect(find.text(_l.contactAddressInvalidCnPostal), findsOneWidget);
    await _enter(tester, 'addresses-postal-0', '');
    await _save(tester);
    final a = (await repo.getContact('a1'))!.addresses.single;
    expect(a.country, 'CN');
    expect(a.city, 'Springfield');
    expect(a.region, isNull);
  });

  testWidgets('switching to Other pre-fills the text from the parts', (
    tester,
  ) async {
    final repo = await _mount(tester, seed: _seed(), region: 'US');
    await _addAddress(tester);
    await _enter(tester, 'addresses-street1-0', '1 Main St');
    await _enter(tester, 'addresses-city-0', 'Springfield');
    await _pickRegion(tester, 'IL', 'IL');
    await _pickCountry(tester, _l.contactAddressCountryOther);
    const text = '1 Main St\nSpringfield, IL\nUnited States';
    expect(_text(tester, 'addresses-value-0'), text);
    await _save(tester);
    final a = (await repo.getContact('a1'))!.addresses.single;
    expect(a.country, isNull);
    expect(a.value, text);
    expect(a.street1, isNull);
    expect(a.region, isNull);
  });

  testWidgets('an existing free-form address opens as Other, unparsed', (
    tester,
  ) async {
    await _mount(
      tester,
      seed: _seed(const [
        ContactAddress(label: 'home', value: '1 Main St, Springfield, IL'),
      ]),
      region: 'US',
    );
    expect(_text(tester, 'addresses-value-0'), '1 Main St, Springfield, IL');
    expect(_k('addresses-street1-0'), findsNothing);
    expect(
      tester.widget<DropdownButton<String>>(_k('addresses-country-0')).value,
      '',
      reason: 'Other',
    );
  });

  testWidgets('untouched addresses are written back byte-identical', (
    tester,
  ) async {
    final stored = <String, dynamic>{
      'schemaVersion': 1,
      'id': 'a1',
      'contactType': 'person',
      'firstName': 'Pat',
      'addresses': [
        {'label': 'home', 'value': '1 Main St\nSpringfield'},
        {
          'geo': {'lat': 1},
          'label': 'work',
          // Not what formatSingleLine would produce: must not be re-derived.
          'value': 'hand-written value',
          'country': 'US',
          'city': 'Springfield',
          'region': 'IL',
          'postalCode': 62701,
        },
        {'label': 'astronaut-base', 'value': 'Moon'},
      ],
    };
    final repo = await _mount(
      tester,
      seed: ContactCodec.fromMap(stored),
      region: 'CN',
    );
    await tester.enterText(_k('contact-first-name'), 'Pat2');
    await _save(tester);
    final saved = ContactCodec.toMap((await repo.getContact('a1'))!);
    expect(saved['firstName'], 'Pat2');
    expect(jsonEncode(saved['addresses']), jsonEncode(stored['addresses']));
  });

  testWidgets('a label-only change keeps the address parts and value', (
    tester,
  ) async {
    const a = ContactAddress(
      label: 'home',
      value: 'hand-written value',
      country: 'US',
      city: 'Springfield',
    );
    final repo = await _mount(tester, seed: _seed(const [a]), region: 'US');
    await _scrollTo(tester, _k('addresses-label-0'));
    await tester.tap(_k('addresses-label-0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l.fieldLabelWork).last);
    await tester.pumpAndSettle();
    await _save(tester);
    final s = (await repo.getContact('a1'))!.addresses.single;
    expect(s.label, 'work');
    expect(s.value, 'hand-written value');
    expect(s.city, 'Springfield');
  });

  testWidgets('editing one part re-derives the stored value', (tester) async {
    const a = ContactAddress(
      label: 'home',
      value: 'hand-written value',
      country: 'US',
      city: 'Springfield',
    );
    final repo = await _mount(tester, seed: _seed(const [a]), region: 'US');
    expect(_text(tester, 'addresses-city-0'), 'Springfield');
    await _enter(tester, 'addresses-city-0', 'Chicago');
    await _save(tester);
    final s = (await repo.getContact('a1'))!.addresses.single;
    expect(s.city, 'Chicago');
    expect(s.value, formatSingleLine(s));
    expect(s.value, 'Chicago, United States');
  });

  testWidgets('remove uses the localized icon button', (tester) async {
    final repo = await _mount(
      tester,
      seed: _seed(const [ContactAddress(label: 'home', value: 'x')]),
    );
    final remove = find.descendant(
      of: find.byKey(const Key('addresses-card-0')),
      matching: find.byType(HmmIconButton),
    );
    expect(remove, findsOneWidget);
    expect(
      tester.widget<HmmIconButton>(remove).tooltip,
      _l.contactRemoveFieldTooltip,
    );
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await _save(tester);
    expect((await repo.getContact('a1'))!.addresses, isEmpty);
  });

  testWidgets('iOS opens the region picker as a Cupertino popup', (
    tester,
  ) async {
    await _mount(
      tester,
      seed: _seed(),
      region: 'US',
      platform: TargetPlatform.iOS,
    );
    await _addAddress(tester);
    await tester.tap(_k('addresses-region-0'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPopupSurface), findsOneWidget);
    expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('Android opens the region picker as a bottom sheet', (
    tester,
  ) async {
    await _mount(tester, seed: _seed(), region: 'CN');
    await _addAddress(tester);
    await tester.tap(_k('addresses-region-0'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    // Searchable by pinyin.
    await tester.enterText(_k('region-search'), 'xinjiang');
    await tester.pumpAndSettle();
    expect(_k('region-XJ'), findsOneWidget);
    expect(_k('region-GD'), findsNothing);
  });

  testWidgets('editing keeps a stored part the form does not show', (
    tester,
  ) async {
    const us = ContactAddress(
      label: 'home',
      value: 'v',
      country: 'US',
      city: 'Springfield',
      district: 'Sangamon County',
    );
    const cn = ContactAddress(
      label: 'work',
      value: 'v',
      country: 'CN',
      city: '深圳市',
      street2: 'B座',
    );
    final repo = await _mount(
      tester,
      seed: _seed(const [us, cn]),
      region: 'US',
    );
    await _enter(tester, 'addresses-city-0', 'Chicago');
    await _enter(tester, 'addresses-city-1', '广州市');
    await _save(tester);
    final saved = (await repo.getContact('a1'))!.addresses;
    expect(saved[0].city, 'Chicago');
    expect(saved[0].district, 'Sangamon County');
    expect(saved[0].value, 'Chicago, United States');
    expect(saved[1].city, '广州市');
    expect(saved[1].street2, 'B座');
  });

  testWidgets('a hidden part is not carried into another country', (
    tester,
  ) async {
    const us = ContactAddress(
      label: 'home',
      value: 'v',
      country: 'US',
      city: 'Springfield',
      district: 'Sangamon County',
    );
    final repo = await _mount(tester, seed: _seed(const [us]), region: 'US');
    await _pickCountry(tester, _l.contactAddressCountryCA);
    await _save(tester);
    final a = (await repo.getContact('a1'))!.addresses.single;
    expect(a.country, 'CA');
    expect(a.district, isNull);
  });

  testWidgets('a refused save says why and reveals the postal field', (
    tester,
  ) async {
    final repo = InMemoryContactRepository()..seed(_seed());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contactRepositoryModeProvider.overrideWithValue(repo),
          deviceRegionProvider.overrideWithValue('US'),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ContactEditScreen(contactId: 'a1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _addAddress(tester);
    await _enter(tester, 'addresses-postal-0', '1234');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    final view = tester.getRect(find.byType(Scrollable).first);
    expect(view.overlaps(tester.getRect(_k('addresses-postal-0'))), isFalse);
    await _save(tester);
    expect(repo.saveCalls, 0);
    expect(find.text(_l.contactAddressFixPostal), findsOneWidget);
    final field = tester.getRect(_k('addresses-postal-0'));
    expect(
      view.contains(field.topLeft) && view.contains(field.bottomRight),
      isTrue,
    );
  });
}
