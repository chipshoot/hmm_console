import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Multi-select mode of the Notes list: whether it is on, and which notes
/// (by local id) are ticked.
class NotesMultiSelect {
  const NotesMultiSelect({this.active = false, this.ids = const {}});

  final bool active;
  final Set<int> ids;
}

class NotesMultiSelectNotifier extends Notifier<NotesMultiSelect> {
  @override
  NotesMultiSelect build() => const NotesMultiSelect();

  /// Turn the mode on, optionally with [firstId] already ticked.
  void enter([int? firstId]) => state = NotesMultiSelect(
    active: true,
    ids: firstId == null ? const {} : {firstId},
  );

  /// Turn the mode off and forget the ticks.
  void exit() => state = const NotesMultiSelect();

  void toggle(int id) {
    final next = {...state.ids};
    if (!next.remove(id)) next.add(id);
    state = NotesMultiSelect(active: state.active, ids: next);
  }

  /// Tick every id in [ids], keeping the ones already ticked.
  void selectAll(Iterable<int> ids) => state = NotesMultiSelect(
    active: state.active,
    ids: {...state.ids, ...ids},
  );

  /// Drop ticks that are not in [ids] (e.g. notes a filter just hid).
  void keepOnly(Iterable<int> ids) {
    final keep = ids.toSet();
    state = NotesMultiSelect(
      active: state.active,
      ids: {
        for (final id in state.ids)
          if (keep.contains(id)) id,
      },
    );
  }
}

final notesMultiSelectProvider =
    NotifierProvider<NotesMultiSelectNotifier, NotesMultiSelect>(
      NotesMultiSelectNotifier.new,
    );
