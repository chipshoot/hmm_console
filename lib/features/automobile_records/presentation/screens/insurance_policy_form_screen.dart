import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_error_message.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../../../core/data/data_mode.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/open_attachment.dart';
import '../../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../core/data/attachments/widgets/attachments_section.dart';
import '../../../../core/contact_block/contact_info.dart';
import '../../../../core/contact_block/widgets/contact_info_editor.dart';
import '../../domain/entities/auto_insurance_policy.dart';
import '../../states/_records_automobile_id_provider.dart';
import '../../states/mutate_insurance_policy_state.dart';
import '../widgets/optional_date_picker.dart';

class InsurancePolicyFormScreen extends ConsumerStatefulWidget {
  const InsurancePolicyFormScreen({
    super.key,
    required this.automobileId,
    this.policyId,
  });

  final int automobileId;
  final int? policyId;

  bool get isEdit => policyId != null;

  @override
  ConsumerState<InsurancePolicyFormScreen> createState() =>
      _InsurancePolicyFormScreenState();
}

class _InsurancePolicyFormScreenState
    extends ConsumerState<InsurancePolicyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _providerCtrl = TextEditingController();
  final _policyNumberCtrl = TextEditingController();

  /// Embedded contact blocks, edited in place. The form owns the list; each
  /// editor reports changes rather than holding its own copy.
  List<ContactInfo> _contacts = [];

  final List<PickedImageBytes> _pendingImages = [];
  final List<PickedFileBytes> _pendingFiles = [];
  final List<VaultRef> _savedRefs = [];
  final List<VaultRef> _removedRefs = [];
  final _premiumCtrl = TextEditingController();
  final _deductibleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _currency = 'CAD';
  DateTime? _effective;
  DateTime? _expiry;
  bool _isActive = true;

  bool _loading = false;
  AutoInsurancePolicy? _existing;

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
      final policy = await ref
          .read(insuranceRepositoryModeProvider)
          .getPolicyById(widget.automobileId, widget.policyId!);
      _existing = policy;
      _providerCtrl.text = policy.provider;
      _policyNumberCtrl.text = policy.policyNumber;
      _premiumCtrl.text = policy.premium.toStringAsFixed(2);
      _deductibleCtrl.text = policy.deductible?.toStringAsFixed(2) ?? '';
      _notesCtrl.text = policy.notes ?? '';
      _currency = policy.currency;
      _effective = policy.effectiveDate;
      _expiry = policy.expiryDate;
      _isActive = policy.isActive;
      _contacts = List.of(policy.contacts);
      _savedRefs
        ..clear()
        ..addAll([
          ...policy.attachments.images.whereType<VaultRef>(),
          ...policy.attachments.files.whereType<VaultRef>(),
        ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _providerCtrl.dispose();
    _policyNumberCtrl.dispose();
    _premiumCtrl.dispose();
    _deductibleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mutationState = ref.watch(mutateInsurancePolicyStateProvider);
    final saving = mutationState.isLoading;

    ref.listen<AsyncValue<void>>(mutateInsurancePolicyStateProvider, (_, next) {
      if (next.hasValue && !next.isLoading && !next.isRefreshing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEdit ? 'Policy updated' : 'Policy added'),
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
      title: widget.isEdit ? 'Edit Insurance Policy' : 'Add Insurance Policy',
      child: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextFormField(
                      fieldController: _providerCtrl,
                      fieldValidator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      label: l.recordsProvider,
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _policyNumberCtrl,
                      fieldValidator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      label: l.recordsPolicyNumberLabel,
                    ),
                    const SizedBox(height: 16),
                    OptionalDatePicker(
                      label: l.recordsEffectiveDate,
                      date: _effective,
                      onChanged: (d) => setState(() => _effective = d),
                    ),
                    const SizedBox(height: 16),
                    OptionalDatePicker(
                      label: l.recordsExpiryDate,
                      date: _expiry,
                      onChanged: (d) => setState(() => _expiry = d),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: AppTextFormField(
                            fieldController: _premiumCtrl,
                            fieldValidator: _validateAmount,
                            label: l.recordsPremium,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [_decimalFormatter],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppTextFormField(
                            fieldController:
                                TextEditingController(text: _currency),
                            fieldValidator: (_) => null,
                            label: l.recordsCurrencyShort,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _deductibleCtrl,
                      fieldValidator: (v) =>
                          (v == null || v.isEmpty) ? null : _validateAmount(v),
                      label: l.recordsDeductible,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [_decimalFormatter],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(l.recordsActive),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _notesCtrl,
                      fieldValidator: (_) => null,
                      label: l.recordsNotes,
                    ),
                    // Neither contacts nor attachments reach the API yet, so
                    // in cloudApi mode offering them would take input, report
                    // success, and discard it. Same guard the service-record
                    // form uses.
                    if (ref.watch(dataModeProvider) != DataMode.cloudApi) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.contactBlockTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton.icon(
                          key: const Key('addContactButton'),
                          icon: const Icon(Icons.add),
                          label: Text(l.contactBlockAdd),
                          onPressed: () => setState(
                            () => _contacts = [
                              ..._contacts,
                              const ContactInfo(role: ContactRoles.agent),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _contacts.length; i++)
                      Padding(
                        // Keyed by index so removing one does not carry the
                        // next block's controllers into the removed slot.
                        key: ValueKey('contactBlock_$i'),
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ContactInfoEditor(
                          value: _contacts[i],
                          onChanged: (c) {
                            final next = List.of(_contacts);
                            next[i] = c;
                            _contacts = next;
                          },
                          onRemove: () => setState(() {
                            final next = List.of(_contacts);
                            next.removeAt(i);
                            _contacts = next;
                          }),
                        ),
                      ),
                    const SizedBox(height: 24),
                    AttachmentsSection(
                      items: _attachmentItems,
                      resolver: ref.watch(attachmentResolverProvider).value ??
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
                          : (widget.isEdit ? 'Save Changes' : 'Add Policy'),
                      onPressed: saving ? () {} : _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

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
    // The picker is an OS sheet; the user can leave the form while it is open.
    if (pick == null || !mounted) return;
    setState(() => _pendingImages.add(pick));
  }

  Future<void> _addPdf() async {
    final pick = await ref.read(fileByteSourceProvider).pickPdf();
    if (pick == null || !mounted) return;
    setState(() => _pendingFiles.add(pick));
  }

  void _removeItem(AttachmentItem item) {
    setState(() {
      switch (item) {
        case PendingImageItem(:final pick):
          _pendingImages.remove(pick);
        case PendingFileItem(:final pick):
          _pendingFiles.remove(pick);
        case SavedAttachmentItem(:final ref):
          // Removed from the policy now, deleted from the vault on save -
          // cancelling the form must not destroy bytes.
          _savedRefs.remove(ref);
          _removedRefs.add(ref);
      }
    });
  }

  Future<void> _openItem(AttachmentItem item) async {
    // A pending pick has no vault path yet; openable once saved.
    if (item is! SavedAttachmentItem) return;
    final err = await openAttachment(ref, item.ref);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  String? _validateAmount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = double.tryParse(v);
    if (n == null) return 'Invalid number';
    if (n < 0) return 'Cannot be negative';
    return null;
  }

  static final _decimalFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_effective == null || _expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l.recordsDatesRequired)),
      );
      return;
    }
    if (!_effective!.isBefore(_expiry!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l.recordsDateOrderInvalid)),
      );
      return;
    }

    final policy = AutoInsurancePolicy(
      id: _existing?.id ?? 0,
      automobileId: widget.automobileId,
      provider: _providerCtrl.text.trim(),
      policyNumber: _policyNumberCtrl.text.trim(),
      effectiveDate: _effective!,
      expiryDate: _expiry!,
      premium: double.parse(_premiumCtrl.text),
      currency: _currency,
      deductible: _deductibleCtrl.text.trim().isEmpty
          ? null
          : double.parse(_deductibleCtrl.text),
      coverage: _existing?.coverage ?? const [],
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      isActive: _isActive,
      contacts: _contacts,
      // Retained refs only; newly picked bytes have no vault path until the
      // state writes them against the saved note id.
      attachments: NoteAttachments(
        images: _savedRefs.where((r) => r.contentType.startsWith('image/')).toList(),
        files: _savedRefs.where((r) => !r.contentType.startsWith('image/')).toList(),
      ),
    );

    final notifier = ref.read(mutateInsurancePolicyStateProvider.notifier);
    if (widget.isEdit) {
      await notifier.edit(
        widget.automobileId,
        _existing!.id,
        policy,
        pendingImages: _pendingImages,
        pendingFiles: _pendingFiles,
        removed: _removedRefs,
      );
    } else {
      await notifier.create(
        widget.automobileId,
        policy,
        pendingImages: _pendingImages,
        pendingFiles: _pendingFiles,
      );
    }
  }
}

class _NullResolver implements IAttachmentResolver {
  const _NullResolver();
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}
