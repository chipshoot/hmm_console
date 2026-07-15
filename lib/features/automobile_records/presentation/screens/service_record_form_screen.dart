import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/inline_ref_uri.dart';
import '../../../notes/presentation/widgets/inline_image_controller.dart';
import '../../../notes/presentation/widgets/note_markdown_body.dart';
import '../../../../core/data/attachments/open_attachment.dart';
import '../../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../core/data/attachments/widgets/attachments_section.dart';
import '../../../../core/data/data_mode.dart';
import '../../../receipt_scan/domain/apply_draft.dart';
import '../../../receipt_scan/domain/receipt_draft.dart';
import '../../../receipt_scan/presentation/scan_receipt_flow.dart';
import '../../../receipt_scan/providers/receipt_extractor_providers.dart';
import '../../../../core/network/dio_error_message.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../../../core/data/repository_providers.dart';
import '../../domain/entities/part_item.dart';
import '../../domain/entities/service_record.dart';
import '../../domain/entities/service_type.dart';
import '../../states/_records_automobile_id_provider.dart';
import '../../states/mutate_service_record_state.dart';
import '../widgets/optional_date_picker.dart';
import '../widgets/service_line_items_editor.dart';

class ServiceRecordFormScreen extends ConsumerStatefulWidget {
  const ServiceRecordFormScreen({
    super.key,
    required this.automobileId,
    this.recordId,
  });

  final int automobileId;
  final int? recordId;

  bool get isEdit => recordId != null;

  @override
  ConsumerState<ServiceRecordFormScreen> createState() =>
      _ServiceRecordFormScreenState();
}

