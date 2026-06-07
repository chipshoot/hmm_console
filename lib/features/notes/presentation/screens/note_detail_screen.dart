import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/local/database.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../core/notes/catalog_palette.dart';
import '../../../../core/notes/editing/edit_dispatch.dart';
import '../../data/models/hmm_note.dart';
import '../../rendering/render_registry.dart';
import '../../states/mutate_note_state.dart';
import '../widgets/attachment_gallery.dart';
import '../widgets/markdown_view.dart';

class NoteDetailData {
  const NoteDetailData(this.note, this.catalog);
  final HmmNote note;
  final NoteCatalog? catalog;
}

final noteDetailProvider =
    FutureProvider.family<NoteDetailData, int>((ref, id) async {
  final note = await ref.watch(hmmNoteRepositoryProvider).getNoteById(id);
  if (note == null) throw StateError('Note $id not found');
  NoteCatalog? catalog;
  final cid = note.catalogId;
  if (cid != null) {
    catalog = await ref.watch(noteCatalogRepositoryProvider).getCatalogById(cid);
  }
  return NoteDetailData(note, catalog);
});

enum _MenuAction { edit, raw, delete }

class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({super.key, required this.noteId});
  final int noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(noteDetailProvider(noteId));
    final registry = ref.watch(noteRenderRegistryProvider);
    final dispatch = ref.watch(editDispatchProvider);

    return Scaffold(
      appBar: AppBar(
        title: async.maybeWhen(
          data: (d) => Text(CatalogPalette.styleFor(d.catalog?.name).displayName),
          orElse: () => const Text('Note'),
        ),
        actions: [
          async.maybeWhen(
            data: (d) {
              final catalogName = d.catalog?.name;
              return PopupMenuButton<_MenuAction>(
                onSelected: (a) async {
                  switch (a) {
                    case _MenuAction.edit:
                      dispatch.edit(context, catalogName, d.note);
                    case _MenuAction.raw:
                      context.push('/notes/$noteId/raw');
                    case _MenuAction.delete:
                      await ref.read(mutateNoteProvider).delete(noteId);
                      if (context.mounted) context.pop();
                  }
                },
                itemBuilder: (context) => [
                  if (dispatch.canEdit(catalogName))
                    const PopupMenuItem(
                        value: _MenuAction.edit, child: Text('Edit')),
                  const PopupMenuItem(
                      value: _MenuAction.raw,
                      child: Text('View raw content')),
                  const PopupMenuItem(
                      value: _MenuAction.delete, child: Text('Delete')),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) {
          final markdown = _safeRender(registry, d.catalog?.name, d.note);
          final atts = <AttachmentRef>[
            if (d.note.effectiveAttachments.primaryImage != null)
              d.note.effectiveAttachments.primaryImage!,
            ...d.note.effectiveAttachments.images,
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(d.note.subject,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (atts.isNotEmpty) ...[
                AttachmentGallery(refs: atts),
                const SizedBox(height: 12),
              ],
              MarkdownView(markdown),
            ],
          );
        },
      ),
    );
  }

  /// Renderers must not throw, but isolate anyway: fall back to a banner +
  /// generic view rather than crashing the read screen.
  String _safeRender(
      NoteRenderRegistry registry, String? catalogName, HmmNote note) {
    try {
      return registry.rendererFor(catalogName).render(note);
    } catch (_) {
      return '> ⚠️ Couldn\'t render this note\'s format. Use **View raw content** to inspect it.';
    }
  }
}
