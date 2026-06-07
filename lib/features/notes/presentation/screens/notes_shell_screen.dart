import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'note_detail_screen.dart';
import 'notes_list_screen.dart';

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

class NotesShellScreen extends ConsumerWidget {
  const NotesShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kNotesWideBreakpoint;
        if (!isWide) return const NotesListScreen();

        final selectedId = ref.watch(selectedNoteIdProvider);
        return Scaffold(
          body: Row(
            children: [
              const SizedBox(width: 360, child: NotesListScreen()),
              const VerticalDivider(width: 1),
              Expanded(
                child: selectedId == null
                    ? const Center(child: Text('Select a note'))
                    : NoteDetailScreen(noteId: selectedId),
              ),
            ],
          ),
        );
      },
    );
  }
}
