import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/gas_log/data/repositories/gas_station_repository.dart';
import '../../../features/gas_log/domain/entities/gas_station.dart';
import '../note_input.dart';
import 'database.dart';
import 'local_note_catalog_repository.dart';
import 'local_note_repository.dart';

const _stationCatalogName = 'Hmm.AutomobileMan.GasStation';
const _stationCatalogSchema = '{}';

class LocalGasStationRepository implements IGasStationRepository {
  LocalGasStationRepository(this._noteRepo, this._catalogRepo);

  final INoteRepository _noteRepo;
  final INoteCatalogRepository _catalogRepo;

  @override
  Future<List<GasStation>> getGasStations() async {
    final catalog = await _catalogRepo.getOrCreateCatalog(
      _stationCatalogName,
      _stationCatalogSchema,
    );
    final result = await _noteRepo.getNotes(
      catalogId: catalog.id,
      pageSize: 200,
    );
    return result.items
        .map(_deserialize)
        .whereType<GasStation>()
        .where((s) => s.isActive)
        .toList();
  }

  @override
  Future<GasStation> createGasStation(GasStation station) async {
    final catalog = await _catalogRepo.getOrCreateCatalog(
      _stationCatalogName,
      _stationCatalogSchema,
    );
    final content = _serialize(station);
    final note = await _noteRepo.createNote(NoteCreate(
      subject: station.name.isNotEmpty ? station.name : 'Gas Station',
      content: content,
      catalogId: catalog.id,
    ));

    return _deserialize(note)!.copyWith(id: note.id);
  }

  @override
  Future<GasStation> updateGasStation(int id, GasStation station) async {
    final content = _serialize(station);
    final note = await _noteRepo.updateNote(id, NoteUpdate(content: content));
    return _deserialize(note)!;
  }

  @override
  Future<void> deleteGasStation(int id) async {
    await _noteRepo.deleteNote(id);
  }

  String _serialize(GasStation station) {
    final data = <String, dynamic>{
      'name': station.name,
      'address': station.address,
      'city': station.city,
      'state': station.state,
      'country': station.country,
      'zipCode': station.zipCode,
      'description': station.description,
      'latitude': station.latitude,
      'longitude': station.longitude,
      'isActive': station.isActive,
      '_v': 1,
    };
    return jsonEncode({'note': {'content': {'GasStation': data}}});
  }

  GasStation? _deserialize(Note note) {
    if (note.content == null) return null;
    try {
      final json = jsonDecode(note.content!) as Map<String, dynamic>;
      final d = json['note']?['content']?['GasStation'] as Map<String, dynamic>?;
      if (d == null) return null;

      return GasStation(
        id: note.id,
        name: d['name'] as String? ?? '',
        address: d['address'] as String?,
        city: d['city'] as String?,
        state: d['state'] as String?,
        country: d['country'] as String?,
        zipCode: d['zipCode'] as String?,
        description: d['description'] as String?,
        latitude: (d['latitude'] as num?)?.toDouble(),
        longitude: (d['longitude'] as num?)?.toDouble(),
        isActive: d['isActive'] as bool? ?? true,
      );
    } catch (_) {
      return null;
    }
  }
}

final localGasStationRepositoryProvider = Provider<IGasStationRepository>((ref) {
  return LocalGasStationRepository(
    ref.watch(localNoteRepositoryProvider),
    ref.watch(localNoteCatalogRepositoryProvider),
  );
});
