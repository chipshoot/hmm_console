import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
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

  /// Shown under the title. For a new note this is "today" (the value it will
  /// be created with); for an existing note it's the note's create date.
  late DateTime _createdAt;

  @override
  void initState() {
    super.initState();
    _noteId = widget.noteId;
    _parentId = widget.presetParentId;
    _createdAt = DateTime.now();
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
      _createdAt = note.createDate.toLocal();
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

  String get _stampText =>
      '${DateFormat.yMMMMd().format(_createdAt)} · ${DateFormat.jm().format(_createdAt)}';

  /// Compact nav bar (no large title — the subject *is* the page title).
  PreferredSizeWidget _buildNav(BuildContext context, AppColors c) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    Future<void> onSave() async {
      final id = await _save();
      if (id != null && context.mounted) context.pop();
    }

    if (isApple) {
      return CupertinoNavigationBar(
        backgroundColor: c.groupedBackground,
        border: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 36),
              onPressed: _busy ? null : _addImage,
              child: Icon(CupertinoIcons.photo, color: c.accent, size: 24),
            ),
            const SizedBox(width: 6),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 36),
              onPressed: _busy ? null : onSave,
              child: Text('Save',
                  style: TextStyle(
                      color: c.accent,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
    return AppBar(
      backgroundColor: c.groupedBackground,
      actions: [
        IconButton(
          tooltip: 'Add image',
          icon: const Icon(Icons.image),
          onPressed: _busy ? null : _addImage,
        ),
        TextButton(onPressed: _busy ? null : onSave, child: const Text('Save')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _loadExisting();
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.groupedBackground,
      appBar: _buildNav(context, c),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subsystem attach — a control above / outside the note page.
          _SubsystemStrip(
            parentId: _parentId,
            onChanged: (v) => setState(() => _parentId = v),
          ),
          // The note page: borderless title · timestamp · one rule · canvas.
          Expanded(
            child: ColoredBox(
              color: c.secondaryGroupedBackground,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _subjectCtrl,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: DesignTokens.titleLarge
                          .copyWith(color: c.label, fontSize: 26),
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_stampText,
                        style: DesignTokens.caption
                            .copyWith(color: c.tertiaryLabel)),
                    const SizedBox(height: 12),
                    Divider(height: 1, thickness: 1, color: c.separator),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        controller: _bodyCtrl,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                            fontSize: 16, color: c.label, height: 1.4),
                        decoration: const InputDecoration(
                          hintText: 'Start writing…',
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Attach to subsystem" control, on a grey strip above the note page.
class _SubsystemStrip extends ConsumerWidget {
  const _SubsystemStrip({required this.parentId, required this.onChanged});

  final int? parentId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final anchorsAsync = ref.watch(subsystemAnchorsProvider);
    return Container(
      decoration: BoxDecoration(
        color: c.groupedBackground,
        border: Border(bottom: BorderSide(color: c.separator)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('Attach to subsystem',
              style: DesignTokens.rowSecondary.copyWith(color: c.secondaryLabel)),
          const Spacer(),
          anchorsAsync.maybeWhen(
            data: (anchors) {
              final value =
                  anchors.any((a) => a.id == parentId) ? parentId : null;
              return Container(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                decoration: BoxDecoration(
                  color: c.secondaryGroupedBackground,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                  border: Border.all(color: c.separator),
                ),
                child: DropdownButton<int?>(
                  value: value,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                  icon: Icon(Icons.expand_more, size: 18, color: c.secondaryLabel),
                  style: DesignTokens.rowTitle.copyWith(color: c.label, fontSize: 15),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('None')),
                    for (final a in anchors)
                      DropdownMenuItem<int?>(
                          value: a.id, child: Text(a.subject)),
                  ],
                  onChanged: onChanged,
                ),
              );
            },
            orElse: () => const SizedBox(height: 20),
          ),
        ],
      ),
    );
  }
}
