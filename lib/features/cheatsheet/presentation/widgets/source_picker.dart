import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/repository_providers.dart';
import '../../../notes/data/models/hmm_note.dart';
import '../../domain/entities/cheatsheet_source.dart';
import '../../domain/note_piece_extractor.dart';
import '../../domain/source_scope.dart';

/// Catalog id → catalog name, so the picker can tell a vehicle note from a
/// grocery list — and either from one of the app's own bookkeeping notes.
///
/// [HmmNote] carries only a catalog *id*; the scoping rules are written against
/// names, because names are what stays stable across devices (ids are assigned
/// per-device by `getOrCreateCatalog`).
final cheatsheetSourceCatalogNamesProvider =
    FutureProvider.autoDispose<Map<int, String>>((ref) async {
  final catalogs = await ref.watch(noteCatalogRepositoryProvider).getCatalogs();
  return {for (final c in catalogs) c.id: c.name};
});

/// The notes this card can bind to, ranked for its template.
///
/// Pages until exhausted rather than taking a first page: a cap here would
/// quietly make some notes unbindable, with nothing on screen to say so.
///
/// The whole set is held in memory so search covers *all* notes rather than
/// only the pages scrolled so far — correct for a personal-scale store. If a
/// vault ever grows past comfortable, the replacement is repository-side
/// search, not a smaller page limit.
///
/// Fetching every catalog and ranking afterwards, rather than querying one
/// catalog, is deliberate: `scopeSourceNotes` keeps out-of-domain notes
/// reachable, and a `catalogId` filter on the query could not.
///
/// `autoDispose` so each picker session re-reads: cached for the app's
/// lifetime, a note written after the picker first opened would stay
/// unbindable until restart, with nothing on screen explaining why.
final cheatsheetSourceNotesProvider = FutureProvider.autoDispose
    .family<ScopedSourceNotes, String>((ref, templateId) async {
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

  return scopeSourceNotes(
    all: out,
    catalogNames: await ref.watch(cheatsheetSourceCatalogNamesProvider.future),
    domain: sourceDomainFor(templateId),
  );
});

/// Two-step chooser: pick a note, then pick which piece of it to show.
///
/// Reports through [onSelected] rather than popping itself, so it can be
/// hosted in a sheet, a dialog or a test harness. [showSourcePicker] is the
/// sheet wrapper.
class SourcePicker extends ConsumerStatefulWidget {
  const SourcePicker({
    super.key,
    required this.onSelected,
    required this.templateId,
  });

  final ValueChanged<CheatsheetSource> onSelected;

  /// The card's template, which decides what gets offered first. Passed in
  /// rather than read from the editor so the picker stays usable from a sheet,
  /// a test, or any future caller that isn't mid-edit.
  final String templateId;

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
    final notes = ref.watch(cheatsheetSourceNotesProvider(widget.templateId));
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
        data: (scoped) => _note == null
            ? _noteStep(scoped)
            : _granularityStep(context, _note!),
      ),
    );
  }

  Widget _noteStep(ScopedSourceNotes scoped) {
    final q = _query.trim().toLowerCase();
    List<HmmNote> matching(List<HmmNote> notes) => q.isEmpty
        ? notes
        : notes.where((n) => n.subject.toLowerCase().contains(q)).toList();

    final preferred = matching(scoped.preferred);
    final other = matching(scoped.other);
    final domain = sourceDomainFor(widget.templateId);

    // One flat list of headers and notes, so the whole thing can still be
    // built lazily — a vault of a few thousand notes should not cost a few
    // thousand widgets to show ten.
    final rows = <Object>[
      if (domain != null && preferred.isNotEmpty) _domainHeading(domain.id),
      ...preferred,
      // The second header only earns its place when there is something above
      // it; with no domain matches the list reads better as one plain list.
      if (preferred.isNotEmpty && other.isNotEmpty) 'Other notes',
      ...other,
    ];

    final nothingAtAll = scoped.preferred.isEmpty && scoped.other.isEmpty;

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
        if (nothingAtAll)
          const Padding(
            key: Key('source-picker-empty'),
            padding: EdgeInsets.all(24),
            child: Text('No notes to reference yet.'),
          )
        else if (rows.isEmpty)
          const Padding(
            key: Key('source-picker-no-matches'),
            padding: EdgeInsets.all(24),
            child: Text('No notes match that search.'),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                if (row is String) return _SectionLabel(row);
                final n = row as HmmNote;
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
            tooltip: 'Back to the note list',
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

/// Heading copy for a domain.
///
/// Lives here, not on [SourceDomain], so the scoping rules stay free of display
/// text. Switching over the enum without a default is deliberate: adding a
/// domain then fails to compile until it has a heading, rather than shipping a
/// group labelled with an identifier.
///
/// Still English, like the other 19 strings in this feature — the cheatsheet
/// screens predate any `AppLocalizations` use. When they are localized this is
/// the single place the picker's domain headings need to change.
String _domainHeading(SourceDomainId id) => switch (id) {
      SourceDomainId.vehicle => 'Vehicle',
    };

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
Future<CheatsheetSource?> showSourcePicker(
  BuildContext context, {
  required String templateId,
}) =>
    showModalBottomSheet<CheatsheetSource>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SourcePicker(
        templateId: templateId,
        onSelected: (source) => Navigator.of(sheetContext).pop(source),
      ),
    );
