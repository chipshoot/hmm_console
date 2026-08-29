import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/driver_licence/data/driver_licence_codec.dart';
import '../../../features/driver_licence/data/i_driver_licence_repository.dart';
import '../../../features/driver_licence/domain/driver_licence.dart';
import '../../../features/notes/data/models/hmm_note.dart';
import '../attachments/attachment_ref.dart';
import '../hmm_note_input.dart';
import 'local_hmm_note_repository.dart';
import 'local_note_catalog_repository.dart';

/// Three segments so `CatalogPalette.domainKeyFor` reads `AutomobileMan` as the
/// domain key and groups this with the rest of the vehicle domain.
const driverLicenceCatalogName = 'Hmm.AutomobileMan.DriverLicence';

/// There is exactly ONE licence, so the subject is fixed rather than derived.
/// A second save updates this note; it can never create a duplicate. A second
/// note would shadow the first and the details would appear to revert at
/// random depending on which was read.
const kDriverLicenceSubject = 'DriverLicence:self';

class LocalDriverLicenceRepository implements IDriverLicenceRepository {
  LocalDriverLicenceRepository(this._notes, this._catalogs);

  final IHmmNoteRepository _notes;
  final INoteCatalogRepository _catalogs;

  static const _pageSize = 100;

  String _serialize(DriverLicence l) => jsonEncode({
        'note': {
          'content': {'DriverLicence': DriverLicenceCodec.toMap(l)},
        },
      });

  /// The image bytes are referenced from the note's `attachments` column, not
  /// from content — that column is the only thing `VaultGc` reads when
  /// deciding what is still live.
  NoteAttachments _attachmentsFor(DriverLicence l) {
    final images = <AttachmentRef>[
      if (l.frontImage != null) l.frontImage!,
      if (l.backImage != null) l.backImage!,
    ];
    return images.isEmpty ? NoteAttachments.empty : NoteAttachments(images: images);
  }

  DriverLicence? _deserialize(HmmNote? note) {
    final content = note?.content;
    if (content == null) return null;
    try {
      final data =
          (jsonDecode(content) as Map)['note']?['content']?['DriverLicence'];
      if (data is Map) {
        return DriverLicenceCodec.fromMap(
          data.cast<String, dynamic>(),
          note!.effectiveAttachments,
        );
      }
      debugPrint('LocalDriverLicenceRepository: note ${note!.id}/${note.uuid} '
          'has no DriverLicence payload; treated as absent.');
      return null;
    } catch (e) {
      // The licence vanishes with nothing on screen to explain it, so name the
      // note here — otherwise this is undiagnosable without reproducing it.
      debugPrint('LocalDriverLicenceRepository: note ${note!.id}/${note.uuid} '
          'has unreadable licence JSON ($e); treated as absent.');
      return null;
    }
  }

  Future<int> _catalogId() async =>
      (await _catalogs.getOrCreateCatalog(driverLicenceCatalogName, '{}')).id;

  /// Finds the licence note by **subject**, not by decoding content: the
  /// subject stays readable when the JSON does not, so a corrupt payload
  /// cannot make `saveLicence` decide the licence is new and write a second
  /// note under the same subject.
  Future<HmmNote?> _note() async {
    final catalogId = await _catalogId();
    var page = 1;
    while (true) {
      final res = await _notes.getNotes(
        catalogId: catalogId,
        page: page,
        pageSize: _pageSize,
      );
      for (final n in res.items) {
        if (n.subject == kDriverLicenceSubject) return n;
      }
      if (res.items.isEmpty || page >= res.meta.totalPages) return null;
      page++;
    }
  }

  @override
  Future<DriverLicence?> getLicence() async => _deserialize(await _note());

  @override
  Future<int?> noteId() async => (await _note())?.id;

  @override
  Future<DriverLicence> saveLicence(DriverLicence licence) async {
    final existing = await _note();
    // `attachments` is passed on BOTH paths: omitting it on update leaves the
    // previous set in place, so a replaced or removed image would keep its
    // bytes alive forever and a stale ref would resolve on the next read.
    if (existing == null) {
      await _notes.createNote(HmmNoteCreate(
        subject: kDriverLicenceSubject,
        catalogId: await _catalogId(),
        content: _serialize(licence),
        attachments: _attachmentsFor(licence),
      ));
    } else {
      await _notes.updateNote(
        existing.id,
        HmmNoteUpdate(
          subject: kDriverLicenceSubject,
          content: _serialize(licence),
          attachments: _attachmentsFor(licence),
        ),
      );
    }
    return licence;
  }
}

final localDriverLicenceRepositoryProvider = Provider<IDriverLicenceRepository>(
  (ref) => LocalDriverLicenceRepository(
    ref.watch(localHmmNoteRepositoryProvider),
    ref.watch(localNoteCatalogRepositoryProvider),
  ),
);
