import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/contact_block/contact_info.dart';
import 'package:hmm_console/core/contact_block/widgets/contact_info_editor.dart';
import 'package:hmm_console/core/contact_block/widgets/contact_info_view.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  Widget host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  group('editor', () {
    testWidgets('reports edits without owning the value', (tester) async {
      ContactInfo? seen;
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(),
        onChanged: (c) => seen = c,
      )));

      await tester.enterText(find.byKey(const Key('contactNameField')), 'Ada');
      expect(seen!.name, 'Ada');

      await tester.enterText(find.byKey(const Key('contactPhoneField')), '555');
      expect(seen!.phone, '555');
    });

    testWidgets('a cleared field becomes absent, not an empty string', (tester) async {
      ContactInfo? seen;
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(phone: '555'),
        onChanged: (c) => seen = c,
      )));

      await tester.enterText(find.byKey(const Key('contactPhoneField')), '   ');
      expect(seen!.phone, isNull);
    });



    testWidgets('remove is offered only when the owner allows it', (tester) async {
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(),
        onChanged: (_) {},
      )));
      expect(find.byKey(const Key('contactRemoveButton')), findsNothing);

      var removed = false;
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(),
        onChanged: (_) {},
        onRemove: () => removed = true,
      )));
      await tester.tap(find.byKey(const Key('contactRemoveButton')));
      expect(removed, isTrue);
    });

  });


  testWidgets('resyncs when the parent supplies a different value', (tester) async {
    // Removing a block shifts later blocks down an index. The editors are
    // keyed by index, so Flutter reuses the State for that slot and initState
    // does NOT run again - without a resync the fields keep showing the
    // removed block's text while the model underneath is the next one.
    await tester.pumpWidget(host(ContactInfoEditor(
      value: const ContactInfo(name: 'Ada', phone: '111'),
      onChanged: (_) {},
    )));
    expect(find.text('Ada'), findsOneWidget);

    await tester.pumpWidget(host(ContactInfoEditor(
      value: const ContactInfo(name: 'Grace', phone: '222'),
      onChanged: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Grace'), findsOneWidget);
    expect(find.text('222'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);
  });




    testWidgets('editing one field leaves the others untouched', (tester) async {
      // The original version of this test started from an all-empty contact,
      // so hardcoding the other fields to null would have passed it.
      ContactInfo? seen;
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(
                    name: 'Grace',
          organization: 'General',
          phone: '111',
          mobile: '333',
          fax: '444',
          email: 'g@example.com',
          address: ContactAddress(street: '1 Main St', city: 'Ottawa'),
          notes: 'after hours',
        ),
        onChanged: (c) => seen = c,
      )));

      await tester.enterText(find.byKey(const Key('contactPhoneField')), '222');

      expect(seen!.phone, '222');
      expect(seen!.name, 'Grace');
      expect(seen!.organization, 'General');
      expect(seen!.mobile, '333');
      expect(seen!.fax, '444');
      expect(seen!.email, 'g@example.com');
      expect(seen!.address!.street, '1 Main St');
      expect(seen!.address!.city, 'Ottawa');
      expect(seen!.notes, 'after hours');
    });

  group('view', () {
    testWidgets('taps report the value that was tapped', (tester) async {
      String? called;
      String? mapped;
      await tester.pumpWidget(host(ContactInfoView(
        value: const ContactInfo(
                    name: 'Ada',
          phone: '555-0100',
          address: ContactAddress(street: '1 Analytical Way', city: 'Ottawa'),
        ),
        onCall: (v) => called = v,
        onMap: (v) => mapped = v,
      )));

      await tester.tap(find.byKey(const Key('contactCallRow')));
      expect(called, '555-0100');

      await tester.tap(find.byKey(const Key('contactMapRow')));
      expect(mapped, '1 Analytical Way, Ottawa');
    });

    testWidgets('absent fields render nothing at all', (tester) async {
      await tester.pumpWidget(host(const ContactInfoView(
        value: ContactInfo(phone: '911'),
      )));

      expect(find.byKey(const Key('contactCallRow')), findsOneWidget);
      expect(find.byKey(const Key('contactEmailRow')), findsNothing);
      expect(find.byKey(const Key('contactMapRow')), findsNothing);
    });

    testWidgets('an unnamed organization is not printed twice', (tester) async {
      await tester.pumpWidget(host(const ContactInfoView(
        value: ContactInfo(organization: 'General'),
      )));

      expect(find.text('General'), findsOneWidget);
    });
  });

  group('phone punctuation', () {
    testWidgets('a dash survives being typed into every number field', (tester) async {
      // The reported bug. The field must ACCEPT the character regardless of
      // which keyboard produced it — typing, pasting or a hardware keyboard.
      ContactInfo? seen;
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(),
        onChanged: (c) => seen = c,
      )));

      await tester.enterText(
          find.byKey(const Key('contactPhoneField')), '613-555-0142');
      expect(seen!.phone, '613-555-0142');

      await tester.enterText(
          find.byKey(const Key('contactMobileField')), '(613) 555-0143');
      expect(seen!.mobile, '(613) 555-0143');

      await tester.enterText(
          find.byKey(const Key('contactFaxField')), '+1 613-555-0144');
      expect(seen!.fax, '+1 613-555-0144');
    });

    testWidgets('letters are still kept out of a number field', (tester) async {
      ContactInfo? seen;
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(),
        onChanged: (c) => seen = c,
      )));

      await tester.enterText(
          find.byKey(const Key('contactPhoneField')), 'call me 613-555-0142');
      // The letters are gone; the spaces they sat between are legal in a
      // number and are kept, exactly as typed.
      expect(seen!.phone, '  613-555-0142');
    });

    testWidgets('the number fields ask for a keyboard that HAS a dash', (tester) async {
      // TextInputType.phone is the iOS phone pad: digits and +*# only, no
      // dash key. That is what made the character untypable on device, and a
      // formatter alone cannot fix it.
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(),
        onChanged: (_) {},
      )));

      for (final k in ['contactPhoneField', 'contactMobileField', 'contactFaxField']) {
        // Read off the rendered EditableText, not our own wrapper, so this
        // asserts what the platform is actually asked for.
        final field = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(Key(k)),
            matching: find.byType(EditableText),
          ),
        );
        expect(field.keyboardType, const TextInputType.numberWithOptions(signed: true),
            reason: '$k must not use the dashless phone pad');
      }
    });
  });

  group('address', () {
    testWidgets('each part is edited on its own and reaches the value', (tester) async {
      ContactInfo? seen;
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(),
        onChanged: (c) => seen = c,
      )));

      await tester.enterText(find.byKey(const Key('contactStreetField')), '1 Main St');
      await tester.enterText(find.byKey(const Key('contactCityField')), 'Ottawa');
      await tester.enterText(find.byKey(const Key('contactRegionField')), 'ON');
      await tester.enterText(find.byKey(const Key('contactPostalCodeField')), 'K1A 0B1');
      await tester.enterText(find.byKey(const Key('contactCountryField')), 'Canada');

      expect(seen!.address!.street, '1 Main St');
      expect(seen!.address!.city, 'Ottawa');
      expect(seen!.address!.region, 'ON');
      expect(seen!.address!.postalCode, 'K1A 0B1');
      expect(seen!.address!.country, 'Canada');
    });

    testWidgets('an untouched address stays absent rather than empty', (tester) async {
      ContactInfo? seen;
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(),
        onChanged: (c) => seen = c,
      )));

      await tester.enterText(find.byKey(const Key('contactNameField')), 'Ada');
      expect(seen!.address, isNull);
    });

    testWidgets('a preserved address key survives an edit through the editor', (tester) async {
      // The editor models five parts; a sixth written by a newer client must
      // not be dropped just because this build cannot show it.
      ContactInfo? seen;
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(
                    address: ContactAddress(
            city: 'Ottawa',
            extraFields: {'unit': '4B'},
          ),
        ),
        onChanged: (c) => seen = c,
      )));

      await tester.enterText(find.byKey(const Key('contactCityField')), 'Kanata');

      expect(seen!.address!.city, 'Kanata');
      expect(seen!.address!.extraFields['unit'], '4B');
    });

    testWidgets('the view prints the address on separate lines', (tester) async {
      await tester.pumpWidget(host(const ContactInfoView(
        value: ContactInfo(
                    address: ContactAddress(
            street: '1 Main St',
            city: 'Ottawa',
            region: 'ON',
            postalCode: 'K1A 0B1',
            country: 'Canada',
          ),
        ),
      )));

      expect(find.text('1 Main St'), findsOneWidget);
      expect(find.text('Ottawa, ON K1A 0B1'), findsOneWidget);
      expect(find.text('Canada'), findsOneWidget);
    });
  });

  group('cell and fax in the view', () {
    testWidgets('each number gets its own row', (tester) async {
      await tester.pumpWidget(host(const ContactInfoView(
        value: ContactInfo(
                    phone: '555-0100',
          mobile: '555-0111',
          fax: '555-0122',
        ),
      )));

      expect(find.byKey(const Key('contactCallRow')), findsOneWidget);
      expect(find.byKey(const Key('contactMobileRow')), findsOneWidget);
      expect(find.byKey(const Key('contactFaxRow')), findsOneWidget);
    });

    testWidgets('a contact with no cell shows no cell row', (tester) async {
      await tester.pumpWidget(host(const ContactInfoView(
        value: ContactInfo(phone: '555-0100'),
      )));

      expect(find.byKey(const Key('contactMobileRow')), findsNothing);
      expect(find.byKey(const Key('contactFaxRow')), findsNothing);
    });

    testWidgets('tapping the cell row reports the cell, not the landline', (tester) async {
      String? called;
      await tester.pumpWidget(host(ContactInfoView(
        value: const ContactInfo(
                    phone: '555-0100',
          mobile: '555-0111',
        ),
        onCall: (v) => called = v,
      )));

      await tester.tap(find.byKey(const Key('contactMobileRow')));
      expect(called, '555-0111');
    });
  });
}
