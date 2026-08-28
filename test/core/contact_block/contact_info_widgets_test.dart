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
        value: const ContactInfo(role: ContactRoles.agent),
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

    testWidgets('renders role labels, never the stored literal', (tester) async {
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(role: ContactRoles.doctor),
        onChanged: (_) {},
      )));

      expect(find.text('Doctor'), findsOneWidget);
      expect(find.text('doctor'), findsNothing);
    });

    testWidgets('a role this version does not offer stays selectable', (tester) async {
      // Otherwise merely opening the form would rewrite the stored value.
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(role: 'veterinarian'),
        onChanged: (_) {},
      )));

      expect(find.text('veterinarian'), findsOneWidget);
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

    testWidgets('labels translate but the stored role does not', (tester) async {
      await tester.pumpWidget(host(
        ContactInfoEditor(
          value: const ContactInfo(role: ContactRoles.doctor),
          onChanged: (_) {},
        ),
        locale: const Locale('zh'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('医生'), findsOneWidget);
      expect(find.text('Doctor'), findsNothing);
    });
  });


  testWidgets('resyncs when the parent supplies a different value', (tester) async {
    // Removing a block shifts later blocks down an index. The editors are
    // keyed by index, so Flutter reuses the State for that slot and initState
    // does NOT run again - without a resync the fields keep showing the
    // removed block's text while the model underneath is the next one.
    await tester.pumpWidget(host(ContactInfoEditor(
      value: const ContactInfo(role: ContactRoles.agent, name: 'Ada', phone: '111'),
      onChanged: (_) {},
    )));
    expect(find.text('Ada'), findsOneWidget);

    await tester.pumpWidget(host(ContactInfoEditor(
      value: const ContactInfo(role: ContactRoles.doctor, name: 'Grace', phone: '222'),
      onChanged: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Grace'), findsOneWidget);
    expect(find.text('222'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);
  });


    testWidgets('changing the role keeps text typed just before it', (tester) async {
      // The role handler used to emit widget.value.copyWith(role:), and the
      // parent does not setState on text edits, so widget.value was stale and
      // the just-typed number was silently wiped.
      ContactInfo? seen;
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(role: ContactRoles.agent),
        onChanged: (c) => seen = c,
      )));

      await tester.enterText(find.byKey(const Key('contactPhoneField')), '555-0100');
      await tester.tap(find.byKey(const Key('contactRoleField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Doctor').last);
      await tester.pumpAndSettle();

      expect(seen!.role, ContactRoles.doctor);
      expect(seen!.phone, '555-0100');
    });


    testWidgets('editing one field leaves the others untouched', (tester) async {
      // The original version of this test started from an all-empty contact,
      // so hardcoding the other fields to null would have passed it.
      ContactInfo? seen;
      await tester.pumpWidget(host(ContactInfoEditor(
        value: const ContactInfo(
          role: ContactRoles.doctor,
          name: 'Grace',
          organization: 'General',
          phone: '111',
          email: 'g@example.com',
          address: '1 Main St',
          notes: 'after hours',
        ),
        onChanged: (c) => seen = c,
      )));

      await tester.enterText(find.byKey(const Key('contactPhoneField')), '222');

      expect(seen!.phone, '222');
      expect(seen!.name, 'Grace');
      expect(seen!.organization, 'General');
      expect(seen!.email, 'g@example.com');
      expect(seen!.address, '1 Main St');
      expect(seen!.notes, 'after hours');
      expect(seen!.role, ContactRoles.doctor);
    });

  group('view', () {
    testWidgets('taps report the value that was tapped', (tester) async {
      String? called;
      String? mapped;
      await tester.pumpWidget(host(ContactInfoView(
        value: const ContactInfo(
          role: ContactRoles.agent,
          name: 'Ada',
          phone: '555-0100',
          address: '1 Analytical Way',
        ),
        onCall: (v) => called = v,
        onMap: (v) => mapped = v,
      )));

      await tester.tap(find.byKey(const Key('contactCallRow')));
      expect(called, '555-0100');

      await tester.tap(find.byKey(const Key('contactMapRow')));
      expect(mapped, '1 Analytical Way');
    });

    testWidgets('absent fields render nothing at all', (tester) async {
      await tester.pumpWidget(host(const ContactInfoView(
        value: ContactInfo(role: ContactRoles.emergency, phone: '911'),
      )));

      expect(find.byKey(const Key('contactCallRow')), findsOneWidget);
      expect(find.byKey(const Key('contactEmailRow')), findsNothing);
      expect(find.byKey(const Key('contactMapRow')), findsNothing);
    });

    testWidgets('an unnamed organization is not printed twice', (tester) async {
      await tester.pumpWidget(host(const ContactInfoView(
        value: ContactInfo(role: 'hospital', organization: 'General'),
      )));

      expect(find.text('General'), findsOneWidget);
    });
  });
}
