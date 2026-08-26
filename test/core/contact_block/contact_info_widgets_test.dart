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
