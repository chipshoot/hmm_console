import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_error_message.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../../../core/data/repository_providers.dart';
import '../../domain/entities/auto_scheduled_service.dart';
import '../../domain/entities/service_type.dart';
import '../../states/_records_automobile_id_provider.dart';
import '../../states/mutate_scheduled_service_state.dart';
import '../widgets/optional_date_picker.dart';
import '../widgets/service_type_dropdown.dart';

class ScheduledServiceFormScreen extends ConsumerStatefulWidget {
  const ScheduledServiceFormScreen({
    super.key,
    required this.automobileId,
    this.scheduleId,
  });

  final int automobileId;
  final int? scheduleId;

  bool get isEdit => scheduleId != null;

  @override
  ConsumerState<ScheduledServiceFormScreen> createState() =>
      _ScheduledServiceFormScreenState();
}

class _ScheduledServiceFormScreenState
    extends ConsumerState<ScheduledServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _intervalDaysCtrl = TextEditingController();
  final _intervalMileageCtrl = TextEditingController();
  final _nextDueMileageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  ServiceType _type = ServiceType.oilChange;
  DateTime? _nextDueDate;
  bool _isActive = true;

  bool _loading = false;
  AutoScheduledService? _existing;

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
      final s = await ref
          .read(scheduledServiceRepositoryModeProvider)
          .getScheduleById(widget.automobileId, widget.scheduleId!);
      _existing = s;
      _nameCtrl.text = s.name;
      _intervalDaysCtrl.text = s.intervalDays?.toString() ?? '';
      _intervalMileageCtrl.text = s.intervalMileage?.toString() ?? '';
      _nextDueMileageCtrl.text = s.nextDueMileage?.toString() ?? '';
      _notesCtrl.text = s.notes ?? '';
      _type = s.type;
      _nextDueDate = s.nextDueDate;
      _isActive = s.isActive;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _intervalDaysCtrl.dispose();
    _intervalMileageCtrl.dispose();
    _nextDueMileageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(mutateScheduledServiceStateProvider).isLoading;

    ref.listen<AsyncValue<void>>(mutateScheduledServiceStateProvider,
        (_, next) {
      if (next.hasValue && !next.isLoading && !next.isRefreshing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                widget.isEdit ? 'Schedule updated' : 'Schedule added'),
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
      title: widget.isEdit ? 'Edit Schedule' : 'Add Schedule',
      child: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextFormField(
                      fieldController: _nameCtrl,
                      fieldValidator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      label: 'Name',
                    ),
                    const SizedBox(height: 16),
                    ServiceTypeDropdown(
                      value: _type,
                      onChanged: (v) => setState(() => _type = v),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextFormField(
                            fieldController: _intervalDaysCtrl,
                            fieldValidator: _validateOptionalInt,
                            label: 'Every N days',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppTextFormField(
                            fieldController: _intervalMileageCtrl,
                            fieldValidator: _validateOptionalInt,
                            label: 'Every N miles',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OptionalDatePicker(
                      label: 'Next due date',
                      date: _nextDueDate,
                      onChanged: (d) => setState(() => _nextDueDate = d),
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _nextDueMileageCtrl,
                      fieldValidator: _validateOptionalInt,
                      label: 'Next due mileage',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Active'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
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
                          : (widget.isEdit ? 'Save Changes' : 'Add Schedule'),
                      onPressed: saving ? () {} : _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String? _validateOptionalInt(String? v) {
    if (v == null || v.isEmpty) return null;
    final n = int.tryParse(v);
    if (n == null || n <= 0) return 'Must be > 0';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final intervalDays = _intervalDaysCtrl.text.trim().isEmpty
        ? null
        : int.parse(_intervalDaysCtrl.text);
    final intervalMileage = _intervalMileageCtrl.text.trim().isEmpty
        ? null
        : int.parse(_intervalMileageCtrl.text);
    if (intervalDays == null && intervalMileage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Set at least one interval (days or mileage)')),
      );
      return;
    }

    final schedule = AutoScheduledService(
      id: _existing?.id ?? 0,
      automobileId: widget.automobileId,
      name: _nameCtrl.text.trim(),
      type: _type,
      intervalDays: intervalDays,
      intervalMileage: intervalMileage,
      nextDueDate: _nextDueDate,
      nextDueMileage: _nextDueMileageCtrl.text.trim().isEmpty
          ? null
          : int.parse(_nextDueMileageCtrl.text),
      isActive: _isActive,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    final notifier = ref.read(mutateScheduledServiceStateProvider.notifier);
    if (widget.isEdit) {
      await notifier.edit(widget.automobileId, _existing!.id, schedule);
    } else {
      await notifier.create(widget.automobileId, schedule);
    }
  }
}
