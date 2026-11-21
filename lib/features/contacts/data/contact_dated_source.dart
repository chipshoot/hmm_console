import '../../calendar/contract/dated_note.dart';
import '../../calendar/domain/calendar_event.dart';
import '../domain/entities/contact.dart';
import '../domain/entities/contact_birthday.dart';
import 'i_contact_repository.dart';

/// Adapter so the contact entity stays free of calendar types.
class ContactDatedNote implements DatedNote {
  const ContactDatedNote(this.contact);

  final Contact contact;

  @override
  List<DatedItem> get dates {
    final b = contact.birthday;
    if (b == null || !contact.remindBirthday) return const [];
    return [
      DatedItem(
        key: 'contact:${contact.id}:birthday',
        kind: LinkedKind.birthday,
        args: {
          'name': contact.displayName,
          'birthYear': b.year,
          'calendar': b.calendar.name,
        },
        date: birthdaySeriesStart(b),
        repeat: birthdayRule(b),
        owner: EventOwner(
          subsystem: kLinkedSubsystemContacts,
          noteUuid: contact.id,
        ),
      ),
    ];
  }
}

/// Supplies contact birthdays to the linked-dates matcher. The repository is
/// read lazily because its provider throws in Cloud API mode.
class ContactDatedSource implements DatedNoteSource {
  ContactDatedSource(this._repo);

  final IContactRepository Function() _repo;

  @override
  Set<String> get subsystems => const {kLinkedSubsystemContacts};

  @override
  Future<List<DatedNote>> datedNotes() async => [
    for (final c in await _repo().getContacts())
      if (c.isActivated && c.birthday != null && c.remindBirthday)
        ContactDatedNote(c),
  ];

  @override
  Future<String?> locationOf(EventOwner owner) async {
    final id = owner.noteUuid;
    if (owner.subsystem != kLinkedSubsystemContacts || id == null) return null;
    final c = await _repo().getContact(id);
    return c == null || !c.isActivated ? null : '/contacts/$id';
  }
}
