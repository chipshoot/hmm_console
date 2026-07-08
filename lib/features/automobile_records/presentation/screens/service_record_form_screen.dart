import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
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
import '../widgets/service_type_dropdown.dart';

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
  ServiceType _type = ServiceType.oilChange;
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
      _type = record.type;
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
                    ServiceTypeDropdown(
                      value: _type,
                      onChanged: (v) => setState(() => _type = v),
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
                    ),
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

  List<AttachmentItem> get _attachmentItems => [
        for (final p in _pendingImages) PendingImageItem(p),
        for (final r in _savedRefs)
          if (r.contentType.startsWith('image/')) SavedAttachmentItem(r),
        for (final p in _pendingFiles) PendingFileItem(p),
        for (final r in _savedRefs)
          if (!r.contentType.startsWith('image/')) SavedAttachmentItem(r),
      ];

  Future<void> _addImage() async {
    final pick = await ref
        .read(imageByteSourceProvider)
        .pick(AttachmentPickSource.gallery);
    if (pick != null) setState(() => _pendingImages.add(pick));
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
        type: _type,
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
          if (v.type != null) _type = v.type!;
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
      type: _type,
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
