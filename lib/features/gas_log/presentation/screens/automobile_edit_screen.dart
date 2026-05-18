import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../../../core/widgets/editable_info_card.dart';
import '../../../../core/widgets/gaps.dart';
import '../../../../core/widgets/numeric_input.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../../auth/providers/current_user_provider.dart';
import '../../../automobile_records/presentation/widgets/automobile_records_summary.dart';
import '../../domain/entities/automobile.dart';
import '../../../settings/providers/gas_log_settings_provider.dart';
import '../../domain/validators/automobile_validator.dart';
import '../../states/automobiles_state.dart';
import '../../states/update_automobile_state.dart';
import '../widgets/engine_type_dropdown.dart';
import '../widgets/fuel_type_dropdown.dart';
import '../widgets/ownership_status_dropdown.dart';

/// Vehicle Information screen.
///
/// Layout (top → bottom):
///   1. Identity (VIN, maker, brand, …) — read-only by default. Long-press
///      the header to unlock for typo correction; an inline Save/Cancel
///      pair appears while unlocked.
///   2. Mileage     — EditableInfoCard
///   3. Registration — EditableInfoCard
///   4. Insurance / Service / Scheduled-service summary cards (each links
///      out to its own record-history screen).
///   5. Notes — EditableInfoCard
///   6. Audit log (read-only)
///
/// Each EditableInfoCard owns its own edit toggle + Save/Cancel buttons;
/// there is no global Save button. Persisting a single card calls
/// `updateAutomobileStateProvider` with the full Automobile (other fields
/// unchanged from `_original`).
class AutomobileEditScreen extends ConsumerStatefulWidget {
  final int automobileId;

  const AutomobileEditScreen({super.key, required this.automobileId});

  @override
  ConsumerState<AutomobileEditScreen> createState() =>
      _AutomobileEditScreenState();
}

