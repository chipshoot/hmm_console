import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/picker/image_attachment_picker.dart'
    show AttachmentPickSource;
import '../../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/data/note_location.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../gas_log/providers/location_provider.dart'
    show currentPositionProvider;
import '../../../settings/providers/geo_capture_provider.dart';
import '../../providers/note_location_capture.dart';
import '../widgets/note_file_card_list.dart';
import '../widgets/note_location_card.dart';
import '../widgets/record_sheet.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/subsystem_anchor.dart';
import '../../states/mutate_note_state.dart';
import '../screens/note_detail_screen.dart' show noteDetailProvider;
import '../widgets/media_toolbar.dart';
import '../widgets/note_media_card_list.dart';

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
  final _bodyFocus = FocusNode();
  int? _noteId; // becomes non-null once persisted
  int? _parentId;
  bool _parentTouched = false; // user changed the subsystem dropdown
  bool _busy = false;
  bool _loaded = false;

  /// Images picked this session, not yet attached (attached on save).
  final List<PickedImageBytes> _pendingPicks = [];

  /// Images already attached to the note (when editing an existing note).
  List<AttachmentRef> _savedImages = [];

  /// PDF/files picked this session, not yet attached (attached on save).
  final List<PickedFileBytes> _pendingFiles = [];

  /// Files already attached to the note (when editing an existing note).
  List<AttachmentRef> _savedFiles = [];

  /// Editable note date shown under the title. New note: defaults to now.
  /// Existing note: the note's effectiveNoteDate. OneNote-style — tap to edit.
  late DateTime _noteDate;

  /// Captured/loaded note location (Phase 2b). Null = none. Shown as a card.
  NoteLocation? _pendingLocation;

  /// True once a persisted location was removed, so an update writes the clear.
  bool _locationCleared = false;

  @override
  void initState() {
    super.initState();
    _noteId = widget.noteId;
    _parentId = widget.presetParentId;
    _noteDate = DateTime.now();
    if (widget.noteId == null) {
      _maybeCaptureLocation();
    }
  }

  /// For a new note, when the opt-in toggle is on, capture the current
  /// location in the background (non-blocking). Failures leave it null.
  Future<void> _maybeCaptureLocation() async {
    try {
      final enabled = await ref.read(geoCaptureEnabledProvider.future);
      if (!enabled || !mounted) return;
      // Force a fresh fix — both providers cache for the ProviderScope's
      // lifetime, so without this a second note would reuse the first note's
      // coordinates.
      ref.invalidate(currentPositionProvider);
      ref.invalidate(noteLocationCaptureProvider);
      final loc = await ref.read(noteLocationCaptureProvider.future);
      if (loc == null || !mounted) return;
      setState(() => _pendingLocation = loc);
    } catch (_) {
      // Best-effort: any failure ⇒ no card, no crash.
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (_loaded || widget.noteId == null) return;
    _loaded = true;
    final note = await ref
        .read(hmmNoteRepositoryProvider)
        .getNoteById(widget.noteId!);
    if (note != null && mounted) {
      _subjectCtrl.text = note.subject;
      _bodyCtrl.text = note.content ?? '';
      _noteDate = note.effectiveNoteDate.toLocal();
      _savedImages = [
        if (note.effectiveAttachments.primaryImage != null)
          note.effectiveAttachments.primaryImage!,
        ...note.effectiveAttachments.images,
      ];
      // Reflect the note's real attachment so the dropdown isn't stuck on
      // "None". Don't mark it touched — an untouched dropdown must not
      // rewrite the parent on save.
      if (!_parentTouched) _parentId = note.parentNoteId;
      _pendingLocation = note.location;
      _savedFiles = [...note.effectiveAttachments.files];
      setState(() {});
    }
  }

  /// Persists the note (create or update) and returns its id.
  Future<int?> _save() async {
    final subject = _subjectCtrl.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subject is required')));
      return null;
    }
    final mutate = ref.read(mutateNoteProvider);
    setState(() => _busy = true);
    try {
      if (_noteId == null) {
        final note = await mutate.createGeneral(
          subject: subject,
          markdownBody: _bodyCtrl.text,
          parentNoteId: _parentId,
          noteDate: _noteDate.toUtc(),
          location: _pendingLocation,
        );
        _noteId = note.id;
      } else {
        // 2b has no edit-to-a-new-place path: we only ever clear a removed
        // location (NoteLocation.empty); otherwise pass null = don't touch.
        await mutate.updateGeneral(
          _noteId!,
          subject: subject,
          markdownBody: _bodyCtrl.text,
          noteDate: _noteDate.toUtc(),
          location: _locationCleared ? NoteLocation.empty : null,
        );
        // Persist the chosen subsystem only if the user changed it — covers
        // attach (id), detach (null), and re-link. An untouched dropdown
        // leaves the existing parent intact (avoids the async-load race).
        if (_parentTouched) {
          await mutate.setParent(_noteId!, _parentId);
        }
        ref.invalidate(noteDetailProvider(_noteId!));
      }
      // Attach any photos added this session, then clear them.
      if (_pendingPicks.isNotEmpty && _noteId != null) {
        for (final pick in _pendingPicks) {
          await mutate.attachImageBytes(_noteId!, pick);
        }
        if (mounted) setState(() => _pendingPicks.clear());
        ref.invalidate(noteDetailProvider(_noteId!));
      }
      // Attach any PDFs added this session, then clear them.
      if (_pendingFiles.isNotEmpty && _noteId != null) {
        for (final pick in _pendingFiles) {
          await mutate.attachFileBytes(_noteId!, pick);
        }
        if (mounted) setState(() => _pendingFiles.clear());
        ref.invalidate(noteDetailProvider(_noteId!));
      }
      return _noteId;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Pick an image (gallery/camera) and hold it as pending — it attaches on the
  /// next save. No subject required to add.
  Future<void> _addMedia(AttachmentPickSource source) async {
    final pick = await ref.read(imageByteSourceProvider).pick(source);
    if (pick != null && mounted) {
      setState(() => _pendingPicks.add(pick));
    }
  }

  /// Pick a PDF and hold it pending — attaches on the next save.
  Future<void> _addFile() async {
    final pick = await ref.read(fileByteSourceProvider).pickPdf();
    if (pick != null && mounted) {
      setState(() => _pendingFiles.add(pick));
    }
  }

  /// Record a voice note (modal sheet) and hold it pending — attaches on save.
  Future<void> _addRecording() async {
    final pick = await showRecordSheet(context, ref);
    if (pick != null && mounted) {
      setState(() => _pendingFiles.add(pick));
    }
  }

  String get _stampText =>
      '${DateFormat.yMMMMd().format(_noteDate)} · ${DateFormat.jm().format(_noteDate)}';

  /// OneNote-style: tap the date line to edit the note date (date + time).
  /// Cupertino modal on Apple; Material date-then-time on Android.
  Future<void> _pickNoteDate() async {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    if (isApple) {
      DateTime temp = _noteDate;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => Container(
          height: 280,
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () {
                        setState(() => _noteDate = temp);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _noteDate,
                  use24hFormat: false,
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final date = await showDatePicker(
        context: context,
        initialDate: _noteDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_noteDate),
      );
      if (!mounted) return;
      setState(() {
        _noteDate = DateTime(
          date.year,
          date.month,
          date.day,
          time?.hour ?? _noteDate.hour,
          time?.minute ?? _noteDate.minute,
        );
      });
    }
  }

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
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 36),
          onPressed: _busy ? null : onSave,
          child: Text(
            'Save',
            style: TextStyle(
              color: c.accent,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return AppBar(
      backgroundColor: c.groupedBackground,
      actions: [
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
      bottomNavigationBar: MediaToolbar(
        onPick: _addMedia,
        onPickFile: _addFile,
        onRecord: _addRecording,
        enabled: !_busy,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subsystem attach — a control above / outside the note page.
          _SubsystemStrip(
            parentId: _parentId,
            onChanged: (v) => setState(() {
              _parentId = v;
              _parentTouched = true;
            }),
          ),
          // The note page: borderless title · timestamp · one rule · canvas.
          Expanded(
            child: ColoredBox(
              color: c.secondaryGroupedBackground,
              // Scrollable so the body stays reachable above the keyboard once
              // images/cards fill the page — otherwise the fixed content above
              // it squeezes the body field to nothing and the input panel
              // covers it. The translucent GestureDetector keeps the
              // "tap anywhere on the canvas to write" affordance now that the
              // body no longer fills the whole page.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _bodyFocus.requestFocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _subjectCtrl,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: DesignTokens.titleLarge.copyWith(
                          color: c.label,
                          fontSize: 26,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Title',
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _busy ? null : _pickNoteDate,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _stampText,
                              style: DesignTokens.caption.copyWith(
                                color: c.tertiaryLabel,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_calendar_outlined,
                              size: 14,
                              color: c.tertiaryLabel,
                            ),
                          ],
                        ),
                      ),
                      if (_pendingLocation != null &&
                          !_pendingLocation!.isEmpty)
                        NoteLocationCard(
                          location: _pendingLocation!,
                          onRemove: () => setState(() {
                            _pendingLocation = null;
                            _locationCleared = true;
                          }),
                        ),
                      const SizedBox(height: 12),
                      Divider(height: 1, thickness: 1, color: c.separator),
                      const SizedBox(height: 12),
                      NoteMediaCardList(
                        saved: _savedImages,
                        pending: _pendingPicks,
                        onRemovePending: (i) =>
                            setState(() => _pendingPicks.removeAt(i)),
                      ),
                      NoteFileCardList(
                        saved: _savedFiles,
                        pending: _pendingFiles,
                        onRemovePending: (i) =>
                            setState(() => _pendingFiles.removeAt(i)),
                      ),
                      TextField(
                        controller: _bodyCtrl,
                        focusNode: _bodyFocus,
                        maxLines: null,
                        minLines: 8,
                        textAlignVertical: TextAlignVertical.top,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 16,
                          color: c.label,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Start writing…',
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
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
          Text(
            'Attach to subsystem',
            style: DesignTokens.rowSecondary.copyWith(color: c.secondaryLabel),
          ),
          const Spacer(),
          anchorsAsync.maybeWhen(
            data: (anchors) {
              final value = anchors.any((a) => a.id == parentId)
                  ? parentId
                  : null;
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
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radiusMedium,
                  ),
                  icon: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: c.secondaryLabel,
                  ),
                  style: DesignTokens.rowTitle.copyWith(
                    color: c.label,
                    fontSize: 15,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None'),
                    ),
                    for (final a in anchors)
                      DropdownMenuItem<int?>(
                        value: a.id,
                        child: Text(a.subject),
                      ),
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