class _ServiceRecordFormScreenState
    extends ConsumerState<ServiceRecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mileageCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _shopCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  List<ServiceType> _types = [ServiceType.oilChange];
  DateTime? _date;
  final String _currency = 'CAD';
  List<PartItem> _items = const [];
  double? _tax;

  bool _loading = false;
  ServiceRecord? _existing;

  final List<PickedImageBytes> _pendingImages = [];
  final List<PickedFileBytes> _pendingFiles = [];
  List<VaultRef> _savedRefs = []; // retained from the loaded record
  final List<VaultRef> _removedRefs = [];

  /// Inline images staged into the Notes markdown this session (shared with the
  /// general note editor). Resolved + rewritten to vault paths on save.
  final InlineImageController _inline = InlineImageController();

  /// Image paths referenced inline in the notes at load — used on save to
  /// confirm before dropping a stored image the user removed from the text.
  List<String> _loadedInlinePaths = const [];

  bool _scanning = false;
  // Bumped when a scan re-seeds the line items so the editor rebuilds with the
  // merged list (it captures initialItems once).
  int _itemsSeed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(recordsAutomobileIdProvider.notifier)
          .set(widget.automobileId);
      if (widget.isEdit) _loadExisting();
    });
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final record = await ref
          .read(serviceRecordRepositoryModeProvider)
          .getRecordById(widget.automobileId, widget.recordId!);
      _existing = record;
      _mileageCtrl.text = record.mileage.toString();
      _descriptionCtrl.text = record.description ?? '';
      _shopCtrl.text = record.shopName ?? '';
      _notesCtrl.text = record.notes ?? '';
      _loadedInlinePaths = imageRefPathsIn(record.notes ?? '');
      _nameCtrl.text = record.name ?? '';
      _refCtrl.text = record.referenceNumber ?? '';
      _types =
          record.types.isEmpty ? [ServiceType.other] : List.of(record.types);
      _date = record.date;
      _items = [...record.parts];
      // Force the line-items editor to rebuild with the loaded parts. It
      // captures initialItems once (late final) and is keyed by _itemsSeed,
      // so without bumping the seed a fast load (editor already built with an
      // empty list, no spinner frame in between) leaves the items invisible.
      _itemsSeed++;
      _tax = record.tax;
      _savedRefs = [
        ...record.attachments.images.whereType<VaultRef>(),
        ...record.attachments.files.whereType<VaultRef>(),
      ];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _mileageCtrl.dispose();
    _descriptionCtrl.dispose();
    _shopCtrl.dispose();
    _notesCtrl.dispose();
    _nameCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(mutateServiceRecordStateProvider).isLoading;

    ref.listen<AsyncValue<void>>(mutateServiceRecordStateProvider, (_, next) {
      if (next.hasValue && !next.isLoading && !next.isRefreshing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEdit ? 'Record updated' : 'Record added'),
          ),
        );
        if (mounted) context.pop();
      }
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dioErrorMessage(next.error!)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return CommonScreenScaffold(
      title: widget.isEdit ? 'Edit Service Record' : 'Add Service Record',
      child: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ScanReceiptCard(
                      mode: ref.watch(receiptExtractorModeProvider),
                      scanning: _scanning,
                      onTap: _scanning ? null : _showScanSheet,
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _nameCtrl,
                      fieldValidator: (_) => null,
                      label: 'Service name',
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _refCtrl,
                      fieldValidator: (_) => null,
                      label: 'Reference # (optional)',
                    ),
                    const SizedBox(height: 16),
                    OptionalDatePicker(
                      label: 'Service date',
                      date: _date,
                      onChanged: (d) => setState(() => _date = d),
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _mileageCtrl,
                      fieldValidator: _validatePositiveInt,
                      label: 'Mileage',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Service types',
                          style: Theme.of(context).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final t in ServiceType.values)
                          FilterChip(
                            label: Text(t.displayName),
                            selected: _types.contains(t),
                            onSelected: (on) => setState(() {
                              if (on) {
                                if (!_types.contains(t)) _types.add(t);
                              } else if (_types.length > 1) {
                                // Keep at least one category selected.
                                _types.remove(t);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _descriptionCtrl,
                      fieldValidator: (_) => null,
                      label: 'Description',
                    ),
                    const SizedBox(height: 16),
                    ServiceLineItemsEditor(
                      key: ValueKey(_itemsSeed),
                      initialItems: _items,
                      initialTax: _tax,
                      onChanged: (items, tax) {
                        _items = items;
                        _tax = tax;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _shopCtrl,
                      fieldValidator: (_) => null,
                      label: 'Shop name (optional)',
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _notesCtrl,
                      fieldValidator: (_) => null,
                      label: 'Notes',
                      helperText: 'Supports markdown',
                      onChanged: (_) => setState(() {}),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.image_outlined),
                        tooltip: 'Insert image into notes',
                        onPressed: _insertInlineImage,
                      ),
                    ),
                    if (_notesCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Preview',
                            style: Theme.of(context).textTheme.labelSmall),
                      ),
                      NoteMarkdownBody(
                        data: _notesCtrl.text,
                        resolver:
                            ref.watch(attachmentResolverProvider).value,
                        pendingBytes: _inline.pendingBytes,
                        selectable: false,
                      ),
                    ],
                    if (ref.watch(dataModeProvider) != DataMode.cloudApi) ...[
                      const SizedBox(height: 16),
                      AttachmentsSection(
                        items: _attachmentItems,
                        resolver:
                            ref.watch(attachmentResolverProvider).value ??
                                const _NullResolver(),
                        editable: true,
                        onAddImage: _addImage,
                        onAddPdf: _addPdf,
                        onRemove: _removeItem,
                        onTap: _openItem,
                      ),
                    ],
                    const SizedBox(height: 24),
                    HighlightButton(
                      text: saving
                          ? 'Saving...'
                          : (widget.isEdit ? 'Save Changes' : 'Add Record'),
                      onPressed: saving ? () {} : _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String? _validatePositiveInt(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final n = int.tryParse(v);
    if (n == null || n < 0) return 'Invalid';
    return null;
  }

  /// Keep any row the user put content into (a name OR a unit cost); only
  /// fully-blank placeholder rows are dropped. A populated-but-unnamed row is
  /// kept so `_submit` can flag it rather than silently discard it.
  List<PartItem> get _keptItems => _items
      .where((p) => p.name.trim().isNotEmpty || p.unitCost != null)
      .toList();

  List<AttachmentItem> get _attachmentItems {
    // Images shown inline in the notes are excluded from the gallery (dedup).
    final inline = imageRefPathsIn(_notesCtrl.text).toSet();
    return [
      for (final p in _pendingImages) PendingImageItem(p),
      for (final r in _savedRefs)
        if (r.contentType.startsWith('image/') && !inline.contains(r.path))
          SavedAttachmentItem(r),
      for (final p in _pendingFiles) PendingFileItem(p),
      for (final r in _savedRefs)
        if (!r.contentType.startsWith('image/')) SavedAttachmentItem(r),
    ];
  }

  Future<void> _addImage() async {
    final pick = await ref
        .read(imageByteSourceProvider)
        .pick(AttachmentPickSource.gallery);
    if (pick != null) setState(() => _pendingImages.add(pick));
  }

  /// Pick an image and insert it inline into the Notes markdown at the cursor.
  /// Staged for the live preview; persisted + rewritten on save.
  Future<void> _insertInlineImage() async {
    final pick = await ref
        .read(imageByteSourceProvider)
        .pick(AttachmentPickSource.gallery);
    if (pick == null || !mounted) return;
    setState(() => _inline.stageAndInsert(_notesCtrl, pick));
  }

  Future<void> _addPdf() async {
    final pick = await ref.read(fileByteSourceProvider).pickPdf();
    if (pick != null) setState(() => _pendingFiles.add(pick));
  }

  void _removeItem(AttachmentItem item) {
    setState(() {
      switch (item) {
        case PendingImageItem(:final pick):
          _pendingImages.remove(pick);
        case PendingFileItem(:final pick):
          _pendingFiles.remove(pick);
        case SavedAttachmentItem(:final ref):
          _savedRefs.remove(ref);
          _removedRefs.add(ref);
      }
    });
  }

  Future<void> _openItem(AttachmentItem item) async {
    // Pending items have no vault path yet — openable after save.
    if (item is! SavedAttachmentItem) return;
    final err = await openAttachment(ref, item.ref);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  ScanFormValues _currentValues() => ScanFormValues(
        shopName: _shopCtrl.text.trim().isEmpty ? null : _shopCtrl.text.trim(),
        date: _date,
        mileage: int.tryParse(_mileageCtrl.text),
        type: _types.first,
        tax: _tax,
        currency: _currency,
        items: _items,
      );

  Future<void> _showScanSheet() async {
    final cloudAi = ref.read(receiptExtractorModeProvider) ==
        ReceiptExtractorMode.cloudAi;
    final source = await showModalBottomSheet<_ScanSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, _ScanSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a photo'),
              onTap: () => Navigator.pop(ctx, _ScanSource.photo),
            ),
            // PDFs are readable only by the Cloud AI extractor; on-device OCR
            // handles images only.
            ListTile(
              enabled: cloudAi,
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose a PDF'),
              subtitle: cloudAi
                  ? null
                  : const Text('Needs Cloud AI (change in Settings)'),
              onTap: cloudAi ? () => Navigator.pop(ctx, _ScanSource.pdf) : null,
            ),
          ],
        ),
      ),
    );
    if (source != null) await _scanReceipt(source);
  }

  Future<void> _scanReceipt(_ScanSource source) async {
    final Uint8List bytes;
    final String contentType;
    if (source == _ScanSource.pdf) {
      final pick = await ref.read(fileByteSourceProvider).pickPdf();
      if (pick == null || !mounted) return;
      setState(() => _pendingFiles.add(pick));
      bytes = pick.bytes;
      contentType = pick.contentType ?? 'application/pdf';
    } else {
      final pick = await ref.read(imageByteSourceProvider).pick(
            source == _ScanSource.camera
                ? AttachmentPickSource.camera
                : AttachmentPickSource.gallery,
          );
      if (pick == null || !mounted) return;
      setState(() => _pendingImages.add(pick));
      bytes = pick.bytes;
      contentType = pick.contentType ?? 'image/jpeg';
    }

    setState(() => _scanning = true);
    final result = await scanReceipt(
      extractor: ref.read(receiptExtractorProvider),
      input: ReceiptInput(bytes: bytes, contentType: contentType),
      current: _currentValues(),
    );
    if (!mounted) return;
    setState(() => _scanning = false);

    switch (result) {
      case ScanSuccess(:final applied):
        setState(() {
          final v = applied.values;
          if (v.shopName != null) _shopCtrl.text = v.shopName!;
          if (v.date != null) _date = v.date;
          if (v.mileage != null) _mileageCtrl.text = v.mileage!.toString();
          if (v.type != null && !_types.contains(v.type)) {
            _types = [..._types, v.type!];
          }
          _tax = v.tax;
          _items = v.items;
          _itemsSeed++;
        });
        final mismatch = applied.totalsMismatch
            ? " Note: the receipt total doesn't match the itemized total."
            : '';
        final adjusted = applied.adjustedItemCount > 0
            ? ' (reconciled ${applied.adjustedItemCount} '
                '${applied.adjustedItemCount == 1 ? "line item" : "line items"} '
                'to match line totals)'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Filled ${applied.filledScalarCount} fields and '
            '${applied.appendedItemCount} line items$adjusted — '
            'review before saving.$mismatch',
          ),
        ));
      case ScanFailure(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      // The invalid field (usually a required, empty Mileage that a scan
      // didn't fill) can be scrolled off-screen above the line items, making
      // the button look dead — surface why the save didn't go through.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the highlighted fields (e.g. Mileage).'),
        ),
      );
      return;
    }
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service date is required')),
      );
      return;
    }

    final items = _keptItems;
    if (items.any((p) => p.name.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Each line item needs a name')),
      );
      return;
    }

    final record = ServiceRecord(
      id: _existing?.id ?? 0,
      automobileId: widget.automobileId,
      date: _date!,
      mileage: int.parse(_mileageCtrl.text),
      types: _types,
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      referenceNumber:
          _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      cost: items.isEmpty ? _existing?.cost : null,
      currency: _currency,
      shopName:
          _shopCtrl.text.trim().isEmpty ? null : _shopCtrl.text.trim(),
      parts: items,
      // Tax is only meaningful alongside items; don't persist a standalone
      // tax on an itemless (legacy-cost) record.
      tax: items.isEmpty ? null : _tax,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    final notifier = ref.read(mutateServiceRecordStateProvider.notifier);

    // Staged inline images need a note id to persist under. Resolve them, merge
    // the freshly-persisted refs into the retention set, then save once.
    if (_inline.pendingBytes.isNotEmpty) {
      int noteId;
      ServiceRecord base = record;
      if (!widget.isEdit) {
        // Create directly via the repo (not the notifier) so the create's
        // success state transition doesn't trip the form's save listener and
        // pop the screen mid-submit — the single pop happens on the save below.
        final ServiceRecord created;
        try {
          created = await ref
              .read(serviceRecordRepositoryModeProvider)
              .createRecord(widget.automobileId, record);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(dioErrorMessage(e)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ));
          }
          return;
        }
        base = created;
        noteId = created.id;
      } else {
        noteId = record.id;
      }

      final picker = await ref.read(imageAttachmentPickerProvider.future);
      final result = await _inline.resolveAndRewrite(
        noteId: noteId,
        body: _notesCtrl,
        persist: (id, pick) => picker.persistToVault(
          noteId: id,
          bytes: pick.bytes,
          originalName: pick.originalName,
          contentTypeHint: pick.contentType,
        ),
      );
      if (mounted) setState(() {});
      if (result.hadFailures && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Some images couldn't be added and were skipped."),
        ));
      }

      // Confirm any inline image the user removed from the notes text before
      // dropping the stored bytes.
      final removedPaths = InlineImageController.removedImagePaths(
        _loadedInlinePaths,
        _notesCtrl.text,
      ).toSet();
      final removedRefs = <VaultRef>[..._removedRefs];
      var retainedRefs = <VaultRef>[..._savedRefs];
      if (removedPaths.isNotEmpty && mounted) {
        final del = await _confirmRemoveInlineImages(removedPaths.length);
        if (del) {
          removedRefs
              .addAll(_savedRefs.where((r) => removedPaths.contains(r.path)));
          retainedRefs =
              retainedRefs.where((r) => !removedPaths.contains(r.path)).toList();
        }
      }
      // Merge the freshly-persisted inline refs into the retention set.
      for (final r in result.newRefs) {
        if (!retainedRefs.any((e) => e.path == r.path)) retainedRefs.add(r);
      }

      await notifier.save(
        autoId: widget.automobileId,
        // The record now exists (created above or already did).
        record: base.copyWith(
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        ),
        isEdit: true,
        pendingImages: _pendingImages,
        pendingFiles: _pendingFiles,
        retained: retainedRefs,
        removed: removedRefs,
      );
      return;
    }

    // No inline images — unchanged path.
    await notifier.save(
      autoId: widget.automobileId,
      record: record,
      isEdit: widget.isEdit,
      pendingImages: _pendingImages,
      pendingFiles: _pendingFiles,
      retained: _savedRefs,
      removed: _removedRefs,
    );
  }

  /// Asks whether to delete stored images the user removed from the notes text.
  /// Returns true = delete, false = keep attached (default on dismiss).
  Future<bool> _confirmRemoveInlineImages(int count) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove stored images?'),
        content: Text(
          'You removed $count image${count == 1 ? '' : 's'} from the notes. '
          'Delete the stored image${count == 1 ? '' : 's'}, or keep '
          '${count == 1 ? 'it' : 'them'} attached?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep attached'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}

/// Fallback resolver used only while [attachmentResolverProvider] is still
/// loading — renders every ref as its placeholder.
class _NullResolver implements IAttachmentResolver {
  const _NullResolver();
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}

enum _ScanSource { camera, photo, pdf }

/// Prominent "scan a receipt to auto-fill" affordance at the top of the form.
class _ScanReceiptCard extends StatelessWidget {
  const _ScanReceiptCard({
    required this.mode,
    required this.scanning,
    required this.onTap,
  });

  final ReceiptExtractorMode mode;
  final bool scanning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cloud = mode == ReceiptExtractorMode.cloudAi;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.document_scanner_outlined),
        title: const Text('Scan a receipt'),
        subtitle: Text(
          scanning
              ? 'Reading receipt…'
              : 'Auto-fill from a photo${cloud ? ' or PDF' : ''} · '
                  '${cloud ? 'Cloud AI' : 'On-device'}',
        ),
        trailing: scanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