class _AutomobileEditScreenState extends ConsumerState<AutomobileEditScreen>
    with AutomobileValidator {
  final _identityFormKey = GlobalKey<FormState>();

  // Identity fields (locked by default)
  bool _immutableUnlocked = false;
  bool _identitySaving = false;
  final _vinCtrl = TextEditingController();
  final _makerCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _trimCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  String _engineType = 'Gasoline';
  String _fuelType = 'Regular';
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  String _ownershipStatus = 'Owned';

  // Per-card pending state
  final _meterReadingCtrl = TextEditingController();
  DateTime? _registrationExpiryDate;
  final _notesCtrl = TextEditingController();

  // Photo banner — instant-commit picker (no draft state). Tapping
  // pick or remove goes straight through _persist; there's no
  // Save/Cancel for this card because there's nothing to validate.
  // _photoBusy disables the controls while the picker / save is
  // in flight.
  bool _photoBusy = false;

  Automobile? _original;

  @override
  void initState() {
    super.initState();
    _populateFromOriginal();
  }

  void _populateFromOriginal() {
    final data = ref.read(automobilesStateProvider).value;
    if (data == null) return;
    final auto =
        data.where((a) => a.id == widget.automobileId).firstOrNull;
    if (auto == null) return;
    _original = auto;
    _resetIdentityFields();
    _resetMileage();
    _resetRegistration();
    _resetNotes();
  }

  void _resetIdentityFields() {
    final orig = _original!;
    _vinCtrl.text = orig.vin ?? '';
    _makerCtrl.text = orig.maker ?? '';
    _brandCtrl.text = orig.brand ?? '';
    _modelCtrl.text = orig.model ?? '';
    _trimCtrl.text = orig.trim ?? '';
    _yearCtrl.text = orig.year > 0 ? '${orig.year}' : '';
    _engineType = orig.engineType ?? 'Gasoline';
    _fuelType = orig.fuelType ?? 'Regular';
    _colorCtrl.text = orig.color ?? '';
    _plateCtrl.text = orig.plate ?? '';
    _ownershipStatus = orig.ownershipStatus ?? 'Owned';
  }

  void _resetMileage() {
    _meterReadingCtrl.text = _original!.meterReading.toString();
  }

  void _resetRegistration() {
    _registrationExpiryDate = _original!.registrationExpiryDate;
  }

  void _resetNotes() {
    _notesCtrl.text = _original!.notes ?? '';
  }

  @override
  void dispose() {
    _vinCtrl.dispose();
    _makerCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _trimCtrl.dispose();
    _yearCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    _meterReadingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // -------------------- Save plumbing --------------------

  /// Pushes [updated] through the update notifier, awaits completion, and
  /// updates [_original] so subsequent card edits start from fresh data.
  /// Errors surface via the snackbar listener; returns false to keep the
  /// caller's editor open.
  Future<bool> _persist(Automobile updated) async {
    await ref
        .read(updateAutomobileStateProvider.notifier)
        .updateAutomobile(widget.automobileId, updated);
    if (!mounted) return false;
    final s = ref.read(updateAutomobileStateProvider);
    if (s.hasError) return false;
    setState(() => _original = updated);
    return true;
  }

  Automobile _cloneWith({
    String? vin,
    String? maker,
    String? brand,
    String? model,
    String? trim,
    int? year,
    String? color,
    String? plate,
    String? engineType,
    String? fuelType,
    int? meterReading,
    String? ownershipStatus,
    Object? registrationExpiryDate = _kSentinel,
    Object? notes = _kSentinel,
    Object? primaryImage = _kSentinel,
    List<AutomobileAuditEntry>? auditLog,
  }) {
    final orig = _original!;
    return Automobile(
      id: orig.id,
      vin: vin ?? orig.vin,
      maker: maker ?? orig.maker,
      brand: brand ?? orig.brand,
      model: model ?? orig.model,
      trim: trim ?? orig.trim,
      year: year ?? orig.year,
      color: color ?? orig.color,
      plate: plate ?? orig.plate,
      engineType: engineType ?? orig.engineType,
      fuelType: fuelType ?? orig.fuelType,
      fuelTankCapacity: orig.fuelTankCapacity,
      cityMPG: orig.cityMPG,
      highwayMPG: orig.highwayMPG,
      combinedMPG: orig.combinedMPG,
      meterReading: meterReading ?? orig.meterReading,
      purchaseMeterReading: orig.purchaseMeterReading,
      purchaseDate: orig.purchaseDate,
      purchasePrice: orig.purchasePrice,
      ownershipStatus: ownershipStatus ?? orig.ownershipStatus,
      isActive: orig.isActive,
      soldDate: orig.soldDate,
      soldMeterReading: orig.soldMeterReading,
      soldPrice: orig.soldPrice,
      registrationExpiryDate: identical(registrationExpiryDate, _kSentinel)
          ? orig.registrationExpiryDate
          : registrationExpiryDate as DateTime?,
      insuranceExpiryDate: orig.insuranceExpiryDate,
      insuranceProvider: orig.insuranceProvider,
      insurancePolicyNumber: orig.insurancePolicyNumber,
      lastServiceDate: orig.lastServiceDate,
      lastServiceMeterReading: orig.lastServiceMeterReading,
      nextServiceDueDate: orig.nextServiceDueDate,
      nextServiceDueMeterReading: orig.nextServiceDueMeterReading,
      notes: identical(notes, _kSentinel) ? orig.notes : notes as String?,
      createdDate: orig.createdDate,
      lastModifiedDate: orig.lastModifiedDate,
      primaryImage: identical(primaryImage, _kSentinel)
          ? orig.primaryImage
          : primaryImage as AttachmentRef?,
      images: orig.images,
      auditLog: auditLog ?? orig.auditLog,
    );
  }

  static const Object _kSentinel = Object();

  // -------------------- Per-card save handlers --------------------

  Future<bool> _saveMileage() async {
    final newMeter = int.tryParse(_meterReadingCtrl.text);
    if (newMeter == null || newMeter < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid meter reading')),
      );
      return false;
    }
    return _persist(_cloneWith(meterReading: newMeter));
  }

  Future<bool> _saveRegistration() async {
    return _persist(_cloneWith(registrationExpiryDate: _registrationExpiryDate));
  }

  Future<bool> _saveNotes() async {
    final trimmed = _notesCtrl.text.trim();
    return _persist(_cloneWith(notes: trimmed.isEmpty ? null : trimmed));
  }

  // -------------------- Photo banner --------------------

  Future<void> _pickAndSavePhoto() async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      final picker = await ref.read(imageAttachmentPickerProvider.future);
      final picked = await picker.pickForNote(
        noteId: widget.automobileId,
        source: AttachmentPickSource.gallery,
      );
      if (!mounted) return;
      if (picked == null) return; // user cancelled
      await _persist(_cloneWith(primaryImage: picked));
    } on AttachmentPickerException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      await _persist(_cloneWith(primaryImage: null));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _showPhotoActionSheet() async {
    if (_photoBusy) return;
    final hasPhoto = _original?.primaryImage != null;
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(hasPhoto ? 'Replace photo' : 'Choose photo'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_PhotoAction.pick),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Remove photo',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _PhotoAction.pick:
        await _pickAndSavePhoto();
      case _PhotoAction.remove:
        await _removePhoto();
    }
  }

  void _showFullscreenPhoto(AttachmentRef ref_) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Consumer(builder: (context, ref, _) {
        final resolverAsync = ref.watch(attachmentResolverProvider);
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: resolverAsync.when(
                data: (resolver) => InteractiveViewer(
                  child: AttachmentImage(ref: ref_, resolver: resolver),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text(
                  'Could not load photo: $e',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _saveIdentity() async {
    if (!_identityFormKey.currentState!.validate()) return;
    setState(() => _identitySaving = true);
    try {
      final orig = _original!;
      final newVin = _vinCtrl.text.isNotEmpty ? _vinCtrl.text : null;
      final newMaker = _makerCtrl.text.isNotEmpty ? _makerCtrl.text : null;
      final newBrand = _brandCtrl.text.isNotEmpty ? _brandCtrl.text : null;
      final newModel = _modelCtrl.text.isNotEmpty ? _modelCtrl.text : null;
      final newTrim = _trimCtrl.text.isNotEmpty ? _trimCtrl.text : null;
      final newYear = int.tryParse(_yearCtrl.text) ?? orig.year;
      final newColor = _colorCtrl.text.isNotEmpty ? _colorCtrl.text : null;
      final newPlate = _plateCtrl.text.isNotEmpty ? _plateCtrl.text : null;

      final auditAdditions = _diffIdentity(orig, {
        'vin': newVin,
        'maker': newMaker,
        'brand': newBrand,
        'model': newModel,
        'trim': newTrim,
        'year': newYear == 0 ? null : '$newYear',
        'engineType': _engineType,
        'fuelType': _fuelType,
        'color': newColor,
        'plate': newPlate,
        'ownershipStatus': _ownershipStatus,
      });

      final updated = _cloneWith(
        vin: newVin,
        maker: newMaker,
        brand: newBrand,
        model: newModel,
        trim: newTrim,
        year: newYear,
        color: newColor,
        plate: newPlate,
        engineType: _engineType,
        fuelType: _fuelType,
        ownershipStatus: _ownershipStatus,
        auditLog: [...orig.auditLog, ...auditAdditions],
      );

      final ok = await _persist(updated);
      if (ok && mounted) {
        setState(() => _immutableUnlocked = false);
      }
    } finally {
      if (mounted) setState(() => _identitySaving = false);
    }
  }

  void _cancelIdentity() {
    setState(() {
      _resetIdentityFields();
      _immutableUnlocked = false;
    });
  }

  // -------------------- Build --------------------

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gasLogSettingsProvider);
    final distLabel = settings.distanceUnit.label;

    ref.listen<AsyncValue<void>>(updateAutomobileStateProvider, (_, next) {
      if (next.hasValue && !next.isLoading && !next.isRefreshing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle updated')),
        );
      }
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    if (_original == null) {
      return CommonScreenScaffold(
        title: 'Vehicle Information',
        child: const Center(child: Text('Vehicle not found')),
      );
    }

    final orig = _original!;

    return CommonScreenScaffold(
      title: 'Vehicle Information',
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. Photo — full-width hero above the cards. Vehicles
              //    carry visual information (plate, color, condition,
              //    body style) that's worth the screen real estate.
              _photoBanner(orig),
              GapWidgets.h16,

              // 1. Identity (read-only / long-press to unlock)
              _identityCard(context, orig),
              GapWidgets.h16,

              // 2. Mileage
              EditableInfoCard(
                icon: Icons.speed_outlined,
                title: 'Mileage',
                displayBuilder: (_) =>
                    _readOnlyRow('Meter reading', '${orig.meterReading} $distLabel'),
                editorBuilder: (_) => AppTextFormField(
                  fieldController: _meterReadingCtrl,
                  fieldValidator: validateMeterReading,
                  label: 'Meter Reading ($distLabel)',
                  keyboardType: NumericInput.integer.keyboardType,
                  inputFormatters: NumericInput.integer.formatters,
                ),
                onSave: _saveMileage,
                onCancel: () => setState(_resetMileage),
              ),
              GapWidgets.h16,

              // 3. Registration — hidden when the user disables it in
              // Settings (e.g. Ontario retired the renewal sticker
              // in 2022, so this card is just noise there).
              if (settings.showRegistration) ...[
                EditableInfoCard(
                  icon: Icons.assignment_outlined,
                  title: 'Registration',
                  displayBuilder: (_) => _readOnlyRow(
                    'Expiry',
                    orig.registrationExpiryDate != null
                        ? _formatDate(orig.registrationExpiryDate!)
                        : 'Not set',
                  ),
                  editorBuilder: (_) => _optionalDatePicker(
                    context,
                    label: 'Registration Expiry',
                    date: _registrationExpiryDate,
                    onChanged: (d) =>
                        setState(() => _registrationExpiryDate = d),
                  ),
                  onSave: _saveRegistration,
                  onCancel: () => setState(_resetRegistration),
                ),
                GapWidgets.h16,
              ],

              // 4. Insurance / Service / Scheduled-service summary cards
              AutomobileRecordsSummary(automobileId: widget.automobileId),
              GapWidgets.h16,

              // 5. Notes
              EditableInfoCard(
                icon: Icons.notes_outlined,
                title: 'Notes',
                displayBuilder: (_) => Text(
                  orig.notes?.isNotEmpty == true ? orig.notes! : 'No notes',
                  style: orig.notes?.isNotEmpty == true
                      ? null
                      : TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                ),
                editorBuilder: (_) => AppTextFormField(
                  fieldController: _notesCtrl,
                  fieldValidator: (_) => null,
                  label: 'Notes (optional)',
                ),
                onSave: _saveNotes,
                onCancel: () => setState(_resetNotes),
              ),
              GapWidgets.h16,

              // 6. Audit log (read-only)
              if (orig.auditLog.isNotEmpty) ...[
                _sectionTitle(context, 'Change history'),
                GapWidgets.h8,
                ..._buildAuditList(context, orig.auditLog),
                GapWidgets.h24,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoBanner(Automobile orig) {
    final cs = Theme.of(context).colorScheme;
    final photo = orig.primaryImage;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo == null)
              // No photo: the whole banner is a tap target that opens
              // the picker.
              InkWell(
                onTap: _photoBusy ? null : _pickAndSavePhoto,
                child: Container(
                  color: cs.surfaceContainerHighest,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 40,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add photo',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Photo set: tap → fullscreen; pencil overlay (below)
              // opens the edit action sheet.
              Consumer(
                builder: (context, ref, _) {
                  final resolverAsync = ref.watch(attachmentResolverProvider);
                  return resolverAsync.when(
                    data: (resolver) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showFullscreenPhoto(photo),
                      child: AttachmentImage(
                        ref: photo,
                        resolver: resolver,
                        loadingPlaceholder: Container(
                          color: cs.surfaceContainerHighest,
                        ),
                        errorPlaceholder: Container(
                          color: cs.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: const Text('Photo unavailable'),
                        ),
                      ),
                    ),
                    loading: () =>
                        Container(color: cs.surfaceContainerHighest),
                    error: (_, _) => Container(
                      color: cs.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Text('Photo unavailable'),
                    ),
                  );
                },
              ),
            if (photo != null)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: _photoBusy ? null : _showPhotoActionSheet,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit photo',
                  ),
                ),
              ),
            if (_photoBusy)
              Container(
                color: Colors.black26,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _identityCard(BuildContext context, Automobile orig) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: _immutableUnlocked
              ? null
              : () => _confirmUnlockImmutables(context),
          child: Form(
            key: _identityFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_car, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      _immutableUnlocked
                          ? 'Vehicle Info'
                          : 'Vehicle Info (read-only)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                if (!_immutableUnlocked) ...[
                  GapWidgets.h4,
                  Text(
                    'Hold to edit',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
                GapWidgets.h16,
                if (_immutableUnlocked)
                  ..._identityEditFields()
                else
                  ..._identityReadOnlyFields(orig),
                if (_immutableUnlocked) ...[
                  GapWidgets.h16,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _identitySaving ? null : _cancelIdentity,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _identitySaving ? null : _saveIdentity,
                        child: Text(
                            _identitySaving ? 'Saving...' : 'Save changes'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _identityEditFields() => [
        AppTextFormField(
          fieldController: _vinCtrl,
          fieldValidator: validateVin,
          label: 'VIN (17 characters)',
        ),
        GapWidgets.h16,
        AppTextFormField(
          fieldController: _makerCtrl,
          fieldValidator: validateMaker,
          label: 'Maker',
        ),
        GapWidgets.h16,
        AppTextFormField(
          fieldController: _brandCtrl,
          fieldValidator: validateBrand,
          label: 'Brand',
        ),
        GapWidgets.h16,
        AppTextFormField(
          fieldController: _modelCtrl,
          fieldValidator: validateModel,
          label: 'Model',
        ),
        GapWidgets.h16,
        AppTextFormField(
          fieldController: _trimCtrl,
          fieldValidator: (_) => null,
          label: 'Trim (optional)',
        ),
        GapWidgets.h16,
        AppTextFormField(
          fieldController: _yearCtrl,
          fieldValidator: validateYear,
          label: 'Year',
          keyboardType: NumericInput.integer.keyboardType,
          inputFormatters: NumericInput.integer.formatters,
        ),
        GapWidgets.h16,
        EngineTypeDropdown(
          value: _engineType,
          onChanged: (v) => setState(() => _engineType = v ?? 'Gasoline'),
        ),
        GapWidgets.h16,
        FuelTypeDropdown(
          value: _fuelType,
          onChanged: (v) => setState(() => _fuelType = v ?? 'Regular'),
        ),
        GapWidgets.h16,
        Row(
          children: [
            Expanded(
              child: AppTextFormField(
                fieldController: _colorCtrl,
                fieldValidator: (_) => null,
                label: 'Color',
              ),
            ),
            GapWidgets.w16,
            Expanded(
              child: AppTextFormField(
                fieldController: _plateCtrl,
                fieldValidator: validatePlate,
                label: 'Plate',
              ),
            ),
          ],
        ),
        GapWidgets.h16,
        OwnershipStatusDropdown(
          value: _ownershipStatus,
          onChanged: (v) => setState(() => _ownershipStatus = v ?? 'Owned'),
        ),
      ];

  List<Widget> _identityReadOnlyFields(Automobile orig) => [
        _readOnlyRow('VIN', orig.vin ?? 'N/A'),
        _readOnlyRow('Maker', orig.maker ?? 'N/A'),
        _readOnlyRow('Brand', orig.brand ?? 'N/A'),
        _readOnlyRow('Model', orig.model ?? 'N/A'),
        _readOnlyRow('Trim', orig.trim ?? 'N/A'),
        _readOnlyRow('Year', orig.year > 0 ? '${orig.year}' : 'N/A'),
        _readOnlyRow('Engine', orig.engineType ?? 'N/A'),
        _readOnlyRow('Fuel', orig.fuelType ?? 'N/A'),
        _readOnlyRow('Color', orig.color ?? 'N/A'),
        _readOnlyRow('Plate', orig.plate ?? 'N/A'),
        _readOnlyRow('Ownership', orig.ownershipStatus ?? 'N/A'),
      ];

  // -------------------- Helpers --------------------

  String _formatDate(DateTime d) =>
      '${d.month}/${d.day}/${d.year}';

  Widget _readOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _optionalDatePicker(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (date != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                ),
              const Icon(Icons.calendar_today),
              const SizedBox(width: 12),
            ],
          ),
        ),
        child: Text(
          date != null ? _formatDate(date) : 'Not set',
          style: TextStyle(
            color: date != null
                ? null
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Long-press handler on the read-only identity section. Shows a
  /// confirmation dialog explaining the consequences and unlocks the
  /// fields on confirm. Mirrors the iOS HIG "destructive but recoverable"
  /// pattern.
  Future<void> _confirmUnlockImmutables(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit vehicle identity?'),
        content: const Text(
          'VIN, maker, brand, model, year, engine, and fuel type normally '
          'do not change. Edit these only to correct a typo from when the '
          'vehicle was added.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => _immutableUnlocked = true);
    }
  }

  /// Build audit entries for the identity-field deltas between [orig] and
  /// the supplied new-values map. Year is normalised to a string so the
  /// before/after columns are comparable.
  List<AutomobileAuditEntry> _diffIdentity(
      Automobile orig, Map<String, Object?> newVals) {
    final actor = ref.read(currentUserProvider)?.uid;
    final now = DateTime.now().toUtc();

    String? str(Object? v) {
      if (v == null) return null;
      final s = v is int ? '$v' : v.toString();
      return s.isEmpty ? null : s;
    }

    final pairs = <String, String?>{
      'vin': str(orig.vin),
      'maker': str(orig.maker),
      'brand': str(orig.brand),
      'model': str(orig.model),
      'trim': str(orig.trim),
      'year': orig.year > 0 ? '${orig.year}' : null,
      'engineType': str(orig.engineType),
      'fuelType': str(orig.fuelType),
      'color': str(orig.color),
      'plate': str(orig.plate),
      'ownershipStatus': str(orig.ownershipStatus),
    };

    final out = <AutomobileAuditEntry>[];
    pairs.forEach((field, oldVal) {
      final newVal = str(newVals[field]);
      if (oldVal != newVal) {
        out.add(AutomobileAuditEntry(
          timestamp: now,
          field: field,
          oldValue: oldVal,
          newValue: newVal,
          actor: actor,
        ));
      }
    });
    return out;
  }

  List<Widget> _buildAuditList(
      BuildContext context, List<AutomobileAuditEntry> entries) {
    final sorted = [...entries]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final theme = Theme.of(context);
    return sorted.map((e) {
      final ts = e.timestamp.toLocal();
      final stamp =
          '${ts.year}-${'${ts.month}'.padLeft(2, '0')}-${'${ts.day}'.padLeft(2, '0')} '
          '${'${ts.hour}'.padLeft(2, '0')}:${'${ts.minute}'.padLeft(2, '0')}';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${e.field}  ${e.oldValue ?? '∅'}  →  ${e.newValue ?? '∅'}',
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              stamp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

/// Result of the photo bottom-sheet — kept narrow so the caller's
/// switch is exhaustive.
enum _PhotoAction { pick, remove }
