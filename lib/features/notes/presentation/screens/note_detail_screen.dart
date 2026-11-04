import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/inline_ref_uri.dart';
import '../../../../core/data/local/database.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/help/undoable_action.dart';
import '../../../../core/notes/editing/edit_dispatch.dart';
import '../../../../core/notes/note_state.dart';
import '../../../../core/settings/settings_controller.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/models/hmm_note.dart';
import '../../rendering/note_display.dart';
import '../../rendering/render_registry.dart';
import '../../states/mutate_note_state.dart';
import '../../states/note_delete_policy.dart';
import '../../states/note_selection.dart';
import '../../states/recently_deleted_provider.dart';
import '../catalog_labels.dart';
import '../widgets/note_swipe_actions.dart' show deleteNoteWithUndo;
import '../widgets/markdown_view.dart';
import '../widgets/note_file_card_list.dart';
import '../widgets/note_flag_sheet.dart';
import '../widgets/note_location_card.dart';
import '../widgets/note_media_card_list.dart';

/// The note is gone (purged, or deleted for good from another device).
class NoteNotFound implements Exception {
  const NoteNotFound(this.id);
  final int id;

  @override
  String toString() => 'NoteNotFound';
}

class NoteDetailData {
  /// [state] (pin/flag, G14) defaults to "no row": unpinned, unflagged.
  NoteDetailData(this.note, this.catalog, [NoteState? state])
    : state = state ?? NoteState.none(note.uuid);
  final HmmNote note;
  final NoteCatalog? catalog;
  final NoteState state;
}

/// Pin + flag of one note, live: re-emits when sync (or this device) writes
/// the note's NoteStates row.
final noteStateProvider = StreamProvider.autoDispose.family<NoteState, String>((
  ref,
  uuid,
) {
  return ref.watch(noteStateRepositoryProvider).watchState(uuid);
});

/// autoDispose: nothing else refreshes this after a sync, so a kept-alive
/// value would show a stale note for the rest of the session.
final noteDetailProvider = FutureProvider.autoDispose
    .family<NoteDetailData, int>((ref, id) async {
      // Re-read when this note enters or leaves Recently Deleted (a delete or
      // restore synced from another device); select keeps other notes' deletes
      // from reloading it.
      ref.watch(
        deletedNoteIdsProvider.select((a) => a.value?.contains(id) ?? false),
      );
      final note = await ref.watch(hmmNoteRepositoryProvider).getNoteById(id);
      if (note == null) throw NoteNotFound(id);
      NoteCatalog? catalog;
      final cid = note.catalogId;
      if (cid != null) {
        catalog = await ref
            .watch(noteCatalogRepositoryProvider)
            .getCatalogById(cid);
      }
      final state = await ref.watch(noteStateProvider(note.uuid).future);
      return NoteDetailData(note, catalog, state);
    });

enum _MenuAction { edit, raw, pin, flag, delete, manageIn, restore }

