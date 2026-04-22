import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/gas_log/data/repositories/automobile_repository.dart';
import '../../../features/gas_log/domain/entities/automobile.dart';
import 'database.dart';
import 'local_author_repository.dart';
import 'local_note_catalog_repository.dart';
import 'local_note_repository.dart';

const _autoCatalogName = 'Hmm.AutomobileMan.AutomobileInfo';
const _autoCatalogSchema = '{}';

class LocalAutomobileRepository implements IAutomobileRepository {
  LocalAutomobileRepository(this._noteRepo, this._catalogRepo, this._authorRepo);

  final INoteRepository _noteRepo;
  final INoteCatalogRepository _catalogRepo;
  final IAuthorRepository _authorRepo;

  @override
  Future<List<Automobile>> getAutomobiles() async {
    final result = await _noteRepo.getNotesBySubjectPrefix(
      'AutomobileInfo',
      pageSize: 100,
    );
    return result.items
        .map(_deserialize)
        .whereType<Automobile>()
        .where((a) => a.isActive)
        .toList();
  }

  @override
  Future<Automobile> getAutomobileById(int id) async {
    final note = await _noteRepo.getNoteById(id);
    if (note == null) throw Exception('Automobile $id not found');
    return _deserialize(note)!;
  }

  @override
  Future<Automobile> createAutomobile(Automobile automobile) async {
    final catalog = await _catalogRepo.getOrCreateCatalog(
      _autoCatalogName,
      _autoCatalogSchema,
    );
    final authors = await _authorRepo.getAuthors();
    if (authors.isEmpty) throw Exception('No author found');

    final content = _serialize(automobile);
    final note = await _noteRepo.createNote(NotesCompanion.insert(
      subject: 'AutomobileInfo,Id:0',
      content: Value(content),
      authorId: authors.first.id,
      catalogId: Value(catalog.id),
    ));

    final created = _deserialize(note)!;
    await _noteRepo.updateNote(
      note.id,
      NotesCompanion(subject: Value('AutomobileInfo,Id:${note.id}')),
    );
    return created;
  }

  @override
  Future<void> updateAutomobile(int id, Automobile automobile) async {
    final content = _serialize(automobile);
    await _noteRepo.updateNote(id, NotesCompanion(content: Value(content)));
  }

  @override
  Future<void> deactivateAutomobile(int id) async {
    final current = await getAutomobileById(id);
    final deactivated = Automobile(
      id: current.id,
      vin: current.vin,
      maker: current.maker,
      brand: current.brand,
      model: current.model,
      trim: current.trim,
      year: current.year,
      color: current.color,
      plate: current.plate,
      engineType: current.engineType,
      fuelType: current.fuelType,
      fuelTankCapacity: current.fuelTankCapacity,
      cityMPG: current.cityMPG,
      highwayMPG: current.highwayMPG,
      combinedMPG: current.combinedMPG,
      meterReading: current.meterReading,
      purchaseMeterReading: current.purchaseMeterReading,
      purchaseDate: current.purchaseDate,
      purchasePrice: current.purchasePrice,
      ownershipStatus: current.ownershipStatus,
      isActive: false,
      soldDate: current.soldDate,
      soldMeterReading: current.soldMeterReading,
      soldPrice: current.soldPrice,
      registrationExpiryDate: current.registrationExpiryDate,
      insuranceExpiryDate: current.insuranceExpiryDate,
      insuranceProvider: current.insuranceProvider,
      insurancePolicyNumber: current.insurancePolicyNumber,
      lastServiceDate: current.lastServiceDate,
      lastServiceMeterReading: current.lastServiceMeterReading,
      nextServiceDueDate: current.nextServiceDueDate,
      nextServiceDueMeterReading: current.nextServiceDueMeterReading,
      notes: current.notes,
    );
    final content = _serialize(deactivated);
    await _noteRepo.updateNote(id, NotesCompanion(content: Value(content)));
  }

