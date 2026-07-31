import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cheatsheet_templates.dart';
import '../../domain/entities/cheatsheet_card.dart';
import '../../domain/entities/cheatsheet_source.dart';
import '../../states/cheatsheet_editor_state.dart';
import '../../states/cheatsheets_state.dart';
import '../widgets/source_picker.dart';

/// The binding step, behind a seam so widget tests never open a real sheet.
final cheatsheetSourcePickerProvider =
    Provider<Future<CheatsheetSource?> Function(BuildContext)>(
  (ref) => showSourcePicker,
);

/// Create (`cardId == null`) or edit (`cardId` given) one card.
///
/// Editing **loads** the existing card into the editor rather than starting a
/// fresh one, so its id — and therefore its stored note — carries through the
/// save instead of a second card appearing.
class CheatsheetDesignerScreen extends ConsumerStatefulWidget {
  const CheatsheetDesignerScreen({super.key, this.cardId});

  final String? cardId;

  @override
  ConsumerState<CheatsheetDesignerScreen> createState() =>
      _CheatsheetDesignerScreenState();
}

class _CheatsheetDesignerScreenState
    extends ConsumerState<CheatsheetDesignerScreen> {
  final _title = TextEditingController();
  final _walletGroup = TextEditingController();
  final _newRowLabel = TextEditingController();

  /// Which card the text controllers currently mirror — resyncing on every
  /// build would fight the user's typing.
  String? _syncedId;
  bool _loaded = false;
  bool _saving = false;

  /// Whether a template has been chosen *during this visit*.
  ///
  /// Deliberately screen-local rather than inferred from the editor's state:
  /// that provider outlives the screen, so a card left in it after a save
  /// would make the next "new card" look already-started — skipping the
  /// template chooser and then saving under the previous card's id,
  /// overwriting it. Resetting the provider in initState is not an option;
  /// Riverpod forbids mutating a provider from a widget life-cycle.
  bool _started = false;

  @override
  void dispose() {
    _title.dispose();
    _walletGroup.dispose();
    _newRowLabel.dispose();
    super.dispose();
  }

  CheatsheetEditor get _editor => ref.read(cheatsheetEditorProvider.notifier);

  @override
  Widget build(BuildContext context) {
    if (widget.cardId != null && !_loaded) return _loadExisting(widget.cardId!);

    final card = ref.watch(cheatsheetEditorProvider);
    // Create mode always begins at the chooser, whatever the editor happens
    // to be holding from a previous card.
    if (widget.cardId == null && !_started) return _templateChooser();

    if (_syncedId != card.id) {
      _syncedId = card.id;
      _title.text = card.title;
      _walletGroup.text = card.walletGroup;
    }
    return _form(card);
  }

  Widget _loadExisting(String id) {
    final cards = ref.watch(cheatsheetsStateProvider);
    return cards.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (list) {
        CheatsheetCard? found;
        for (final c in list) {
          if (c.id == id) found = c;
        }
        if (found == null) {
          return const Scaffold(
            body: Center(
              key: Key('designer-not-found'),
              child: Text('That cheatsheet no longer exists.'),
            ),
          );
        }
        // Mutating a provider during build is illegal; adopt on the next frame.
        final existing = found;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _editor.load(existing);
          setState(() => _loaded = true);
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  Widget _templateChooser() => Scaffold(
        appBar: AppBar(title: const Text('New cheatsheet')),
        body: ListView(
          children: [
            for (final t in CheatsheetTemplates.all)
              ListTile(
                key: Key('template-${t.id}'),
                title: Text(t.title),
                subtitle: Text(
                  t.rowLabels.isEmpty
                      ? 'Start empty'
                      : t.rowLabels.take(4).join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // startFromTemplate mints a fresh id, replacing whatever the
                  // editor held.
                  _editor.startFromTemplate(t.id);
                  setState(() => _started = true);
                },
              ),
          ],
        ),
      );

  Future<void> _bind(int index) async {
    final source = await ref.read(cheatsheetSourcePickerProvider)(context);
    if (source != null) _editor.bindRow(index, source);
  }

  Future<void> _save() async {
    // The upsert is a read-then-write with no uniqueness constraint behind
    // it, so two in-flight saves of a new card can both decide to create and
    // leave two notes sharing one card id.
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _editor.commit();
      // Don't leave the saved card sitting in a provider that outlives this
      // screen. Safe here — a callback, not a widget life-cycle.
      _editor.reset();
      if (mounted) await Navigator.of(context).maybePop();
    } catch (e) {
      // Losing a card the user just filled in must not look like success.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save this cheatsheet: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _form(CheatsheetCard card) => Scaffold(
        appBar: AppBar(
          title: Text(widget.cardId == null ? 'New cheatsheet' : 'Edit'),
          actions: [
            TextButton(
              key: const Key('designer-save'),
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('designer-title'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              onChanged: _editor.setTitle,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('designer-wallet-group'),
              controller: _walletGroup,
              decoration: const InputDecoration(labelText: 'Wallet group'),
              onChanged: _editor.setWalletGroup,
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < card.rows.length; i++) _rowTile(card, i),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('designer-new-row'),
                    controller: _newRowLabel,
                    decoration: const InputDecoration(labelText: 'New row'),
                  ),
                ),
                IconButton(
                  key: const Key('designer-add-row'),
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final label = _newRowLabel.text.trim();
                    if (label.isEmpty) return;
                    _editor.addRow(label);
                    _newRowLabel.clear();
                  },
                ),
              ],
            ),
          ],
        ),
      );

  Widget _rowTile(CheatsheetCard card, int i) {
    final row = card.rows[i];
    final source = row.source;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(row.label)),
                IconButton(
                  key: Key('row-$i-remove'),
                  icon: const Icon(Icons.close),
                  onPressed: () => _editor.removeRow(i),
                ),
              ],
            ),
            InkWell(
              key: Key('row-$i-bind'),
              onTap: () => _bind(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  source == null ? 'Tap to bind' : _summarize(source),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final action in ValueAction.values)
                  ChoiceChip(
                    key: Key('row-$i-action-${action.name}'),
                    label: Text(_actionLabel(action)),
                    selected: row.valueAction == action,
                    onSelected: (_) => _editor.setValueAction(i, action),
                  ),
                FilterChip(
                  key: Key('row-$i-open-source'),
                  label: const Text('Open source'),
                  selected: row.openSource,
                  onSelected: (v) => _editor.setOpenSource(i, v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _actionLabel(ValueAction a) => switch (a) {
        ValueAction.none => 'No action',
        ValueAction.call => 'Call',
        ValueAction.map => 'Map',
      };

  static String _summarize(CheatsheetSource s) => switch (s.kind) {
        SourceGranularity.field => 'Field · ${s.locator}',
        SourceGranularity.section => 'Section · ${s.locator}',
        SourceGranularity.whole => 'Whole note',
      };
}
