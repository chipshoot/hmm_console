import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimum width (logical px) at which the notes UI uses a two-pane layout.
const double kNotesWideBreakpoint = 720;

/// Selected note id for the wide-screen detail pane (null = nothing selected).
class _SelectedNoteNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedNoteIdProvider = NotifierProvider<_SelectedNoteNotifier, int?>(
  _SelectedNoteNotifier.new,
);
