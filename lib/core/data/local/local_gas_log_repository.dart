import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/gas_log/data/repositories/i_gas_log_repository.dart';
import '../../../features/gas_log/domain/entities/discount_info.dart';
import '../../../features/gas_log/domain/entities/gas_log.dart';
import '../../network/pagination.dart';
import 'database.dart';
import 'local_author_repository.dart';
import 'local_note_catalog_repository.dart';
import 'local_note_repository.dart';

const _gasLogCatalogName = 'Hmm.AutomobileMan.GasLog';
const _gasLogCatalogSchema = '{}';

class LocalGasLogRepository implements IGasLogRepository {
  LocalGasLogRepository(this._noteRepo, this._catalogRepo, this._authorRepo);

  final INoteRepository _noteRepo;
  final INoteCatalogRepository _catalogRepo;
  final IAuthorRepository _authorRepo;

  @override
  Future<PaginatedResponse<GasLog>> getGasLogs(
    int autoId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final catalog = await _catalogRepo.getOrCreateCatalog(
      _gasLogCatalogName,
      _gasLogCatalogSchema,
    );
    final result = await _noteRepo.getNotes(
      catalogId: catalog.id,
      parentNoteId: autoId,
      page: page,
      pageSize: pageSize,
    );

    final gasLogs = result.items
        .map((note) => _deserializeGasLog(note))
        .whereType<GasLog>()
        .toList();

    return PaginatedResponse(items: gasLogs, meta: result.meta);
  }

  @override
  Future<GasLog> getGasLogById(int autoId, int id) async {
    final note = await _noteRepo.getNoteById(id);
    if (note == null) throw Exception('Gas log $id not found');
    return _deserializeGasLog(note)!;
  }

  @override
  Future<GasLog> createGasLog(int autoId, GasLog gasLog) async {
    final catalog = await _catalogRepo.getOrCreateCatalog(
      _gasLogCatalogName,
      _gasLogCatalogSchema,
    );
    final authors = await _authorRepo.getAuthors();
    if (authors.isEmpty) throw Exception('No author found');
    final author = authors.first;

    final content = _serializeGasLog(gasLog);
    final note = await _noteRepo.createNote(NotesCompanion.insert(
      subject: _subjectFor(gasLog),
      content: Value(content),
      authorId: author.id,
      catalogId: Value(catalog.id),
      parentNoteId: Value(gasLog.automobileId),
    ));

    return _deserializeGasLog(note)!;
  }

  String _subjectFor(GasLog log) {
    final date = log.date.toIso8601String().substring(0, 10);
    final where = (log.stationName != null && log.stationName!.isNotEmpty)
        ? ' @ ${log.stationName}'
        : '';
    return 'Fill-up $date$where';
  }

  @override
  Future<GasLog> createHistoryGasLog(int autoId, GasLog gasLog) async {
    return createGasLog(autoId, gasLog);
  }

  @override
  Future<GasLog> updateGasLog(int autoId, int id, GasLog gasLog) async {
    final content = _serializeGasLog(gasLog);
    final note = await _noteRepo.updateNote(
      id,
      NotesCompanion(content: Value(content)),
    );
    return _deserializeGasLog(note)!;
  }

  @override
  Future<void> deleteGasLog(int autoId, int id) async {
    await _noteRepo.deleteNote(id);
  }

  String _serializeGasLog(GasLog log) {
    final gasLogData = <String, dynamic>{
      'date': log.date.toIso8601String(),
      'automobileId': log.automobileId,
      'odometer': {'value': log.odometer, 'unit': log.odometerUnit},
      'distance': {'value': log.distance, 'unit': log.distanceUnit},
      'gas': {'value': log.fuel, 'unit': log.fuelUnit},
      'fuelGrade': log.fuelGrade,
      'isFullTank': log.isFullTank,
      'isFirstFillUp': log.isFirstFillUp,
      'price': {'amount': log.totalPrice, 'currency': log.currency},
      'unitPrice': {'amount': log.unitPrice, 'currency': log.currency},
      'station': {
        if (log.stationId != null) 'id': log.stationId,
        'name': log.stationName ?? '',
      },
      if (log.location != null) 'location': log.location,
      if (log.cityDrivingPercentage != null) 'cityDrivingPercentage': log.cityDrivingPercentage,
      if (log.highwayDrivingPercentage != null) 'highwayDrivingPercentage': log.highwayDrivingPercentage,
      if (log.receiptNumber != null) 'receiptNumber': log.receiptNumber,
      if (log.comment != null) 'comment': log.comment,
      if (log.discounts.isNotEmpty)
        'discounts': log.discounts
            .map((d) => {'programId': d.discountId, 'amount': {'amount': d.amount, 'currency': log.currency}})
            .toList(),
      '_v': 1,
    };

    return jsonEncode({'note': {'content': {'GasLog': gasLogData}}});
  }

