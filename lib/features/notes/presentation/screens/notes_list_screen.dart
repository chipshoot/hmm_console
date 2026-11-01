import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/sync/sync_controller.dart';
import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/settings_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/util/search_normalize.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_row_separator.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/models/hmm_note.dart';
import '../../query/note_grouping.dart';
import '../../query/note_query.dart';
import '../../query/note_results.dart';
import '../../rendering/note_display.dart';
import '../../states/filter_usage.dart';
import '../../states/note_selection.dart'
    show kNotesWideBreakpoint, selectedNoteIdProvider;
import '../../states/notes_list_state.dart';
import '../../states/notes_results_provider.dart';
import '../catalog_labels.dart';
import '../widgets/catalog_filter_sheet.dart';
import '../widgets/domain_groups.dart';
import '../widgets/note_flag_sheet.dart' show noteFlagColorLabel;
import '../widgets/note_row.dart';
import '../widgets/notes_view_menu.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The results depend on the locale and week start, which only the widget
    // tree knows. Written after the frame: never while providers build.
    final env = (
      locale: Localizations.localeOf(context),
      firstDayOfWeek: MaterialLocalizations.of(context).firstDayOfWeekIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(notesViewEnvProvider.notifier).set(env);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final listAsync = ref.watch(notesListStateProvider);
    final resultsAsync = ref.watch(notesResultsProvider);
    final notifier = ref.read(notesListStateProvider.notifier);
    final usage = ref.watch(filterUsageProvider).value ?? const {};
    final density = ref.watch(notesRowDensityProvider);
    final data = listAsync.value;

    List<DomainGroup> groupsOf(NotesListData d) => groupByDomain(
      d.catalogsById.values,
      d.countsByCatalog,
      usage,
      domainCounts: d.countsByDomain,
    );

    return AppScaffold(
      title: l.notesTitle,
      drawer: data == null ? null : _FilterDrawer(data: data),
      onRefresh: () async {
        await ref.read(syncControllerProvider).triggerManualSync();
      },
      actions: [
        HmmIconButton(
          tooltip: l.notesViewTooltip,
          icon: Icons.tune,
          onPressed: data == null
              ? null
              : () => showNotesViewMenu(
                  context,
                  density: density,
                  sort: data.query.sort,
                  onDensity: (d) =>
                      ref.read(settingsProvider.notifier).setNotesRowDensity(d),
                  onSort: notifier.setSort,
                ),
        ),
        HmmIconButton(
          tooltip: l.notesFilterTooltip,
          icon: Icons.filter_list,
          onPressed: data == null
              ? null
              : () {
                  final groups = groupsOf(data);
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => CatalogFilterSheet(
                      groups: groups,
                      counts: data.countsByCatalog,
                      selected: catalogSelectionFor(data.query.source, groups),
                      // The sheet only offers All, a whole domain, or one
                      // catalog — each maps to exactly one source.
                      onApply: (ids) => notifier.setSource(
                        sourceForCatalogSelection(ids, groups),
                      ),
                      onRecordDomain: (key) =>
                          ref.read(filterUsageProvider.notifier).record(key),
                    ),
                  );
                },
        ),
        HmmIconButton(
          tooltip: l.notesSubsystemsTitle,
          icon: Icons.widgets_outlined,
          onPressed: () => context.push('/notes/subsystems'),
        ),
        const HelpButton(helpId: HelpId.notesList),
      ],
      // No FAB: creating a note now lives in the Quick Access Panel, which
      // surfaces "New Note" while you're on this screen.
      slivers: [
        if (data != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _SearchField(
                query: data.query.text,
                hintText: l.notesSearchHint,
                clearTooltip: l.notesSearchClearTooltip,
                onChanged: notifier.setText,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _filterBar(data, groupsOf(data), l)),
        ],
        ...resultsAsync.when<List<Widget>>(
          loading: () => const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (e, _) {
            // The type only: the message may hold note text or paths.
            debugPrint('NotesListScreen: load failed (${e.runtimeType})');
            return [
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.error_outline,
                  message: l.notesLoadFailed,
                  actionLabel: l.notesRetry,
                  onAction: notifier.refresh,
                ),
              ),
            ];
          },
          data: (results) => data == null
              ? const []
              : _body(context, data, results, density, l),
        ),
      ],
    );
  }

  Widget _filterBar(
    NotesListData data,
    List<DomainGroup> groups,
    AppLocalizations l,
  ) {
    final notifier = ref.read(notesListStateProvider.notifier);
    // Resolve the active domain (main filter) and, if it has more than one
    // catalog, the sub-filter selection within it.
    final f = catalogSelectionFor(data.query.source, groups);
    DomainGroup? activeDomain;
    if (f != null && f.isNotEmpty) {
      for (final g in groups) {
        if (f.every(g.catalogIds.contains)) {
          activeDomain = g;
          break;
        }
      }
    }
    final mainLabel = activeDomain != null
        ? domainLabel(activeDomain.key, l)
        : ((f == null || f.isEmpty) ? l.notesAll : l.notesFiltered);
    final subDomain = (activeDomain != null && activeDomain.catalogs.length > 1)
        ? activeDomain
        : null;
    int? subSelected;
    if (subDomain != null && f != null) {
      subSelected = setEquals(f, subDomain.catalogIds)
          ? null // "All <domain>"
          : (f.length == 1 ? f.first : null);
    }
    return _FilterBar(
      mainLabel: mainLabel,
      subDomain: subDomain,
      subSelectedCatalogId: subSelected,
      // A whole domain or one of its catalogs: both map exactly.
      onSubSelected: (catId) => notifier.setSource(
        sourceForCatalogSelection(
          catId == null ? subDomain!.catalogIds : {catId},
          groups,
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    NotesListData data,
    NoteResults results,
    NoteRowDensity density,
    AppLocalizations l,
  ) {
    final notifier = ref.read(notesListStateProvider.notifier);
    final text = data.query.text.trim();
    if (results.isEmpty) {
      final Widget empty;
      if (data.all.isEmpty) {
        empty = AppEmptyState(icon: Icons.note_outlined, message: l.notesEmpty);
      } else if (text.isNotEmpty) {
        empty = AppEmptyState(
          icon: Icons.search_off,
          message: l.notesNoMatches(text),
          actionLabel: l.notesSearchClearAction,
          onAction: () => notifier.setText(''),
        );
      } else {
        empty = AppEmptyState(
          icon: Icons.note_outlined,
          message: l.notesNoneInView,
        );
      }
      return [SliverFillRemaining(hasScrollBody: false, child: empty)];
    }

    final registry = ref.watch(noteDisplayRegistryProvider);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final notesById = {for (final n in data.all) n.id: n};
    final highlightWords = [
      for (final w in normalizeForSearch(data.query.text).split(' '))
        if (w.isNotEmpty) w,
    ];

    String? parentTitleOf(HmmNote note, String? domain) {
      final parentNote = note.parentNoteId == null
          ? null
          : notesById[note.parentNoteId];
      final parentSubject = parentNote != null
          ? registry.title(
              parentNote,
              data.catalogsById[parentNote.catalogId]?.name,
              l,
            )
          : data.contextSubjectOf(note);
      // The parent's own words, capped so a long record name cannot swallow
      // the row; an anchor has no subject, so it falls back to the domain.
      if (parentSubject != null) {
        final chars = parentSubject.characters;
        return chars.length > 20 ? '${chars.take(20)}…' : parentSubject;
      }
      return data.parentDomainOf(note) != null && domain != null
          ? domainLabel(domain, l)
          : null;
    }

    void open(HmmNote note) {
      // Contacts and cheatsheet cards have their own screens; the generic
      // note screen would show raw JSON.
      if (registry.open(
        context,
        note,
        data.catalogsById[note.catalogId]?.name,
      )) {
        return;
      }
      final isWide = MediaQuery.of(context).size.width >= kNotesWideBreakpoint;
      if (isWide) {
        ref.read(selectedNoteIdProvider.notifier).select(note.id);
      } else {
        context.push('/notes/${note.id}');
      }
    }

    Widget row(NoteHit hit) {
      final note = hit.note;
      final domain = data.effectiveDomain(note);
      return NoteRow(
        key: ValueKey(note.id),
        hit: hit,
        density: density,
        domainKey: domain,
        catalogName: note.catalogId == null
            ? null
            : data.catalogsById[note.catalogId]?.name,
        parentTitle: parentTitleOf(note, domain),
        tags: data.tagsByNoteId[note.id] ?? const [],
        date: groupingDateOf(note, data.query.sort),
        highlightWords: highlightWords,
        now: now,
        onTap: () => open(note),
      );
    }

    return [
      for (final group in results.groups)
        SliverMainAxisGroup(
          slivers: [
            if (_groupTitle(group.key, l, locale) case final title?)
              SliverPersistentHeader(
                pinned: true,
                delegate: _GroupHeaderDelegate(
                  title: title,
                  background: context.appColors.groupedBackground,
                  color: context.appColors.secondaryLabel,
                ),
              ),
            SliverList.separated(
              itemCount: group.hits.length,
              itemBuilder: (_, i) => row(group.hits[i]),
              separatorBuilder: (_, _) => const AppRowSeparator(),
            ),
          ],
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }
}

/// A section's header text; null for an ungrouped list.
String? _groupTitle(NoteGroupKey key, AppLocalizations l, String locale) =>
    switch (key) {
      PinnedGroup() => l.notesGroupPinned,
      TodayGroup() => l.notesGroupToday,
      YesterdayGroup() => l.notesGroupYesterday,
      ThisWeekGroup() => l.notesGroupThisWeek,
      ThisMonthGroup() => l.notesGroupThisMonth,
      MonthGroup(:final year, :final month) => DateFormat.yMMM(
        locale,
      ).format(DateTime(year, month)),
      LetterGroup(:final letter) => letter,
      FlagGroup(:final color) =>
        color == null ? l.notesGroupUnflagged : noteFlagColorLabel(color, l),
      FlatGroup() => null,
    };

/// A section header that sticks to the top while its section scrolls by.
class _GroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _GroupHeaderDelegate({
    required this.title,
    required this.background,
    required this.color,
  });

  final String title;
  final Color background;
  final Color color;

  static const _height = 32.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Semantics(
    header: true,
    child: Container(
      color: background,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DesignTokens.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  @override
  bool shouldRebuild(_GroupHeaderDelegate old) =>
      old.title != title || old.background != background || old.color != color;
}

/// The filter controls that replace the horizontal chip row: a main button
/// (shows the active domain, opens the category drawer) and — only when the
/// active domain has more than one catalog — a compact sub-filter dropdown.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.mainLabel,
    this.subDomain,
    this.subSelectedCatalogId,
    this.onSubSelected,
  });

  final String mainLabel;
  final DomainGroup? subDomain;
  final int? subSelectedCatalogId;
  final void Function(int? catalogId)? onSubSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
      child: Row(
        children: [
          ActionChip(
            avatar: Icon(Icons.tune, size: 18, color: c.accent),
            label: Text(mainLabel),
            // Opens the AppScaffold drawer; this context is under the Scaffold
            // so Scaffold.of resolves it.
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          if (subDomain != null && onSubSelected != null) ...[
            const SizedBox(width: 8),
            _SubFilterButton(
              domain: subDomain!,
              selectedCatalogId: subSelectedCatalogId,
              onSelected: onSubSelected!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact dropdown for filtering within a domain. The first option is
/// `All [domain]` (the default); the rest are the domain's catalogs.
class _SubFilterButton extends StatelessWidget {
  const _SubFilterButton({
    required this.domain,
    required this.selectedCatalogId,
    required this.onSelected,
  });

  // Sentinel for the "All <domain>" option. PopupMenuButton treats a tapped
  // null-value item as a *cancel* (never firing onSelected), so the "All"
  // option must carry a non-null value. Real catalog ids are positive.
  static const int _allValue = -1;

  final DomainGroup domain;
  final int? selectedCatalogId;
  final void Function(int? catalogId) onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.appColors;
    final allLabel = l.notesAllInDomain(domainLabel(domain.key, l));
    String label = allLabel;
    if (selectedCatalogId != null) {
      for (final cat in domain.catalogs) {
        if (cat.id == selectedCatalogId) {
          label = catalogLabel(cat.name, l);
          break;
        }
      }
    }
    return PopupMenuButton<int>(
      initialValue: selectedCatalogId ?? _allValue,
      onSelected: (v) => onSelected(v == _allValue ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem<int>(value: _allValue, child: Text(allLabel)),
        for (final cat in domain.catalogs)
          PopupMenuItem<int>(
            value: cat.id,
            child: Text(catalogLabel(cat.name, l)),
          ),
      ],
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 8, 7),
        decoration: BoxDecoration(
          color: c.secondaryGroupedBackground,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          border: Border.all(color: c.separator),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: DesignTokens.rowSecondary.copyWith(
                color: c.label,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: c.secondaryLabel),
          ],
        ),
      ),
    );
  }
}

/// Category panel (a left drawer) listing "All" + the note DOMAINS. Picking one
/// applies the filter and closes the panel. Replaces the old inline chips; the
/// per-catalog funnel sheet stays available from the nav bar.
class _FilterDrawer extends ConsumerWidget {
  const _FilterDrawer({required this.data});
  final NotesListData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.appColors;
    final notifier = ref.read(notesListStateProvider.notifier);
    final usage = ref.watch(filterUsageProvider).value ?? const {};
    final groups = groupByDomain(
      data.catalogsById.values,
      data.countsByCatalog,
      usage,
      domainCounts: data.countsByDomain,
    );
    final f = catalogSelectionFor(data.query.source, groups);

    Widget dot(Color color) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    Widget tile({
      required Widget leading,
      required String title,
      required bool selected,
      required VoidCallback onTap,
    }) => ListTile(
      leading: leading,
      title: Text(title),
      selected: selected,
      trailing: selected ? Icon(Icons.check, color: c.accent) : null,
      onTap: onTap,
    );

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
              child: Text(
                l.notesFilter,
                style: DesignTokens.caption.copyWith(
                  color: c.secondaryLabel,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            tile(
              leading: dot(c.tertiaryLabel),
              title: l.notesAll,
              selected: f == null || f.isEmpty,
              onTap: () {
                notifier.setSource(const AllSource());
                Navigator.of(context).pop();
              },
            ),
            for (final g in groups)
              tile(
                leading: dot(g.style.color),
                title: domainLabel(g.key, l),
                selected: f != null && setEquals(f, g.catalogIds),
                onTap: () {
                  ref.read(filterUsageProvider.notifier).record(g.key);
                  notifier.setSource(DomainSource(key: g.key));
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// The search box, showing the query that is actually being applied.
///
/// The query lives on the notifier so it survives reactive data emissions —
/// and therefore also survives leaving the screen. With an uncontrolled
/// TextField that meant coming back to an empty-looking box silently filtering
/// the list, which reads as "all my notes are gone".
///
/// Typing is debounced: the query is sent [_debounce] after the last
/// keystroke, so a fast typist does not re-run the search per letter.
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.query,
    required this.hintText,
    required this.clearTooltip,
    required this.onChanged,
  });

  final String query;
  final String hintText;
  final String clearTooltip;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  static const _debounce = Duration(milliseconds: 150);

  late final TextEditingController _controller = TextEditingController(
    text: widget.query,
  )..addListener(_onControllerChanged);
  late String _lastSent = widget.query;
  late bool _hasText = widget.query.isNotEmpty;
  Timer? _timer;

  void _onControllerChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _send(String text) {
    _timer?.cancel();
    _lastSent = text;
    widget.onChanged(text);
  }

  void _onTyped(String text) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => _send(text));
  }

  void _clear() {
    _controller.clear();
    _send('');
  }

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a change made elsewhere (e.g. "Clear search" in the empty state)
    // is copied into the box. Echoes of what this field sent, and rebuilds
    // while a keystroke is still pending, must not move the caret or undo
    // the typing.
    if (widget.query != oldWidget.query &&
        widget.query != _lastSent &&
        widget.query != _controller.text) {
      _timer?.cancel();
      _lastSent = widget.query;
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: widget.hintText,
        isDense: true,
        border: const OutlineInputBorder(),
        // A way out that does not require selecting invisible text.
        suffixIcon: _hasText
            ? HmmIconButton(
                key: const Key('notesSearchClear'),
                icon: Icons.clear,
                tooltip: widget.clearTooltip,
                onPressed: _clear,
              )
            : null,
      ),
      onChanged: _onTyped,
    );
  }
}