  String _serialize(Automobile auto) {
    final data = <String, dynamic>{
      'maker': auto.maker,
      'brand': auto.brand,
      'model': auto.model,
      'trim': auto.trim,
      'year': auto.year,
      'color': auto.color,
      'vin': auto.vin,
      'plate': auto.plate,
      'engineType': auto.engineType,
      'fuelType': auto.fuelType,
      'fuelTankCapacity': auto.fuelTankCapacity,
      'cityMPG': auto.cityMPG,
      'highwayMPG': auto.highwayMPG,
      'combinedMPG': auto.combinedMPG,
      'meterReading': auto.meterReading,
      'purchaseMeterReading': auto.purchaseMeterReading,
      'purchaseDate': auto.purchaseDate?.toIso8601String(),
      'purchasePrice': auto.purchasePrice,
      'ownershipStatus': auto.ownershipStatus,
      'isActive': auto.isActive,
      'soldDate': auto.soldDate?.toIso8601String(),
      'soldMeterReading': auto.soldMeterReading,
      'soldPrice': auto.soldPrice,
      'registrationExpiryDate': auto.registrationExpiryDate?.toIso8601String(),
      'insuranceExpiryDate': auto.insuranceExpiryDate?.toIso8601String(),
      'insuranceProvider': auto.insuranceProvider,
      'insurancePolicyNumber': auto.insurancePolicyNumber,
      'lastServiceDate': auto.lastServiceDate?.toIso8601String(),
      'lastServiceMeterReading': auto.lastServiceMeterReading,
      'nextServiceDueDate': auto.nextServiceDueDate?.toIso8601String(),
      'nextServiceDueMeterReading': auto.nextServiceDueMeterReading,
      'notes': auto.notes,
      '_v': 1,
    };
    return jsonEncode({'note': {'content': {'AutomobileInfo': data}}});
  }

  Automobile? _deserialize(Note note) {
    if (note.content == null) return null;
    try {
      final json = jsonDecode(note.content!) as Map<String, dynamic>;
      final d = json['note']?['content']?['AutomobileInfo'] as Map<String, dynamic>?;
      if (d == null) return null;

      return Automobile(
        id: note.id,
        vin: d['vin'] as String?,
        maker: d['maker'] as String?,
        brand: d['brand'] as String?,
        model: d['model'] as String?,
        trim: d['trim'] as String?,
        year: d['year'] as int? ?? 0,
        color: d['color'] as String?,
        plate: d['plate'] as String?,
        engineType: d['engineType'] as String?,
        fuelType: d['fuelType'] as String?,
        fuelTankCapacity: (d['fuelTankCapacity'] as num?)?.toDouble() ?? 0,
        cityMPG: (d['cityMPG'] as num?)?.toDouble() ?? 0,
        highwayMPG: (d['highwayMPG'] as num?)?.toDouble() ?? 0,
        combinedMPG: (d['combinedMPG'] as num?)?.toDouble() ?? 0,
        meterReading: d['meterReading'] as int? ?? 0,
        purchaseMeterReading: d['purchaseMeterReading'] as int?,
        purchaseDate: d['purchaseDate'] != null ? DateTime.tryParse(d['purchaseDate'] as String) : null,
        purchasePrice: (d['purchasePrice'] as num?)?.toDouble(),
        ownershipStatus: d['ownershipStatus'] as String?,
        isActive: d['isActive'] as bool? ?? true,
        soldDate: d['soldDate'] != null ? DateTime.tryParse(d['soldDate'] as String) : null,
        soldMeterReading: d['soldMeterReading'] as int?,
        soldPrice: (d['soldPrice'] as num?)?.toDouble(),
        registrationExpiryDate: d['registrationExpiryDate'] != null ? DateTime.tryParse(d['registrationExpiryDate'] as String) : null,
        insuranceExpiryDate: d['insuranceExpiryDate'] != null ? DateTime.tryParse(d['insuranceExpiryDate'] as String) : null,
        insuranceProvider: d['insuranceProvider'] as String?,
        insurancePolicyNumber: d['insurancePolicyNumber'] as String?,
        lastServiceDate: d['lastServiceDate'] != null ? DateTime.tryParse(d['lastServiceDate'] as String) : null,
        lastServiceMeterReading: d['lastServiceMeterReading'] as int?,
        nextServiceDueDate: d['nextServiceDueDate'] != null ? DateTime.tryParse(d['nextServiceDueDate'] as String) : null,
        nextServiceDueMeterReading: d['nextServiceDueMeterReading'] as int?,
        notes: d['notes'] as String?,
        createdDate: note.createDate,
        lastModifiedDate: note.lastModifiedDate,
      );
    } catch (_) {
      return null;
    }
  }
}

final localAutomobileRepositoryProvider = Provider<IAutomobileRepository>((ref) {
  return LocalAutomobileRepository(
    ref.watch(localNoteRepositoryProvider),
    ref.watch(localNoteCatalogRepositoryProvider),
    ref.watch(localAuthorRepositoryProvider),
  );
});