class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({super.key, required this.noteId});
  final int noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(noteDetailProvider(noteId));
    final registry = ref.watch(noteRenderRegistryProvider);
    final displayRegistry = ref.watch(noteDisplayRegistryProvider);
    final dispatch = ref.watch(editDispatchProvider);

    return AppScaffold(
      title: async.maybeWhen(
        data: (d) => catalogLabel(d.catalog?.name, l),
        orElse: () => 'Note',
      ),
      actions: [
        const HelpButton(helpId: HelpId.noteDetail),
        async.maybeWhen(
          data: (d) {
            final catalogName = d.catalog?.name;
            final canDelete = canDeleteFromNotes(d.note, catalogName);
            final place =
                managePlaceFor(catalogName) ?? NoteManagePlace.ownScreen;
            final deleted = d.note.isDeleted;
            return PopupMenuButton<_MenuAction>(
              onSelected: (a) async {
                switch (a) {
                  case _MenuAction.edit:
                    dispatch.edit(context, catalogName, d.note);
                  case _MenuAction.raw:
                    context.push('/notes/$noteId/raw');
                  case _MenuAction.pin:
                    await _togglePin(context, ref, l, d.state);
                  case _MenuAction.flag:
                    await _chooseFlag(context, ref, l, d.state);
                  case _MenuAction.delete:
                    await _delete(context, ref);
                  case _MenuAction.restore:
                    await _restore(context, ref, l);
                  case _MenuAction.manageIn:
                    break; // informational row: the item is disabled
                }
              },
              itemBuilder: (context) => deleted
                  // A deleted note can only be restored or inspected.
                  ? [
                      PopupMenuItem(
                        value: _MenuAction.restore,
                        child: _MenuRow(Icons.restore, l.notesRestoreAction),
                      ),
                      PopupMenuItem(
                        value: _MenuAction.raw,
                        child: _MenuRow(Icons.code, l.notesViewRaw),
                      ),
                    ]
                  : [
                      if (dispatch.canEdit(catalogName))
                        PopupMenuItem(
                          value: _MenuAction.edit,
                          child: _MenuRow(
                            Icons.edit_outlined,
                            l.notesEditAction,
                          ),
                        ),
                      PopupMenuItem(
                        value: _MenuAction.raw,
                        child: _MenuRow(Icons.code, l.notesViewRaw),
                      ),
                      PopupMenuItem(
                        value: _MenuAction.pin,
                        child: _MenuRow(
                          Icons.push_pin_outlined,
                          d.state.isPinned ? l.notesUnpin : l.notesPin,
                        ),
                      ),
                      PopupMenuItem(
                        value: _MenuAction.flag,
                        child: _MenuRow(Icons.flag_outlined, l.notesFlagAction),
                      ),
                      if (canDelete)
                        PopupMenuItem(
                          value: _MenuAction.delete,
                          child: _MenuRow(Icons.delete_outline, l.commonDelete),
                        )
                      else
                        // G7: entity notes are deleted from their own screen.
                        PopupMenuItem(
                          enabled: false,
                          value: _MenuAction.manageIn,
                          child: _MenuRow(
                            Icons.open_in_new,
                            l.notesManageIn(managePlaceLabel(place, l)),
                          ),
                        ),
                    ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) {
              if (e is NoteNotFound) {
                // Wide layout: the pane must not keep pointing at nothing.
                final container = ProviderScope.containerOf(context);
                if (container.read(selectedNoteIdProvider) == noteId) {
                  Future(
                    () => container
                        .read(selectedNoteIdProvider.notifier)
                        .select(null),
                  );
                }
                return Center(child: Text(l.notesDeletedForGood));
              }
              debugPrint('NoteDetailScreen: load failed (${e.runtimeType})');
              return Center(child: Text(l.notesLoadFailed));
            },
            data: (d) {
              final markdown = _safeRender(registry, d.catalog?.name, d.note);
              // Images referenced inline in the body render in place (via
              // MarkdownView); exclude them from the trailing cards so they
              // aren't shown twice.
              final inlinePaths = imageRefPathsIn(markdown).toSet();
              bool notInline(AttachmentRef r) =>
                  r is! VaultRef || !inlinePaths.contains(r.path);
              final atts = <AttachmentRef>[
                if (d.note.effectiveAttachments.primaryImage != null &&
                    notInline(d.note.effectiveAttachments.primaryImage!))
                  d.note.effectiveAttachments.primaryImage!,
                ...d.note.effectiveAttachments.images.where(notInline),
              ];
              final flag = d.state.flag;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (d.note.isDeleted)
                    _DeletedBanner(onRestore: () => _restore(context, ref, l)),
                  Row(
                    children: [
                      if (d.state.isPinned && !d.note.isDeleted)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.push_pin,
                            size: 18,
                            semanticLabel: l.notesPinnedLabel,
                          ),
                        ),
                      if (flag != null && !d.note.isDeleted)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.flag,
                            size: 18,
                            color: flag.color,
                            semanticLabel: l.notesFlaggedLabel(
                              noteFlagColorLabel(flag, l),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          displayRegistry.title(d.note, d.catalog?.name, l),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (atts.isNotEmpty)
                    NoteMediaCardList(saved: atts, readOnly: true),
                  if (d.note.effectiveAttachments.files.isNotEmpty)
                    NoteFileCardList(
                      saved: d.note.effectiveAttachments.files,
                      readOnly: true,
                    ),
                  if (d.note.location != null)
                    NoteLocationCard(
                      location: d.note.location!,
                      readOnly: true,
                    ),
                  const SizedBox(height: 12),
                  MarkdownView(markdown),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Delete = move to Recently Deleted, with Undo (restore); the undoable
  /// part is shared with the list ([deleteNoteWithUndo], which also clears the
  /// wide-screen selection). Narrow screens pop back to the list afterwards.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final isWide = MediaQuery.of(context).size.width >= kNotesWideBreakpoint;
    final moved = await deleteNoteWithUndo(context, ref, noteId);
    if (moved && !isWide) unawaited(navigator.maybePop());
  }

  /// Restore with Undo (moves it back to Recently Deleted). The container is
  /// captured before any await so the reload needs no WidgetRef.
  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) {
    final mutate = ref.read(mutateNoteProvider);
    final container = ProviderScope.containerOf(context);
    final id = noteId;
    return showUndoableAction(
      context,
      busyKey: ('restoreNote', id),
      run: () async {
        await mutate.restore(id);
        container.invalidate(noteDetailProvider(id));
      },
      undo: () async {
        await mutate.delete(id);
        container.invalidate(noteDetailProvider(id));
      },
      done: l.notesRestored,
      failed: l.notesRestoreFailed,
      undone: l.notesMovedToRecentlyDeleted,
      undoFailed: l.notesDeleteFailed,
    );
  }

  Future<void> _togglePin(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    NoteState state,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final mutate = ref.read(mutateNoteProvider);
    final container = ProviderScope.containerOf(context);
    try {
      await mutate.setPinned(noteId, !state.isPinned);
      container.invalidate(noteDetailProvider(noteId));
    } catch (e) {
      debugPrint('NoteDetailScreen: pin failed (${e.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.notesPinFailed)));
    }
  }

  Future<void> _chooseFlag(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    NoteState state,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final mutate = ref.read(mutateNoteProvider);
    final settings = ref.read(settingsProvider.notifier);
    final container = ProviderScope.containerOf(context);
    final choice = await showNoteFlagSheet(context, current: state.flag);
    if (choice == null) return; // dismissed: change nothing
    try {
      await mutate.setFlagColor(noteId, choice.color?.stored);
      container.invalidate(noteDetailProvider(noteId));
    } catch (e) {
      debugPrint('NoteDetailScreen: flag failed (${e.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.notesFlagFailed)));
      return;
    }
    // Clearing a flag leaves the remembered colour alone; the flag is applied
    // by now, so a failure here is logged, not shown.
    if (choice.color != null) {
      try {
        await settings.setNotesLastFlagColor(choice.color!.stored);
      } catch (e) {
        debugPrint('NoteDetailScreen: last colour failed (${e.runtimeType})');
      }
    }
  }

  /// Renderers must not throw, but isolate anyway: fall back to a banner +
  /// generic view rather than crashing the read screen.
  String _safeRender(
    NoteRenderRegistry registry,
    String? catalogName,
    HmmNote note,
  ) {
    try {
      return registry.rendererFor(catalogName).render(note);
    } catch (_) {
      return '> ⚠️ Couldn\'t render this note\'s format. Use **View raw content** to inspect it.';
    }
  }
}

/// Shown above the title of a soft-deleted note: Material banner on Android,
/// a tinted row on Apple platforms.
class _DeletedBanner extends StatelessWidget {
  const _DeletedBanner({required this.onRestore});
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final text = l.notesMovedToRecentlyDeletedBanner;
    if (!isApple) {
      return MaterialBanner(
        content: Text(text),
        actions: [
          TextButton(onPressed: onRestore, child: Text(l.notesRestoreAction)),
        ],
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          CupertinoButton(
            onPressed: onRestore,
            child: Text(l.notesRestoreAction),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 12),
      Flexible(child: Text(label)),
    ],
  );
}