  GasLog? _deserializeGasLog(Note note) {
    if (note.content == null) return null;
    try {
      final json = jsonDecode(note.content!) as Map<String, dynamic>;
      final gasLogJson = json['note']?['content']?['GasLog'] as Map<String, dynamic>?;
      if (gasLogJson == null) return null;

      final odometer = gasLogJson['odometer'] as Map<String, dynamic>?;
      final distance = gasLogJson['distance'] as Map<String, dynamic>?;
      final gas = gasLogJson['gas'] as Map<String, dynamic>?;
      final price = gasLogJson['price'] as Map<String, dynamic>?;
      final unitPrice = gasLogJson['unitPrice'] as Map<String, dynamic>?;
      final station = gasLogJson['station'] as Map<String, dynamic>?;
      final discountsJson = gasLogJson['discounts'] as List<dynamic>? ?? [];

      final odometerVal = (odometer?['value'] as num?)?.toDouble() ?? 0;
      final distanceVal = (distance?['value'] as num?)?.toDouble() ?? 0;
      final fuelVal = (gas?['value'] as num?)?.toDouble() ?? 0;

      return GasLog(
        id: note.id,
        date: DateTime.parse(gasLogJson['date'] as String),
        automobileId: gasLogJson['automobileId'] as int,
        odometer: odometerVal,
        odometerUnit: odometer?['unit'] as String? ?? 'Mile',
        distance: distanceVal,
        distanceUnit: distance?['unit'] as String? ?? 'Mile',
        fuel: fuelVal,
        fuelUnit: gas?['unit'] as String? ?? 'Gallon',
        fuelGrade: gasLogJson['fuelGrade'] as String? ?? '',
        isFullTank: gasLogJson['isFullTank'] as bool? ?? true,
        isFirstFillUp: gasLogJson['isFirstFillUp'] as bool? ?? false,
        totalPrice: (price?['amount'] as num?)?.toDouble() ?? 0,
        unitPrice: (unitPrice?['amount'] as num?)?.toDouble() ?? 0,
        currency: price?['currency'] as String? ?? 'CAD',
        discounts: discountsJson.map((d) {
          final disc = d as Map<String, dynamic>;
          final amt = disc['amount'] as Map<String, dynamic>?;
          return DiscountInfo(
            discountId: disc['programId'] as int,
            amount: (amt?['amount'] as num?)?.toDouble() ?? 0,
          );
        }).toList(),
        stationId: station?['id'] as int?,
        stationName: station?['name'] as String?,
        location: gasLogJson['location'] as String?,
        cityDrivingPercentage: gasLogJson['cityDrivingPercentage'] as int?,
        highwayDrivingPercentage: gasLogJson['highwayDrivingPercentage'] as int?,
        receiptNumber: gasLogJson['receiptNumber'] as String?,
        fuelEfficiency: distanceVal > 0 && fuelVal > 0 ? distanceVal / fuelVal : 0,
        createDate: note.createDate,
        lastModifiedDate: note.lastModifiedDate,
        comment: gasLogJson['comment'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

final localGasLogRepositoryProvider = Provider<IGasLogRepository>((ref) {
  return LocalGasLogRepository(
    ref.watch(localNoteRepositoryProvider),
    ref.watch(localNoteCatalogRepositoryProvider),
    ref.watch(localAuthorRepositoryProvider),
  );
});
