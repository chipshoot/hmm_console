import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/gas_station.dart';
import '../../states/gas_stations_state.dart';

class GasStationFormDialog extends ConsumerStatefulWidget {
  const GasStationFormDialog({super.key, this.initialName, this.station});

  /// Pre-fill name for create mode (from dropdown text).
  final String? initialName;

  /// Existing station for edit mode. If non-null, dialog is in edit mode.
  final GasStation? station;

  @override
  ConsumerState<GasStationFormDialog> createState() =>
      _GasStationFormDialogState();
}

class _GasStationFormDialogState extends ConsumerState<GasStationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _zipCodeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _isSubmitting = false;

  bool get _isEditing => widget.station != null;

  @override
  void initState() {
    super.initState();
    if (widget.station != null) {
      final s = widget.station!;
      _nameCtrl.text = s.name;
      _addressCtrl.text = s.address ?? '';
      _cityCtrl.text = s.city ?? '';
      _stateCtrl.text = s.state ?? '';
      _countryCtrl.text = s.country ?? '';
      _zipCodeCtrl.text = s.zipCode ?? '';
      _descriptionCtrl.text = s.description ?? '';
    } else if (widget.initialName != null) {
      _nameCtrl.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    _zipCodeCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final station = GasStation(
        id: widget.station?.id,
        name: _nameCtrl.text.trim(),
        address:
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
        country:
            _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
        zipCode:
            _zipCodeCtrl.text.trim().isEmpty ? null : _zipCodeCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
      );

      final notifier = ref.read(gasStationsStateProvider.notifier);
      final GasStation result;
      if (_isEditing) {
        result = await notifier.updateStation(widget.station!.id!, station);
      } else {
        result = await notifier.createStation(station);
      }

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        final action = _isEditing ? 'update' : 'create';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to $action station: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Gas Station' : 'Add Gas Station';
    final submitLabel = _isEditing ? 'Save' : 'Add Station';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_gas_station),
                      const SizedBox(width: 8),
                      Text(title,
                          style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Station Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Station name is required';
                      }
                      if (v.trim().length > 100) {
                        return 'Name must be 100 characters or less';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v != null && v.length > 200
                        ? 'Max 200 characters'
                        : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'City *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'City is required';
                            }
                            if (v.trim().length > 50) {
                              return 'Max 50 characters';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'State/Province',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v != null && v.length > 50
                              ? 'Max 50 characters'
                              : null,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _countryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Country *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Country is required';
                            }
                            if (v.trim().length > 50) {
                              return 'Max 50 characters';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _zipCodeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Zip/Postal Code',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v != null && v.length > 20
                              ? 'Max 20 characters'
                              : null,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    validator: (v) => v != null && v.length > 500
                        ? 'Max 500 characters'
                        : null,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(submitLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
