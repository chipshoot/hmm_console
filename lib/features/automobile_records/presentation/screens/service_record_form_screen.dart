import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      _tax = record.tax;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
    if (widget.isEdit) {
      await notifier.edit(widget.automobileId, _existing!.id, record);
    } else {
      await notifier.create(widget.automobileId, record);
    }
  }
}
