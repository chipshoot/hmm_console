import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_birthday.dart';
import 'package:hmm_console/features/contacts/presentation/widgets/birthday_picker.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

Future<BirthdayPickResult? Function()> _open(
  WidgetTester tester,
  TargetPlatform platform, {
  ContactBirthday? initial,
}) async {
  BirthdayPickResult? result;
  var done = false;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showBirthdayPicker(context, initial: initial);
            done = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () {
    expect(done, isTrue);
    return result;
  };
}

Future<void> _wheel(WidgetTester tester, String key, int items) async {
  await tester.drag(
    find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(ListWheelScrollView),
    ),
    Offset(0, -32.0 * items - kTouchSlop),
  );
  await tester.pumpAndSettle();
}

Future<void> _dropdown(WidgetTester tester, Finder field, String text) async {
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(text),
    100,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('iOS: picks lunar leap 4/5 without a year', (tester) async {
    final result = await _open(tester, TargetPlatform.iOS);
    await tester.tap(find.byKey(const Key('birthday-cal-lunar')));
    await tester.pumpAndSettle();
    await _wheel(tester, 'birthday-month-lunar', 3);
    await _wheel(tester, 'birthday-day-lunar', 4);
    await tester.tap(find.byKey(const Key('birthday-leap')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final r = result();
    expect(r, isA<BirthdayPicked>());
    expect(
      (r! as BirthdayPicked).birthday.toJson(),
      const ContactBirthday(
        calendar: BirthdayCalendar.lunar,
        month: 4,
        day: 5,
        leap: true,
      ).toJson(),
    );
  });

  testWidgets('Android: picks 29 Feb 1960', (tester) async {
    final result = await _open(tester, TargetPlatform.android);
    await _dropdown(
      tester,
      find.byKey(const Key('birthday-month-drop')),
      'February',
    );
    await _dropdown(tester, find.byKey(const Key('birthday-day-drop')), '29');
    await _dropdown(
      tester,
      find.byKey(const Key('birthday-year-drop')),
      '1960',
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(
      (result()! as BirthdayPicked).birthday,
      const ContactBirthday(
        calendar: BirthdayCalendar.gregorian,
        month: 2,
        day: 29,
        year: 1960,
      ),
    );
  });

  for (final p in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$p: Clear returns BirthdayCleared, Cancel returns null', (
      tester,
    ) async {
      const initial = ContactBirthday(
        calendar: BirthdayCalendar.gregorian,
        month: 3,
        day: 4,
      );
      var result = await _open(tester, p, initial: initial);
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(result(), isA<BirthdayCleared>());

      result = await _open(tester, p, initial: initial);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result(), isNull);
    });

    testWidgets('$p: no Clear without an initial value', (tester) async {
      await _open(tester, p);
      expect(find.text('Clear'), findsNothing);
    });
  }

  testWidgets('switching 农历 → 公历 keeps the day within the month', (
    tester,
  ) async {
    final result = await _open(
      tester,
      TargetPlatform.android,
      initial: const ContactBirthday(
        calendar: BirthdayCalendar.lunar,
        month: 2,
        day: 30,
        leap: true,
      ),
    );
    await tester.tap(find.text('Gregorian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(
      (result()! as BirthdayPicked).birthday,
      const ContactBirthday(
        calendar: BirthdayCalendar.gregorian,
        month: 2,
        day: 29,
      ),
    );
  });

  for (final p in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final year in [1850, DateTime.now().year + 3]) {
      testWidgets('$p: out-of-range stored year $year survives Done', (
        tester,
      ) async {
        final initial = ContactBirthday(
          calendar: BirthdayCalendar.gregorian,
          month: 5,
          day: 10,
          year: year,
        );
        final result = await _open(tester, p, initial: initial);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect((result()! as BirthdayPicked).birthday, initial);
      });
    }
  }
}
