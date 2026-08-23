import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../states/note_selection.dart';
import 'note_detail_screen.dart';
import 'notes_list_screen.dart';

class NotesShellScreen extends ConsumerWidget {
  const NotesShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
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
                    ? Center(child: Text(l.notesSelectNote))
                    : NoteDetailScreen(noteId: selectedId),
              ),
            ],
          ),
        );
      },
    );
  }
}
