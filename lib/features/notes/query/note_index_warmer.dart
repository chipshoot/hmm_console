import 'package:flutter/foundation.dart';

import '../data/models/hmm_note.dart';
import 'note_text_index.dart';

/// Fills a [NoteTextIndexCache] in the background, in time-boxed slices of
/// at most [sliceBudget] each with a yield to the event loop between them,
/// so a big library does not hold up frames.
class NoteIndexWarmer {
  NoteIndexWarmer({
    required NoteTextIndexCache cache,
    required NoteTextKey Function(HmmNote) keyOf,
    required NoteTextIndex Function(HmmNote) build,
    Duration sliceBudget = const Duration(milliseconds: 8),
    Duration reportEvery = const Duration(milliseconds: 250),
    void Function()? onProgress,
  }) : _cache = cache,
       _keyOf = keyOf,
       _build = build,
       _sliceBudget = sliceBudget,
       _reportEvery = reportEvery,
       _onProgress = onProgress;

  final NoteTextIndexCache _cache;
  final NoteTextKey Function(HmmNote) _keyOf;
  final NoteTextIndex Function(HmmNote) _build;
  final Duration _sliceBudget;
  final Duration _reportEvery;

  /// Called after a slice that indexed something, at most once per
  /// [_reportEvery], and always after the last one that did.
  final void Function()? _onProgress;
  int _generation = 0;

  /// Drops entries for notes no longer live, then indexes the missing or
  /// stale ones. A newer [warm] (or [cancel]) stops this one.
  Future<void> warm(List<HmmNote> notes) async {
    final generation = ++_generation;
    _cache.retainOnly({for (final n in notes) n.id});
    var logged = false;
    var unreported = false;
    final sinceReport = Stopwatch()..start();
    final slice = Stopwatch();
    var i = 0;
    while (i < notes.length) {
      await Future<void>.delayed(Duration.zero);
      if (generation != _generation) return;
      slice
        ..reset()
        ..start();
      do {
        final n = notes[i++];
        final key = _keyOf(n);
        if (_cache.lookup(key) != null) continue;
        try {
          _cache.store(key, _build(n));
          unreported = true;
        } catch (e) {
          if (!logged) {
            logged = true;
            debugPrint('NoteIndexWarmer: index failed (${e.runtimeType})');
          }
        }
      } while (i < notes.length && slice.elapsed < _sliceBudget);
      if (unreported &&
          (i == notes.length || sinceReport.elapsed >= _reportEvery)) {
        unreported = false;
        sinceReport.reset();
        _onProgress?.call();
      }
    }
  }

  void cancel() => _generation++;
}
