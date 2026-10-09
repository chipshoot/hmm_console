import 'dart:convert';

import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_codec.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/contacts/data/contact_codec.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

const generalCatalog = NoteCatalog(
  id: 1,
  name: 'General',
  schema: '{}',
  formatType: 0,
  isDefault: false,
);
const contactCatalog = NoteCatalog(
  id: 2,
  name: 'Hmm.ContactMan.Contact',
  schema: '{}',
  formatType: 0,
  isDefault: false,
);
const cheatsheetCatalog = NoteCatalog(
  id: 3,
  name: 'Hmm.CheatsheetMan.Cheatsheet',
  schema: '{}',
  formatType: 0,
  isDefault: false,
);

HmmNote contactNote(Contact c, {int id = 20}) => HmmNote(
  id: id,
  uuid: 'uuid-${c.id}',
  subject: 'Contact:${c.id}',
  authorId: 1,
  catalogId: 2,
  createDate: DateTime(2026, 6, 1),
  content: jsonEncode({
    'note': {
      'content': {'Contact': ContactCodec.toMap(c)},
    },
  }),
);

HmmNote cheatsheetNote(CheatsheetCard c, {int id = 30}) => HmmNote(
  id: id,
  uuid: 'uuid-${c.id}',
  subject: 'Cheatsheet:${c.id}',
  authorId: 1,
  catalogId: 3,
  createDate: DateTime(2026, 6, 1),
  content: jsonEncode({
    'note': {
      'content': {'Cheatsheet': CheatsheetCodec.toMap(c)},
    },
  }),
);

HmmNote brokenNote(String subject, int catalogId, {int id = 40}) => HmmNote(
  id: id,
  uuid: 'broken',
  subject: subject,
  authorId: 1,
  catalogId: catalogId,
  createDate: DateTime(2026, 6, 1),
  content: '{not json',
);

Contact zhangWei() => const Contact(
  id: 'c-1',
  contactType: ContactType.person,
  firstName: '伟',
  lastName: '张',
  relationship: ContactRelationship(category: RelationshipCategory.doctor),
  phones: [ContactPhone(label: 'mobile', number: '+1 555 0100')],
);

CheatsheetCard vehicleCard() => CheatsheetCard(
  id: 'card-1',
  title: 'Civic',
  walletGroup: 'Vehicle',
  tags: const [],
  templateId: 't',
  rows: [for (var i = 0; i < 9; i++) CheatsheetRow(label: 'r$i', source: null)],
);
