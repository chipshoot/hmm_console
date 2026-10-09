import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/rendering/note_display.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import 'note_display_fixtures.dart';

const _contact = 'Hmm.ContactMan.Contact';
const _sheet = 'Hmm.CheatsheetMan.Cheatsheet';

Future<(NoteDisplayRegistry, AppLocalizations)> _setup(Locale locale) async {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return (
    c.read(noteDisplayRegistryProvider),
    await AppLocalizations.delegate.load(locale),
  );
}

void main() {
  const en = Locale('en');

  test('contact: name, relationship and first phone', () async {
    final (r, l) = await _setup(en);
    final d = r.noteDisplay(contactNote(zhangWei()), _contact, l);
    expect(d.title, '张伟');
    expect(d.preview, 'Doctor · +1 555 0100');
  });

  test('contact without a phone previews the relationship only', () async {
    final (r, l) = await _setup(en);
    final c = zhangWei().copyWith(phones: const []);
    expect(r.noteDisplay(contactNote(c), _contact, l).preview, 'Doctor');
  });

  test('organization shows its organization name', () async {
    final (r, l) = await _setup(en);
    const org = Contact(
      id: 'o-1',
      contactType: ContactType.organization,
      organizationName: 'Acme Clinic',
    );
    expect(r.noteDisplay(contactNote(org), _contact, l).title, 'Acme Clinic');
  });

  test('unreadable or nameless contact reads Contact, never the id', () async {
    final (r, l) = await _setup(en);
    final broken = r.noteDisplay(brokenNote('Contact:c-9', 2), _contact, l);
    expect(broken, (title: 'Contact', preview: ''));
    const nameless = Contact(id: 'c-2', contactType: ContactType.person);
    final d = r.noteDisplay(contactNote(nameless), _contact, l);
    expect(d, (title: 'Contact', preview: ''));
    final (_, zh) = await _setup(const Locale('zh'));
    expect(
      r.noteDisplay(brokenNote('Contact:c-9', 2), _contact, zh).title,
      '联系人',
    );
  });

  test('cheatsheet: card title with group and row count', () async {
    final (r, l) = await _setup(en);
    final d = r.noteDisplay(cheatsheetNote(vehicleCard()), _sheet, l);
    expect(d, (title: 'Civic', preview: 'Vehicle · 9 rows'));
  });

  test('cheatsheet with one row is singular', () async {
    final (r, l) = await _setup(en);
    final one = cheatsheetNote(
      vehicleCard().copyWith(rows: [CheatsheetRow(label: 'a', source: null)]),
    );
    expect(r.noteDisplay(one, _sheet, l).preview, 'Vehicle · 1 row');
  });

  test('unreadable card reads Cheatsheet card', () async {
    final (r, l) = await _setup(en);
    final d = r.noteDisplay(brokenNote('Cheatsheet:x', 3), _sheet, l);
    expect(d, (title: 'Cheatsheet card', preview: ''));
  });

  test('other catalogs keep subject and preview', () async {
    final (r, l) = await _setup(en);
    final n = HmmNote(
      id: 1,
      uuid: 'u',
      subject: 'Grocery list',
      authorId: 1,
      createDate: DateTime(2026, 1, 1),
      content: 'Milk, eggs',
    );
    expect(r.noteDisplay(n, 'General', l), (
      title: 'Grocery list',
      preview: 'Milk, eggs',
    ));
    expect(r.noteDisplay(n, null, l).title, 'Grocery list');
  });

  test('targets: contact and cheatsheet ids come from the subject', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final r = c.read(noteDisplayRegistryProvider);
    final ct = r.targetFor(contactNote(zhangWei()), _contact)!;
    expect(ct.route, RouterNames.contactDetail);
    expect(ct.params, {'id': 'c-1'});
    final st = r.targetFor(cheatsheetNote(vehicleCard()), _sheet)!;
    expect(st.route, RouterNames.cheatsheetDetail);
    expect(st.params, {'id': 'card-1'});
    expect(r.targetFor(brokenNote('Contact:', 2), _contact), isNull);
    expect(r.targetFor(brokenNote('Anything', 1), 'General'), isNull);
  });
}
