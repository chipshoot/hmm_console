import 'dart:async';

import 'package:hmm_console/features/glucose/contract/i_glucose_repository.dart';
import 'package:hmm_console/features/glucose/domain/glucose_reading.dart';

/// In-memory repository for screen tests. `changes()` is broadcast and
/// never emits on subscribe. Deleted ids are remembered for
/// [existsIncludingDeleted].
class FakeGlucoseRepository implements IGlucoseRepository {
  FakeGlucoseRepository([Iterable<GlucoseReading> seed = const []]) {
    for (final r in seed) {
      _items[r.id] = r;
    }
  }

  final Map<String, GlucoseReading> _items = {};
  final Set<String> _deleted = {};
  final _changes = StreamController<void>.broadcast();

  @override
  Future<List<GlucoseReading>> readingsBetween(
    DateTime from,
    DateTime to,
  ) async {
    final f = from.toUtc();
    final t = to.toUtc();
    return [
      for (final r in _items.values)
        if (!r.takenAt.utc.isBefore(f) && r.takenAt.utc.isBefore(t)) r,
    ]..sort((x, y) => y.takenAt.utc.compareTo(x.takenAt.utc));
  }

  @override
  Future<GlucoseReading?> getReading(String id) async => _items[id];

  @override
  Future<bool> existsIncludingDeleted(String id) async =>
      _items.containsKey(id) || _deleted.contains(id);

  @override
  Future<GlucoseReading> saveReading(GlucoseReading r) async {
    final now = DateTime.now().toUtc();
    final saved = r.copyWith(
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch ~/ 1000 * 1000,
        isUtc: true,
      ),
    );
    _items[saved.id] = saved;
    _deleted.remove(saved.id);
    _changes.add(null);
    return saved;
  }

  @override
  Future<void> deleteReading(String id) async {
    if (_items.remove(id) != null) {
      _deleted.add(id);
      _changes.add(null);
    }
  }

  @override
  Stream<void> changes() => _changes.stream;
}
