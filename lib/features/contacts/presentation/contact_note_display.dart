import 'dart:convert';

import '../../../core/data/local/local_contact_repository.dart';
import '../../../core/navigation/route_names.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../notes/data/models/hmm_note.dart';
import '../../notes/rendering/note_display.dart';
import '../data/contact_codec.dart';
import '../domain/contact_name.dart';
import '../domain/entities/contact.dart';
import 'contact_labels.dart';

/// How a contact's note reads in the Notes UI. The subject (`Contact:<id>`)
/// is identity and is never shown.
class ContactNoteDisplay implements NoteDisplayEntry {
  const ContactNoteDisplay();

  static const catalogName = contactCatalogName;
  static const _prefix = 'Contact:';

  @override
  NoteDisplay display(HmmNote note, AppLocalizations l) {
    final c = _decode(note);
    final name = c == null ? '' : ContactName.displayName(c).trim();
    if (c == null || name.isEmpty) {
      return (title: l.notesContactTitleFallback, preview: '');
    }
    final phone = c.phones.map((p) => p.number.trim()).firstWhere(
          (n) => n.isNotEmpty,
          orElse: () => '',
        );
    final preview = [
      relationshipLabel(c.relationship.category, l),
      if (phone.isNotEmpty) phone,
    ].join(' · ');
    return (title: name, preview: preview);
  }

  @override
  NoteTarget? target(HmmNote note) {
    var id = note.subject.startsWith(_prefix)
        ? note.subject.substring(_prefix.length).trim()
        : '';
    if (id.isEmpty) id = _decode(note)?.id ?? '';
    if (id.isEmpty) return null;
    return (route: RouterNames.contactDetail, params: {'id': id});
  }

  Contact? _decode(HmmNote note) {
    final content = note.content;
    if (content == null) return null;
    try {
      final data = (jsonDecode(content) as Map)['note']?['content']?['Contact'];
      if (data is! Map) return null;
      return ContactCodec.fromMap(data.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }
}
