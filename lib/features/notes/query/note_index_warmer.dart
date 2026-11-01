import 'package:flutter/foundation.dart';

import '../data/models/hmm_note.dart';
import 'note_text_index.dart';

/// Fills a [NoteTextIndexCache] in the background, a chunk per event-loop
/// turn, so a big library never blocks a frame.
class NoteIndexWarmer {
  NoteIndexWarmer({
    required NoteTextIndexCache cache,
    required NoteTextKey Function(HmmNote) keyOf,
    required NoteTextIndex Function(HmmNote) build,
    int chunkSize = 200,
    void Function()? onChunk,
  }) : _cache = cache,
       _keyOf = keyOf,
       _build = build,
       _chunkSize = chunkSize,
       _onChunk = onChunk;

  final NoteTextIndexCache _cache;
  final NoteTextKey Function(HmmNote) _keyOf;
  final NoteTextIndex Function(HmmNote) _build;
  final int _chunkSize;
  final void Function()? _onChunk;
  int _generation = 0;

  /// Drops entries for notes no longer live, then indexes the missing or
  /// stale ones. A newer [warm] (or [cancel]) stops this one.
  Future<void> warm(List<HmmNote> notes) async {
    final generation = ++_generation;
    _cache.retainOnly({for (final n in notes) n.id});
    final todo = <(HmmNote, NoteTextKey)>[];
    for (final n in notes) {
      final key = _keyOf(n);
      if (_cache.lookup(key) == null) todo.add((n, key));
    }
    var logged = false;
    for (var i = 0; i < todo.length; i += _chunkSize) {
      await Future<void>.delayed(Duration.zero);
      if (generation != _generation) return;
      final end = i + _chunkSize < todo.length ? i + _chunkSize : todo.length;
      for (final (n, key) in todo.sublist(i, end)) {
        try {
          _cache.store(key, _build(n));
        } catch (e) {
          if (!logged) {
            logged = true;
            debugPrint('NoteIndexWarmer: index failed (${e.runtimeType})');
          }
        }
      }
      _onChunk?.call();
    }
  }

  void cancel() => _generation++;
}
