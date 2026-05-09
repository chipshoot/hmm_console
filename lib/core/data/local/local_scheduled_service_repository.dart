import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/automobile_records/data/repositories/scheduled_service_repository.dart';
import '../../../features/automobile_records/domain/entities/auto_scheduled_service.dart';
import '../../../features/automobile_records/domain/entities/service_type.dart';
import '../../../features/notes/data/models/hmm_note.dart';
import '../hmm_note_input.dart';
import 'local_hmm_note_repository.dart';
import 'local_note_catalog_repository.dart';

const _catalogName = 'Hmm.AutomobileMan.AutoScheduledService';
const _catalogSchema = '{}';

/// Drift-backed mirror of [_ScheduledServiceApiRepository].
class LocalScheduledServiceRepository implements IScheduledServiceRepository {
  LocalScheduledServiceRepository(this._noteRepo, this._catalogRepo);

  final IHmmNoteRepository _noteRepo;
  final INoteCatalogRepository _catalogRepo;

  @override
  Future<List<AutoScheduledService>> getSchedules(int autoId) async {
    final catalog =
        await _catalogRepo.getOrCreateCatalog(_catalogName, _catalogSchema);
    final result = await _noteRepo.getNotes(
      catalogId: catalog.id,
      parentNoteId: autoId,
      pageSize: 1000,
    );
    return result.items
        .map(_deserialize)
        .whereType<AutoScheduledService>()
        .toList();
  }

  @override
  Future<AutoScheduledService?> getSoonest(int autoId) async {
    final schedules = await getSchedules(autoId);
    final candidates = schedules
        .where((s) => s.isActive && s.nextDueDate != null)
        .toList()
      ..sort((a, b) => a.nextDueDate!.compareTo(b.nextDueDate!));
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  Future<AutoScheduledService> getScheduleById(int autoId, int id) async {
    final note = await _noteRepo.getNoteById(id);
    if (note == null) throw Exception('Scheduled service $id not found');
    final s = _deserialize(note);
    if (s == null) throw Exception('Scheduled service $id has invalid content');
    return s;
  }

  @override
  Future<AutoScheduledService> createSchedule(
      int autoId, AutoScheduledService s) async {
    final catalog =
        await _catalogRepo.getOrCreateCatalog(_catalogName, _catalogSchema);
    final stamped = AutoScheduledService(
      id: 0,
      automobileId: autoId,
      name: s.name,
      type: s.type,
      intervalDays: s.intervalDays,
      intervalMileage: s.intervalMileage,
      nextDueDate: s.nextDueDate,
      nextDueMileage: s.nextDueMileage,
      isActive: s.isActive,
      notes: s.notes,
      createdDate: DateTime.now(),
      lastModifiedDate: DateTime.now(),
    );
    final note = await _noteRepo.createNote(HmmNoteCreate(
      subject: _subjectFor(stamped),
      content: _serialize(stamped),
      catalogId: catalog.id,
      parentNoteId: autoId,
    ));
    return _deserialize(note)!;
  }

  @override
  Future<void> updateSchedule(
      int autoId, int id, AutoScheduledService s) async {
    final updated = AutoScheduledService(
      id: id,
      automobileId: autoId,
      name: s.name,
      type: s.type,
      intervalDays: s.intervalDays,
      intervalMileage: s.intervalMileage,
      nextDueDate: s.nextDueDate,
      nextDueMileage: s.nextDueMileage,
      isActive: s.isActive,
      notes: s.notes,
      createdDate: s.createdDate,
      lastModifiedDate: DateTime.now(),
    );
    await _noteRepo.updateNote(
      id,
      HmmNoteUpdate(
        subject: _subjectFor(updated),
        content: _serialize(updated),
      ),
    );
  }

  @override
  Future<void> deleteSchedule(int autoId, int id) async {
    await _noteRepo.deleteNote(id);
  }

  String _subjectFor(AutoScheduledService s) {
    final due = s.nextDueDate;
    final dueLabel = due != null
        ? ' • due ${due.toIso8601String().substring(0, 10)}'
        : '';
    return '${s.name}$dueLabel';
  }

  String _serialize(AutoScheduledService s) {
    final data = <String, dynamic>{
      'automobileId': s.automobileId,
      'name': s.name,
      'type': s.type.wireValue,
      if (s.intervalDays != null) 'intervalDays': s.intervalDays,
      if (s.intervalMileage != null) 'intervalMileage': s.intervalMileage,
      if (s.nextDueDate != null)
        'nextDueDate': s.nextDueDate!.toUtc().toIso8601String(),
      if (s.nextDueMileage != null) 'nextDueMileage': s.nextDueMileage,
      'isActive': s.isActive,
      if (s.notes != null) 'notes': s.notes,
      if (s.createdDate != null)
        'createdDate': s.createdDate!.toUtc().toIso8601String(),
      if (s.lastModifiedDate != null)
        'lastModifiedDate': s.lastModifiedDate!.toUtc().toIso8601String(),
      '_v': 1,
    };
    return jsonEncode({
      'note': {
        'content': {'AutoScheduledService': data}
      }
    });
  }

  AutoScheduledService? _deserialize(HmmNote note) {
    if (note.content == null) return null;
    try {
      final json = jsonDecode(note.content!) as Map<String, dynamic>;
      final body = json['note']?['content']?['AutoScheduledService']
          as Map<String, dynamic>?;
      if (body == null) return null;

      return AutoScheduledService(
        id: note.id,
        automobileId:
            body['automobileId'] as int? ?? note.parentNoteId ?? 0,
        name: body['name'] as String? ?? '',
        type: ServiceType.fromWire(body['type'] as String?),
        intervalDays: body['intervalDays'] as int?,
        intervalMileage: body['intervalMileage'] as int?,
        nextDueDate: body['nextDueDate'] != null
            ? DateTime.parse(body['nextDueDate'] as String)
            : null,
        nextDueMileage: body['nextDueMileage'] as int?,
        isActive: body['isActive'] as bool? ?? true,
        notes: body['notes'] as String?,
        createdDate: note.createDate,
        lastModifiedDate: note.lastModifiedDate,
      );
    } catch (_) {
      return null;
    }
  }
}

final localScheduledServiceRepositoryProvider =
    Provider<IScheduledServiceRepository>(
  (ref) => LocalScheduledServiceRepository(
    ref.watch(localHmmNoteRepositoryProvider),
    ref.watch(localNoteCatalogRepositoryProvider),
  ),
);
