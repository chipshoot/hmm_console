import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/automobile_records/data/repositories/service_record_repository.dart';
import '../../../features/automobile_records/domain/entities/line_item_type.dart';
import '../../../features/automobile_records/domain/entities/part_item.dart';
import '../../../features/automobile_records/domain/entities/service_record.dart';
import '../../../features/automobile_records/domain/entities/service_type.dart';
import '../../../features/notes/data/models/hmm_note.dart';
import '../attachments/attachment_ref.dart';
import '../hmm_note_input.dart';
import 'local_hmm_note_repository.dart';
import 'local_note_catalog_repository.dart';

const _catalogName = 'Hmm.AutomobileMan.ServiceRecord';
const _catalogSchema = '{}';

/// Drift-backed mirror of [_ServiceRecordApiRepository]. One HmmNote per
/// service event, parented to the automobile.
class LocalServiceRecordRepository implements IServiceRecordRepository {
  LocalServiceRecordRepository(this._noteRepo, this._catalogRepo);

  final IHmmNoteRepository _noteRepo;
  final INoteCatalogRepository _catalogRepo;

  @override
  Future<List<ServiceRecord>> getRecords(int autoId) async {
    final catalog =
        await _catalogRepo.getOrCreateCatalog(_catalogName, _catalogSchema);
    final result = await _noteRepo.getNotes(
      catalogId: catalog.id,
      parentNoteId: autoId,
      pageSize: 1000,
    );
    return result.items
        .map(_deserialize)
        .whereType<ServiceRecord>()
        .toList();
  }

  @override
  Future<ServiceRecord> getRecordById(int autoId, int id) async {
    final note = await _noteRepo.getNoteById(id);
    if (note == null) throw Exception('Service record $id not found');
    final r = _deserialize(note);
    if (r == null) throw Exception('Service record $id has invalid content');
    return r;
  }

  @override
  Future<ServiceRecord> createRecord(int autoId, ServiceRecord r) async {
    final catalog =
        await _catalogRepo.getOrCreateCatalog(_catalogName, _catalogSchema);
    final stamped = ServiceRecord(
      id: 0,
      automobileId: autoId,
      date: r.date,
      mileage: r.mileage,
      type: r.type,
      description: r.description,
      cost: r.cost,
      currency: r.currency,
      shopName: r.shopName,
      parts: r.parts,
      tax: r.tax,
      notes: r.notes,
      createdDate: DateTime.now(),
      attachments: r.attachments,
    );
    final note = await _noteRepo.createNote(HmmNoteCreate(
      subject: _subjectFor(stamped),
      content: _serialize(stamped),
      catalogId: catalog.id,
      parentNoteId: autoId,
      // Attachments are read-through on the ServiceRecord entity but live on
      // the note's own column — pass the projected payload through.
      attachments: _attachmentsFor(r),
    ));
    return _deserialize(note)!;
  }

  @override
  Future<void> updateRecord(int autoId, int id, ServiceRecord r) async {
    final updated = ServiceRecord(
      id: id,
      automobileId: autoId,
      date: r.date,
      mileage: r.mileage,
      type: r.type,
      description: r.description,
      cost: r.cost,
      currency: r.currency,
      shopName: r.shopName,
      parts: r.parts,
      tax: r.tax,
      notes: r.notes,
      createdDate: r.createdDate,
      attachments: r.attachments,
    );
    await _noteRepo.updateNote(
      id,
      HmmNoteUpdate(
        subject: _subjectFor(updated),
        content: _serialize(updated),
        // Pass the full attachment state every time: an empty set clears the
        // column (SQL NULL). Callers (the form) must round-trip the loaded
        // record's attachments so an edit never silently wipes them.
        attachments: _attachmentsFor(r),
      ),
    );
  }

  @override
  Future<void> deleteRecord(int autoId, int id) async {
    await _noteRepo.deleteNote(id);
  }

  NoteAttachments _attachmentsFor(ServiceRecord r) =>
      r.attachments.isEmpty ? NoteAttachments.empty : r.attachments;

  String _subjectFor(ServiceRecord r) {
    final d = r.date.toIso8601String().substring(0, 10);
    return '${r.type.displayName} • $d • ${r.mileage} mi';
  }

  String _serialize(ServiceRecord r) {
    final data = <String, dynamic>{
      'automobileId': r.automobileId,
      'date': r.date.toUtc().toIso8601String(),
      'mileage': r.mileage,
      'type': r.type.wireValue,
      if (r.description != null) 'description': r.description,
      if (r.cost != null)
        'cost': {'amount': r.cost, 'currency': r.currency},
      if (r.tax != null) 'tax': {'amount': r.tax, 'currency': r.currency},
      if (r.shopName != null) 'shopName': r.shopName,
      'parts': r.parts
          .map((p) => {
                'type': p.type.wireName,
                'name': p.name,
                'quantity': p.quantity,
                if (p.unitCost != null)
                  'unitCost': {'amount': p.unitCost, 'currency': p.currency},
              })
          .toList(),
      if (r.notes != null) 'notes': r.notes,
      if (r.createdDate != null)
        'createdDate': r.createdDate!.toUtc().toIso8601String(),
      '_v': 1,
    };
    return jsonEncode({
      'note': {
        'content': {'ServiceRecord': data}
      }
    });
  }

  ServiceRecord? _deserialize(HmmNote note) {
    if (note.content == null) return null;
    try {
      final json = jsonDecode(note.content!) as Map<String, dynamic>;
      final body = json['note']?['content']?['ServiceRecord']
          as Map<String, dynamic>?;
      if (body == null) return null;

      final cost = body['cost'] as Map<String, dynamic>?;
      final tax = body['tax'] as Map<String, dynamic>?;
      final partsJson = body['parts'] as List<dynamic>? ?? const [];

      return ServiceRecord(
        id: note.id,
        automobileId:
            body['automobileId'] as int? ?? note.parentNoteId ?? 0,
        date: DateTime.parse(body['date'] as String),
        mileage: body['mileage'] as int? ?? 0,
        type: ServiceType.fromWire(body['type'] as String?),
        description: body['description'] as String?,
        cost: (cost?['amount'] as num?)?.toDouble(),
        currency: cost?['currency'] as String? ?? 'CAD',
        shopName: body['shopName'] as String?,
        parts: partsJson.map((p) {
          final m = p as Map<String, dynamic>;
          final unit = m['unitCost'] as Map<String, dynamic>?;
          return PartItem(
            type: LineItemType.fromWire(m['type'] as String?),
            name: m['name'] as String? ?? '',
            quantity: m['quantity'] as int? ?? 1,
            unitCost: (unit?['amount'] as num?)?.toDouble(),
            currency: unit?['currency'] as String? ?? 'CAD',
          );
        }).toList(),
        tax: (tax?['amount'] as num?)?.toDouble(),
        notes: body['notes'] as String?,
        createdDate: note.createDate,
        // Read-through projection: attachments live on the owning note's
        // column, not inside the serialized content.
        attachments: note.effectiveAttachments,
      );
    } catch (_) {
      return null;
    }
  }
}

final localServiceRecordRepositoryProvider =
    Provider<IServiceRecordRepository>(
  (ref) => LocalServiceRecordRepository(
    ref.watch(localHmmNoteRepositoryProvider),
    ref.watch(localNoteCatalogRepositoryProvider),
  ),
);
