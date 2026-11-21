import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/dated_note.dart';

/// Every subsystem that supplies dates to the linked-dates matcher. Empty
/// until each subsystem adds its source.
final datedNoteSourcesProvider = Provider<List<DatedNoteSource>>((ref) => []);
