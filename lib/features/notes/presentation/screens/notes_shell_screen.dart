import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/settings_controller.dart';
import '../../states/note_selection.dart';
import '../../states/notes_list_state.dart';
import '../widgets/notes_sidebar.dart';
import 'note_detail_screen.dart';
import 'notes_list_screen.dart';

/// Wide layouts: the open note fills the screen (side panel and list
/// hidden). Session-only: auto-disposed, so Notes always reopens with the
/// list showing.
final notesDetailExpandedProvider =
    NotifierProvider.autoDispose<NotesDetailExpanded, bool>(
      NotesDetailExpanded.new,
    );

class NotesDetailExpanded extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

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
        // With no note open there is nothing to fill the screen with.
        final expanded =
            selectedId != null && ref.watch(notesDetailExpandedProvider);
        final dockable = constraints.maxWidth >= kNotesSidebarBreakpoint;
        final hidden = dockable && ref.watch(notesSidebarHiddenProvider);
        final docked = dockable && !hidden && !expanded;
        final data = docked ? ref.watch(notesListStateProvider).value : null;
        return Scaffold(
          body: Row(
            children: [
              if (dockable)
                // Slides the panel in and out; when hidden it is gone, not
                // just zero-width.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => SizeTransition(
                    sizeFactor: animation,
                    axis: Axis.horizontal,
                    axisAlignment: -1,
                    child: child,
                  ),
                  child: docked
                      ? Row(
                          key: const ValueKey('notes-sidebar-shown'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              key: const ValueKey('notes-sidebar-pane'),
                              width: 240,
                              child: Material(
                                child: data == null
                                    ? null
                                    : SafeArea(
                                        right: false,
                                        child: NotesSidebar(
                                          data: data,
                                          onPicked: () {},
                                        ),
                                      ),
                              ),
                            ),
                            const VerticalDivider(width: 1),
                          ],
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('notes-sidebar-hidden'),
                        ),
                ),
              // Offstage, not removed: the list keeps its scroll and search
              // while the note is full screen.
              Offstage(
                offstage: expanded,
                child: SizedBox(
                  key: const ValueKey('notes-list-pane'),
                  width: 360,
                  child: NotesListScreen(
                    sidebarDocked: docked,
                    onToggleSidebar: dockable
                        ? () => ref
                              .read(settingsProvider.notifier)
                              .setNotesSidebarHidden(!hidden)
                        : null,
                  ),
                ),
              ),
              if (!expanded) const VerticalDivider(width: 1),
              Expanded(
                child: selectedId == null
                    ? Center(child: Text(l.notesSelectNote))
                    : NoteDetailScreen(
                        noteId: selectedId,
                        expanded: expanded,
                        onToggleExpanded: () => ref
                            .read(notesDetailExpandedProvider.notifier)
                            .toggle(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
