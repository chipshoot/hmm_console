import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/gaps.dart';
import '../../../../core/widgets/numeric_input.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../../auth/providers/current_user_provider.dart';
import '../../domain/entities/automobile.dart';
import '../../../settings/providers/gas_log_settings_provider.dart';
import '../../domain/validators/automobile_validator.dart';
import '../../states/automobiles_state.dart';
import '../../states/update_automobile_state.dart';
import '../widgets/engine_type_dropdown.dart';
import '../widgets/fuel_type_dropdown.dart';
import '../widgets/ownership_status_dropdown.dart';

class AutomobileEditScreen extends ConsumerStatefulWidget {
  final int automobileId;

  const AutomobileEditScreen({super.key, required this.automobileId});

  @override
  ConsumerState<AutomobileEditScreen> createState() =>
      _AutomobileEditScreenState();
}

class _AutomobileEditScreenState extends ConsumerState<AutomobileEditScreen>
    with AutomobileValidator {
  final _formKey = GlobalKey<FormState>();

  // Normally-immutable identity fields. Hidden long-press on the section
  // header unlocks editing for typo correction; otherwise read-only.
  bool _immutableUnlocked = false;
  final _vinCtrl = TextEditingController();
  final _makerCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _trimCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  String _engineType = 'Gasoline';
  String _fuelType = 'Regular';

  // Mutable fields
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _meterReadingCtrl = TextEditingController();
  String _ownershipStatus = 'Owned';

  // Insurance
  final _insuranceProviderCtrl = TextEditingController();
  final _insurancePolicyCtrl = TextEditingController();
  DateTime? _insuranceExpiryDate;
  DateTime? _registrationExpiryDate;

  // Service
  DateTime? _lastServiceDate;
  final _lastServiceMeterCtrl = TextEditingController();
  DateTime? _nextServiceDueDate;
  final _nextServiceDueMeterCtrl = TextEditingController();

  // Notes
  final _notesCtrl = TextEditingController();

  Automobile? _original;

  @override
  void initState() {
    super.initState();
    _populateForm();
  }

  void _populateForm() {
    final data = ref.read(automobilesStateProvider).value;
    if (data == null) return;

    final auto =
        data.where((a) => a.id == widget.automobileId).firstOrNull;
    if (auto == null) return;

    _original = auto;
    _vinCtrl.text = auto.vin ?? '';
    _makerCtrl.text = auto.maker ?? '';
    _brandCtrl.text = auto.brand ?? '';
    _modelCtrl.text = auto.model ?? '';
    _trimCtrl.text = auto.trim ?? '';
    _yearCtrl.text = auto.year > 0 ? '${auto.year}' : '';
    _engineType = auto.engineType ?? 'Gasoline';
    _fuelType = auto.fuelType ?? 'Regular';
    _colorCtrl.text = auto.color ?? '';
    _plateCtrl.text = auto.plate ?? '';
    _meterReadingCtrl.text = auto.meterReading.toString();
    _ownershipStatus = auto.ownershipStatus ?? 'Owned';
    _insuranceProviderCtrl.text = auto.insuranceProvider ?? '';
    _insurancePolicyCtrl.text = auto.insurancePolicyNumber ?? '';
    _insuranceExpiryDate = auto.insuranceExpiryDate;
    _registrationExpiryDate = auto.registrationExpiryDate;
    _lastServiceDate = auto.lastServiceDate;
    _lastServiceMeterCtrl.text =
        auto.lastServiceMeterReading?.toString() ?? '';
    _nextServiceDueDate = auto.nextServiceDueDate;
    _nextServiceDueMeterCtrl.text =
        auto.nextServiceDueMeterReading?.toString() ?? '';
    _notesCtrl.text = auto.notes ?? '';
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
    _insuranceProviderCtrl.dispose();
    _insurancePolicyCtrl.dispose();
    _lastServiceMeterCtrl.dispose();
    _nextServiceDueMeterCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateAutomobileStateProvider);
    final isLoading = updateState.isLoading;

    final settings = ref.watch(gasLogSettingsProvider);
    final distLabel = settings.distanceUnit.label;

    ref.listen<AsyncValue<void>>(updateAutomobileStateProvider, (_, next) {
      if (next.hasValue && !next.isLoading && !next.isRefreshing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle updated')),
        );
        context.pop();
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
        title: 'Edit Vehicle',
        child: const Center(child: Text('Vehicle not found')),
      );
    }

    final orig = _original!;

    return CommonScreenScaffold(
      title: 'Edit Vehicle',
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Normally-immutable identity fields ---
              // Long-press anywhere on this section to open the
              // edit-confirmation popup. Hidden by design — this is for
              // correcting typos at creation time, not for casual edits,
              // so discoverability is intentionally low. The behaviour
              // mirrors GitHub repo rename / Apple Watch settings: friction
              // proportional to consequences.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: _immutableUnlocked
                    ? null
                    : () => _confirmUnlockImmutables(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle(
                      context,
                      _immutableUnlocked
                          ? 'Vehicle Info'
                          : 'Vehicle Info (read-only)',
                    ),
                    if (!_immutableUnlocked) ...[
                      GapWidgets.h4,
                      Text(
                        'Hold to edit',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ],
                    GapWidgets.h8,
                    if (_immutableUnlocked) ...[
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
                        onChanged: (v) =>
                            setState(() => _engineType = v ?? 'Gasoline'),
                      ),
                      GapWidgets.h16,
                      FuelTypeDropdown(
                        value: _fuelType,
                        onChanged: (v) =>
                            setState(() => _fuelType = v ?? 'Regular'),
                      ),
                    ] else ...[
                      _readOnlyField('VIN', orig.vin ?? 'N/A'),
                      _readOnlyField('Maker', orig.maker ?? 'N/A'),
                      _readOnlyField('Brand', orig.brand ?? 'N/A'),
                      _readOnlyField('Model', orig.model ?? 'N/A'),
                      _readOnlyField('Trim', orig.trim ?? 'N/A'),
                      _readOnlyField(
                          'Year', orig.year > 0 ? '${orig.year}' : 'N/A'),
                      _readOnlyField('Engine', orig.engineType ?? 'N/A'),
                      _readOnlyField('Fuel', orig.fuelType ?? 'N/A'),
                    ],
                  ],
                ),
              ),
              GapWidgets.h24,

              // --- Mutable fields ---
              _sectionTitle(context, 'Editable Details'),
              GapWidgets.h8,
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
              AppTextFormField(
                fieldController: _meterReadingCtrl,
                fieldValidator: validateMeterReading,
                label: 'Meter Reading ($distLabel)',
                keyboardType: NumericInput.integer.keyboardType,
                inputFormatters: NumericInput.integer.formatters,
              ),
              GapWidgets.h16,
              OwnershipStatusDropdown(
                value: _ownershipStatus,
                onChanged: (v) =>
                    setState(() => _ownershipStatus = v ?? 'Owned'),
              ),
              GapWidgets.h24,

              // --- Insurance & Registration ---
              _sectionTitle(context, 'Insurance & Registration'),
              GapWidgets.h8,
              AppTextFormField(
                fieldController: _insuranceProviderCtrl,
                fieldValidator: (_) => null,
                label: 'Insurance Provider (optional)',
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _insurancePolicyCtrl,
                fieldValidator: (_) => null,
                label: 'Policy Number (optional)',
              ),
              GapWidgets.h16,
              _optionalDatePicker(
                context,
                label: 'Insurance Expiry',
                date: _insuranceExpiryDate,
                onChanged: (d) =>
                    setState(() => _insuranceExpiryDate = d),
              ),
              GapWidgets.h16,
              _optionalDatePicker(
                context,
                label: 'Registration Expiry',
                date: _registrationExpiryDate,
                onChanged: (d) =>
                    setState(() => _registrationExpiryDate = d),
              ),
              GapWidgets.h24,

              // --- Service ---
              _sectionTitle(context, 'Service'),
              GapWidgets.h8,
              _optionalDatePicker(
                context,
                label: 'Last Service Date',
                date: _lastServiceDate,
                onChanged: (d) => setState(() => _lastServiceDate = d),
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _lastServiceMeterCtrl,
                fieldValidator: validateMeterReading,
                label: 'Last Service Meter ($distLabel)',
                keyboardType: NumericInput.integer.keyboardType,
                inputFormatters: NumericInput.integer.formatters,
              ),
              GapWidgets.h16,
              _optionalDatePicker(
                context,
                label: 'Next Service Due',
                date: _nextServiceDueDate,
                onChanged: (d) =>
                    setState(() => _nextServiceDueDate = d),
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _nextServiceDueMeterCtrl,
                fieldValidator: validateMeterReading,
                label: 'Next Service Meter ($distLabel)',
                keyboardType: NumericInput.integer.keyboardType,
                inputFormatters: NumericInput.integer.formatters,
              ),
              GapWidgets.h24,

              // --- Notes ---
              _sectionTitle(context, 'Notes'),
              GapWidgets.h8,
              AppTextFormField(
                fieldController: _notesCtrl,
                fieldValidator: (_) => null,
                label: 'Notes (optional)',
              ),
              GapWidgets.h24,

              if (orig.auditLog.isNotEmpty) ...[
                _sectionTitle(context, 'Change history'),
                GapWidgets.h8,
                ..._buildAuditList(context, orig.auditLog),
                GapWidgets.h24,
              ],

              HighlightButton(
                text: isLoading ? 'Saving...' : 'Save Changes',
                onPressed: isLoading ? () {} : _submit,
              ),
              GapWidgets.h24,
            ],
          ),
        ),
        ),
      ),
    );
  }

  /// Render the per-vehicle audit log (newest first). Each row shows the
  /// field name, old → new value, and a short timestamp. Actor is hidden
  /// today since this is a single-user device — when multi-user gets
  /// added we can surface it.
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

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
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
        if (picked != null) {
          onChanged(picked);
        }
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
          date != null
              ? '${date.month}/${date.day}/${date.year}'
              : 'Not set',
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
  /// fields on confirm. The popup intentionally mirrors the iOS HIG
  /// "destructive but recoverable" pattern.
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final orig = _original!;
    final newVin = _immutableUnlocked
        ? (_vinCtrl.text.isNotEmpty ? _vinCtrl.text : null)
        : orig.vin;
    final newMaker = _immutableUnlocked
        ? (_makerCtrl.text.isNotEmpty ? _makerCtrl.text : null)
        : orig.maker;
    final newBrand = _immutableUnlocked
        ? (_brandCtrl.text.isNotEmpty ? _brandCtrl.text : null)
        : orig.brand;
    final newModel = _immutableUnlocked
        ? (_modelCtrl.text.isNotEmpty ? _modelCtrl.text : null)
        : orig.model;
    final newTrim = _immutableUnlocked
        ? (_trimCtrl.text.isNotEmpty ? _trimCtrl.text : null)
        : orig.trim;
    final newYear = _immutableUnlocked
        ? (int.tryParse(_yearCtrl.text) ?? orig.year)
        : orig.year;
    final newEngine = _immutableUnlocked ? _engineType : orig.engineType;
    final newFuel = _immutableUnlocked ? _fuelType : orig.fuelType;

    // Capture an audit entry per identity-field change. Only runs while
    // the section is unlocked — normal mutable field edits (color, plate,
    // meter, …) aren't audited because changing them is the expected use
    // of this screen.
    final auditAdditions = _immutableUnlocked
        ? _diffIdentity(orig, {
            'vin': newVin,
            'maker': newMaker,
            'brand': newBrand,
            'model': newModel,
            'trim': newTrim,
            'year': newYear == 0 ? null : '$newYear',
            'engineType': newEngine,
            'fuelType': newFuel,
          })
        : const <AutomobileAuditEntry>[];

    final updated = Automobile(
      id: orig.id,
      vin: newVin,
      maker: newMaker,
      brand: newBrand,
      model: newModel,
      trim: newTrim,
      year: newYear,
      color: _colorCtrl.text.isNotEmpty ? _colorCtrl.text : null,
      plate: _plateCtrl.text.isNotEmpty ? _plateCtrl.text : null,
      engineType: newEngine,
      fuelType: newFuel,
      fuelTankCapacity: orig.fuelTankCapacity,
      cityMPG: orig.cityMPG,
      highwayMPG: orig.highwayMPG,
      combinedMPG: orig.combinedMPG,
      meterReading: int.tryParse(_meterReadingCtrl.text) ?? orig.meterReading,
      purchaseMeterReading: orig.purchaseMeterReading,
      purchaseDate: orig.purchaseDate,
      purchasePrice: orig.purchasePrice,
      ownershipStatus: _ownershipStatus,
      isActive: orig.isActive,
      soldDate: orig.soldDate,
      soldMeterReading: orig.soldMeterReading,
      soldPrice: orig.soldPrice,
      registrationExpiryDate: _registrationExpiryDate,
      insuranceExpiryDate: _insuranceExpiryDate,
      insuranceProvider: _insuranceProviderCtrl.text.isNotEmpty
          ? _insuranceProviderCtrl.text
          : null,
      insurancePolicyNumber: _insurancePolicyCtrl.text.isNotEmpty
          ? _insurancePolicyCtrl.text
          : null,
      lastServiceDate: _lastServiceDate,
      lastServiceMeterReading:
          int.tryParse(_lastServiceMeterCtrl.text),
      nextServiceDueDate: _nextServiceDueDate,
      nextServiceDueMeterReading:
          int.tryParse(_nextServiceDueMeterCtrl.text),
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      auditLog: [...orig.auditLog, ...auditAdditions],
    );

    ref
        .read(updateAutomobileStateProvider.notifier)
        .updateAutomobile(widget.automobileId, updated);
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
}
