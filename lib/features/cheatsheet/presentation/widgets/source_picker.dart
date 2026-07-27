import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/repository_providers.dart';
import '../../../notes/data/models/hmm_note.dart';
import '../../domain/entities/cheatsheet_source.dart';
import '../../domain/note_piece_extractor.dart';

/// Every note the picker can bind to.
///
/// Pages until exhausted rather than taking a first page: a cap here would
/// quietly make some notes unbindable, with nothing on screen to say so.
///
/// The whole set is held in memory so search covers *all* notes rather than
/// only the pages scrolled so far — correct for a personal-scale store. If a
/// vault ever grows past comfortable, the replacement is repository-side
/// search, not a smaller page limit.
final cheatsheetSourceNotesProvider =
    FutureProvider<List<HmmNote>>((ref) async {
  final repo = ref.watch(hmmNoteRepositoryProvider);
  const pageSize = 100;
  final out = <HmmNote>[];
  var page = 1;
  while (true) {
    final res = await repo.getNotes(page: page, pageSize: pageSize);
    out.addAll(res.items);
    if (res.items.isEmpty || page >= res.meta.totalPages) break;
    page++;
  }
  return out;
});

/// Two-step chooser: pick a note, then pick which piece of it to show.
///
/// Reports through [onSelected] rather than popping itself, so it can be
/// hosted in a sheet, a dialog or a test harness. [showSourcePicker] is the
/// sheet wrapper.
class SourcePicker extends ConsumerStatefulWidget {
  const SourcePicker({super.key, required this.onSelected});

  final ValueChanged<CheatsheetSource> onSelected;

  @override
  ConsumerState<SourcePicker> createState() => _SourcePickerState();
}

class _SourcePickerState extends ConsumerState<SourcePicker> {
  String _query = '';
  HmmNote? _note;

  void _select(SourceGranularity kind, String? locator) {
    widget.onSelected(CheatsheetSource(
      noteUuid: _note!.uuid,
      kind: kind,
      locator: locator,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(cheatsheetSourceNotesProvider);
    return SafeArea(
      child: notes.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load notes: $e'),
        ),
        data: (all) =>
            _note == null ? _noteStep(all) : _granularityStep(context, _note!),
      ),
    );
  }

  Widget _noteStep(List<HmmNote> all) {
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? all
        : all.where((n) => n.subject.toLowerCase().contains(q)).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: const Key('source-picker-search'),
            decoration: const InputDecoration(
              hintText: 'Search notes',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (all.isEmpty)
          const Padding(
            key: Key('source-picker-empty'),
            padding: EdgeInsets.all(24),
            child: Text('No notes to reference yet.'),
          )
        else if (matches.isEmpty)
          const Padding(
            key: Key('source-picker-no-matches'),
            padding: EdgeInsets.all(24),
            child: Text('No notes match that search.'),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: matches.length,
              itemBuilder: (context, i) {
                final n = matches[i];
                return ListTile(
                  key: Key('source-note-${n.uuid}'),
                  title: Text(n.subject),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _note = n),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _granularityStep(BuildContext context, HmmNote n) {
    final fields = NotePieceExtractor.fieldPaths(n.content);
    final headings =
        NotePieceExtractor.sectionHeadings(n.description ?? n.content);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: IconButton(
            key: const Key('source-picker-back'),
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _note = null),
          ),
          title: Text(n.subject),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              if (fields.isNotEmpty) const _SectionLabel('Fields'),
              for (final path in fields)
                ListTile(
                  key: Key('granularity-field-$path'),
                  title: Text(path),
                  onTap: () => _select(SourceGranularity.field, path),
                ),
              if (headings.isNotEmpty) const _SectionLabel('Sections'),
              for (final h in headings)
                ListTile(
                  key: Key('granularity-section-$h'),
                  title: Text(h),
                  onTap: () => _select(SourceGranularity.section, h),
                ),
              const _SectionLabel('Whole note'),
              ListTile(
                key: const Key('granularity-whole'),
                title: const Text('The whole note'),
                onTap: () => _select(SourceGranularity.whole, null),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
}

/// Presents [SourcePicker] as a modal sheet, completing with the chosen
/// source (or null if dismissed).
Future<CheatsheetSource?> showSourcePicker(BuildContext context) =>
    showModalBottomSheet<CheatsheetSource>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SourcePicker(
        onSelected: (source) => Navigator.of(sheetContext).pop(source),
      ),
    );
