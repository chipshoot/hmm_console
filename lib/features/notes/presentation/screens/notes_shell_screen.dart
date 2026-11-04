import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../states/note_selection.dart';
import '../../states/notes_list_state.dart';
import '../widgets/notes_sidebar.dart';
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
        final docked = constraints.maxWidth >= kNotesSidebarBreakpoint;
        final data = docked ? ref.watch(notesListStateProvider).value : null;
        return Scaffold(
          body: Row(
            children: [
              if (docked) ...[
                SizedBox(
                  key: const ValueKey('notes-sidebar-pane'),
                  width: 240,
                  child: Material(
                    child: data == null
                        ? null
                        : SafeArea(
                            right: false,
                            child: NotesSidebar(data: data, onPicked: () {}),
                          ),
                  ),
                ),
                const VerticalDivider(width: 1),
              ],
              SizedBox(
                key: const ValueKey('notes-list-pane'),
                width: 360,
                child: NotesListScreen(sidebarDocked: docked),
              ),
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
