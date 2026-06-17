import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../core/widgets/app_grouped_card.dart';
import '../../../../core/widgets/app_list_row.dart' show kRowInsetNoLeading;
import '../../../../core/widgets/app_row_separator.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/subsystem_anchor.dart';
import '../../states/mutate_note_state.dart';
import '../screens/note_detail_screen.dart' show noteDetailProvider;

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.noteId, this.presetParentId});
  final int? noteId; // null = create
  final int? presetParentId; // preset attach target for a new note
  bool get isNew => noteId == null;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  int? _noteId; // becomes non-null once persisted
  int? _parentId;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _noteId = widget.noteId;
    _parentId = widget.presetParentId;
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (_loaded || widget.noteId == null) return;
    _loaded = true;
    final note =
        await ref.read(hmmNoteRepositoryProvider).getNoteById(widget.noteId!);
    if (note != null && mounted) {
      _subjectCtrl.text = note.subject;
      _bodyCtrl.text = note.content ?? '';
      setState(() {});
    }
  }

  /// Persists the note (create or update) and returns its id.
  Future<int?> _save() async {
    final subject = _subjectCtrl.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subject is required')));
      return null;
    }
    final mutate = ref.read(mutateNoteProvider);
    setState(() => _busy = true);
    try {
      if (_noteId == null) {
        final note = await mutate.createGeneral(
            subject: subject, markdownBody: _bodyCtrl.text,
            parentNoteId: _parentId);
        _noteId = note.id;
      } else {
        await mutate.updateGeneral(_noteId!,
            subject: subject, markdownBody: _bodyCtrl.text);
        if (_parentId != null) {
          await ref.read(mutateNoteProvider).attachExisting(_noteId!, _parentId!);
        }
        ref.invalidate(noteDetailProvider(_noteId!));
      }
      return _noteId;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addImage() async {
    final id = await _save(); // ensure the note exists first
    if (id == null) return;
    try {
      await ref.read(mutateNoteProvider).addImage(id);
      ref.invalidate(noteDetailProvider(id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Image added')));
      }
    } on AttachmentPickerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadExisting();
    return AppScaffold(
      title: widget.isNew ? 'New note' : 'Edit note',
      actions: [
        IconButton(
          tooltip: 'Add image',
          icon: const Icon(Icons.image),
          onPressed: _busy ? null : _addImage,
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  final id = await _save();
                  if (id != null && context.mounted) context.pop();
                },
          child: const Text('Save'),
        ),
      ],
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Grouped card: subsystem picker + subject, hairline between.
                AppGroupedCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer(builder: (context, ref, _) {
                        final anchorsAsync =
                            ref.watch(subsystemAnchorsProvider);
                        return anchorsAsync.maybeWhen(
                          data: (anchors) => DropdownButtonFormField<int?>(
                            initialValue:
                                anchors.any((a) => a.id == _parentId)
                                    ? _parentId
                                    : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Attach to subsystem',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('None')),
                              for (final a in anchors)
                                DropdownMenuItem<int?>(
                                    value: a.id, child: Text(a.subject)),
                            ],
                            onChanged: (v) => setState(() => _parentId = v),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        );
                      }),
                      const AppRowSeparator(indent: kRowInsetNoLeading),
                      TextField(
                        controller: _subjectCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Subject',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Body card fills the remaining space.
                Expanded(
                  child: AppGroupedCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: TextField(
                        controller: _bodyCtrl,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Body (markdown)',
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
