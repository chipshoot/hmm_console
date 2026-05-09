import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/automobile_records/data/repositories/insurance_repository.dart';
import '../../../features/automobile_records/domain/entities/auto_insurance_policy.dart';
import '../../../features/automobile_records/domain/entities/coverage_item.dart';
import '../../../features/notes/data/models/hmm_note.dart';
import '../hmm_note_input.dart';
import 'local_hmm_note_repository.dart';
import 'local_note_catalog_repository.dart';

const _catalogName = 'Hmm.AutomobileMan.AutoInsurancePolicy';
const _catalogSchema = '{}';

/// Drift-backed mirror of [_InsuranceApiRepository]. Each policy is one
/// HmmNote with `parentNoteId = automobileId`, JSON content shaped to
/// match the .NET `AutoInsurancePolicyJsonNoteSerialize` envelope so a
/// future sync layer can hand-off without conversion.
class LocalInsuranceRepository implements IInsuranceRepository {
  LocalInsuranceRepository(this._noteRepo, this._catalogRepo);

  final IHmmNoteRepository _noteRepo;
  final INoteCatalogRepository _catalogRepo;

  @override
  Future<List<AutoInsurancePolicy>> getPolicies(int autoId) async {
    final catalog =
        await _catalogRepo.getOrCreateCatalog(_catalogName, _catalogSchema);
    final result = await _noteRepo.getNotes(
      catalogId: catalog.id,
      parentNoteId: autoId,
      pageSize: 1000,
    );
    return result.items
        .map(_deserialize)
        .whereType<AutoInsurancePolicy>()
        .toList();
  }

  @override
  Future<AutoInsurancePolicy?> getActivePolicy(int autoId) async {
    final policies = await getPolicies(autoId);
    final now = DateTime.now();
    final candidates = policies
        .where((p) =>
            p.isActive &&
            p.effectiveDate.isBefore(now.add(const Duration(milliseconds: 1))) &&
            p.expiryDate.isAfter(now))
        .toList()
      ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  Future<AutoInsurancePolicy> getPolicyById(int autoId, int id) async {
    final note = await _noteRepo.getNoteById(id);
    if (note == null) {
      throw Exception('Insurance policy $id not found');
    }
    final policy = _deserialize(note);
    if (policy == null) {
      throw Exception('Insurance policy $id has invalid content');
    }
    return policy;
  }

  @override
  Future<AutoInsurancePolicy> createPolicy(
      int autoId, AutoInsurancePolicy policy) async {
    final catalog =
        await _catalogRepo.getOrCreateCatalog(_catalogName, _catalogSchema);
    final stamped = AutoInsurancePolicy(
      id: 0,
      automobileId: autoId,
      provider: policy.provider,
      policyNumber: policy.policyNumber,
      effectiveDate: policy.effectiveDate,
      expiryDate: policy.expiryDate,
      premium: policy.premium,
      currency: policy.currency,
      deductible: policy.deductible,
      coverage: policy.coverage,
      notes: policy.notes,
      isActive: policy.isActive,
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
  Future<void> updatePolicy(
      int autoId, int id, AutoInsurancePolicy policy) async {
    final updated = AutoInsurancePolicy(
      id: id,
      automobileId: autoId,
      provider: policy.provider,
      policyNumber: policy.policyNumber,
      effectiveDate: policy.effectiveDate,
      expiryDate: policy.expiryDate,
      premium: policy.premium,
      currency: policy.currency,
      deductible: policy.deductible,
      coverage: policy.coverage,
      notes: policy.notes,
      isActive: policy.isActive,
      createdDate: policy.createdDate,
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
  Future<void> deletePolicy(int autoId, int id) async {
    await _noteRepo.deleteNote(id);
  }

  String _subjectFor(AutoInsurancePolicy p) {
    final exp =
        '${p.expiryDate.year}-${p.expiryDate.month.toString().padLeft(2, '0')}';
    return '${p.provider} • ${p.policyNumber} • exp $exp';
  }

  String _serialize(AutoInsurancePolicy p) {
    final data = <String, dynamic>{
      'automobileId': p.automobileId,
      'provider': p.provider,
      'policyNumber': p.policyNumber,
      'effectiveDate': p.effectiveDate.toUtc().toIso8601String(),
      'expiryDate': p.expiryDate.toUtc().toIso8601String(),
      'premium': {'amount': p.premium, 'currency': p.currency},
      if (p.deductible != null) 'deductible': p.deductible,
      'coverage': p.coverage
          .map((c) => {
                'type': c.type,
                'limit': c.limit,
                'deductible': c.deductible,
                'currency': c.currency,
              })
          .toList(),
      if (p.notes != null) 'notes': p.notes,
      'isActive': p.isActive,
      if (p.createdDate != null)
        'createdDate': p.createdDate!.toUtc().toIso8601String(),
      if (p.lastModifiedDate != null)
        'lastModifiedDate': p.lastModifiedDate!.toUtc().toIso8601String(),
      '_v': 1,
    };
    return jsonEncode({
      'note': {
        'content': {'AutoInsurancePolicy': data}
      }
    });
  }

  AutoInsurancePolicy? _deserialize(HmmNote note) {
    if (note.content == null) return null;
    try {
      final json = jsonDecode(note.content!) as Map<String, dynamic>;
      final body = json['note']?['content']?['AutoInsurancePolicy']
          as Map<String, dynamic>?;
      if (body == null) return null;

      final premium = body['premium'] as Map<String, dynamic>?;
      final coverageJson = body['coverage'] as List<dynamic>? ?? const [];

      return AutoInsurancePolicy(
        id: note.id,
        automobileId:
            body['automobileId'] as int? ?? note.parentNoteId ?? 0,
        provider: body['provider'] as String? ?? '',
        policyNumber: body['policyNumber'] as String? ?? '',
        effectiveDate: DateTime.parse(body['effectiveDate'] as String),
        expiryDate: DateTime.parse(body['expiryDate'] as String),
        premium: (premium?['amount'] as num?)?.toDouble() ?? 0,
        currency: premium?['currency'] as String? ?? 'CAD',
        deductible: (body['deductible'] as num?)?.toDouble(),
        coverage: coverageJson
            .map((c) {
              final m = c as Map<String, dynamic>;
              return CoverageItem(
                type: m['type'] as String? ?? '',
                limit: (m['limit'] as num?)?.toDouble() ?? 0,
                deductible: (m['deductible'] as num?)?.toDouble() ?? 0,
                currency: m['currency'] as String? ?? 'CAD',
              );
            })
            .toList(),
        notes: body['notes'] as String?,
        isActive: body['isActive'] as bool? ?? true,
        createdDate: note.createDate,
        lastModifiedDate: note.lastModifiedDate,
      );
    } catch (_) {
      return null;
    }
  }
}

final localInsuranceRepositoryProvider = Provider<IInsuranceRepository>(
  (ref) => LocalInsuranceRepository(
    ref.watch(localHmmNoteRepositoryProvider),
    ref.watch(localNoteCatalogRepositoryProvider),
  ),
);
