import 'package:flutter/material.dart';

/// Card that flips between a read-only "info" view and an editor on demand.
///
/// Default state shows [displayBuilder] with an edit pencil in the top
/// right. Tapping the pencil swaps the body for [editorBuilder] and
/// reveals an inline "Cancel / Save changes" row. Save/Cancel are local
/// to this card — the parent passes [onSave] (async, returns true if the
/// commit succeeded) and [onCancel] (resets parent-owned pending state).
class EditableInfoCard extends StatefulWidget {
  const EditableInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.displayBuilder,
    required this.editorBuilder,
    required this.onSave,
    required this.onCancel,
  });

  final IconData icon;
  final String title;
  final WidgetBuilder displayBuilder;
  final WidgetBuilder editorBuilder;

  /// Returns `true` when the commit succeeded — the card flips back to
  /// display mode. Returning `false` keeps the editor open so the parent
  /// can surface a validation/snackbar error.
  final Future<bool> Function() onSave;

  /// Called when the user discards the in-flight edit. The parent should
  /// reset its controllers / pending state to the original values.
  final VoidCallback onCancel;

  @override
  State<EditableInfoCard> createState() => _EditableInfoCardState();
}

class _EditableInfoCardState extends State<EditableInfoCard> {
  bool _editing = false;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.onSave();
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editing = false;
    });
  }

  void _cancel() {
    widget.onCancel();
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (!_editing)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => setState(() => _editing = true),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_editing)
              widget.editorBuilder(context)
            else
              widget.displayBuilder(context),
            if (_editing) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : _cancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving...' : 'Save changes'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
