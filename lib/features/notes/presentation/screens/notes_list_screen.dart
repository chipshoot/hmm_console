import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSlidingSegmentedControl;
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
import '../../query/built_in_smart_filters.dart';
import '../../query/note_grouping.dart';
import '../../query/note_query.dart';
import '../../query/note_results.dart';
import '../../query/note_token_labels.dart';
import '../../query/note_token_suggestions.dart';
import '../../query/smart_query.dart';
import '../../rendering/note_display.dart';
import '../../states/note_selection.dart'
    show kNotesWideBreakpoint, selectedNoteIdProvider;
import '../../states/notes_list_state.dart';
import '../../states/notes_multi_select.dart';
import '../../states/notes_results_provider.dart';
import '../../states/recent_searches.dart';
import '../../states/saved_searches_provider.dart';
import '../catalog_labels.dart';
import '../widgets/note_chip_bar.dart';
import '../widgets/note_flag_sheet.dart' show noteFlagColorLabel;
import '../widgets/note_search_field.dart';
import '../widgets/notes_sidebar.dart';
import '../widgets/note_actions_menu.dart';
import '../widgets/note_row.dart';
import '../widgets/note_swipe_actions.dart';
import '../widgets/saved_search_dialogs.dart';
import '../widgets/notes_view_menu.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key, this.sidebarDocked = false});

  /// True when the side panel is docked beside the list: no drawer, no ☰,
  /// no ＋.
  final bool sidebarDocked;

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final _fieldKey = GlobalKey<NoteSearchFieldState>();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// The note's display title: the same one the search results use, never the
  /// raw subject (contacts and cheatsheets keep JSON there).
  String Function(HmmNote) _titleOf(NotesListData data, AppLocalizations l) {
    final registry = ref.read(noteDisplayRegistryProvider);
    return (n) => registry.title(n, data.catalogsById[n.catalogId]?.name, l);
  }

  void _recordRecent() {
    final q = ref.read(notesListStateProvider).value?.query;
    if (q == null || (q.text.trim().isEmpty && q.tokens.isEmpty)) return;
    ref.read(recentSearchesProvider.notifier).record(q);
  }

  void _applySuggestion(NoteToken token) {
    final notifier = ref.read(notesListStateProvider.notifier);
    final q = ref.read(notesListStateProvider).value?.query;
    if (q == null) return;
    // Token and empty text in ONE update, then empty the box: the box never
    // looks empty while the notifier still filters by the old text.
    notifier.setQuery(q.copyWith(text: '', tokens: [...q.tokens, token]));
    _fieldKey.currentState?.clearAndCancel();
  }

  void _applyRecent(RecentSearch r) {
    final notifier = ref.read(notesListStateProvider.notifier);
    final q = ref.read(notesListStateProvider).value?.query;
    if (q == null) return;
    notifier.setQuery(q.copyWith(text: r.text, tokens: r.tokens));
  }

  /// Whether there is anything worth saving: text, tokens or a narrowed source.
  bool _canSave(NoteQuery? q) =>
      q != null &&
      // A SmartSource left after resolution is a deleted saved search.
      q.source is! SmartSource &&
      (q.text.trim().isNotEmpty ||
          q.tokens.isNotEmpty ||
          q.source is! AllSource);

  Future<void> _saveSearch(NotesListData data, AppLocalizations l) async {
    final effective = ref.read(notesEffectiveQueryProvider);
    if (effective == null) return;
    final saved = ref.read(savedSearchesProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final text = effective.text.trim();
    final String initial;
    if (text.isNotEmpty) {
      initial = text;
    } else if (effective.tokens.isNotEmpty) {
      initial = tokenLabel(
        effective.tokens.first,
        data,
        l,
        titleOf: _titleOf(data, l),
        dateFormat: DateFormat.yMd(Localizations.localeOf(context).toString()),
      ).text;
    } else {
      initial = _sourceLabel(data, l, effective.source);
    }
    final name = await showSavedSearchNameDialog(
      context,
      title: l.notesSaveSearchTitle,
      initial: initial,
    );
    if (name == null || name.isEmpty) return;
    // The effective query, so a search saved while a saved search is open
    // holds that search's content and no SmartSource.
    final String message;
    try {
      await saved.add(name, effective.copyWith(scope: NoteScope.currentSource));
      message = l.notesSavedSearchSaved(name);
    } catch (e) {
      // Type only: the saved search is user content.
      debugPrint('NotesListScreen: save search failed (${e.runtimeType})');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.notesSavedSearchSaveFailed)));
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

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
    final density = ref.watch(notesRowDensityProvider);
    final data = listAsync.value;
    final effective = ref.watch(notesEffectiveQueryProvider);

    return AppScaffold(
      title: l.notesTitle,
      drawer: data == null || widget.sidebarDocked
          ? null
          : Drawer(
              child: NotesSidebar(
                data: data,
                onPicked: () => Navigator.of(context).pop(),
              ),
            ),
      onRefresh: () async {
        await ref.read(syncControllerProvider).triggerManualSync();
      },
      actions: [
        if (!widget.sidebarDocked)
          // A Builder: this context is above the Scaffold AppScaffold builds.
          Builder(
            builder: (context) => HmmIconButton(
              tooltip: l.notesMenuTooltip,
              icon: Icons.menu,
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: NoteSearchField(
                      key: _fieldKey,
                      focusNode: _focus,
                      text: data.query.text,
                      chips: _chips(data, l),
                      hintText: l.notesSearchHint,
                      clearTooltip: l.notesSearchClearTooltip,
                      onTextChanged: notifier.setText,
                      onRemoveLastToken: () {
                        final t = data.query.tokens;
                        if (t.isNotEmpty) {
                          notifier.setTokens(t.sublist(0, t.length - 1));
                        }
                      },
                      onSubmitted: (_) => _recordRecent(),
                    ),
                  ),
                  if (_canSave(effective))
                    HmmIconButton(
                      tooltip: l.notesSaveSearchTooltip,
                      icon: Icons.bookmark_add_outlined,
                      onPressed: () => _saveSearch(data, l),
                    ),
                ],
              ),
            ),
          ),
          ..._suggestionsAndRecents(data, l),
          SliverToBoxAdapter(
            child: NoteChipBar(data: data, sidebarDocked: widget.sidebarDocked),
          ),
          if (_showScope(effective))
            SliverToBoxAdapter(child: _scopeToggle(data, effective!, l)),
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

  List<Widget> _chips(NotesListData data, AppLocalizations l) {
    final notifier = ref.read(notesListStateProvider.notifier);
    final titleOf = _titleOf(data, l);
    final format = DateFormat.yMd(Localizations.localeOf(context).toString());
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final tokens = data.query.tokens;
    final struck = TextStyle(
      decoration: TextDecoration.lineThrough,
      color: context.appColors.secondaryLabel,
    );
    // The open saved search's own text and tokens: read-only, before the live
    // chips, and never touched by Backspace.
    final saved = savedSearchFor(
      data.query.source,
      ref.watch(notesSmartFiltersProvider),
    );
    final savedChips = <({String text, bool removed})>[
      if (saved != null && saved.query.text.trim().isNotEmpty)
        (text: '"${saved.query.text.trim()}"', removed: false),
      if (saved != null)
        for (final t in saved.query.tokens)
          tokenLabel(t, data, l, titleOf: titleOf, dateFormat: format),
    ];
    return [
      for (var i = 0; i < savedChips.length; i++)
        Chip(
          avatar: i == 0 ? const Icon(Icons.bookmark_outline) : null,
          label: Text(
            savedChips[i].text,
            style: savedChips[i].removed ? struck : null,
          ),
          backgroundColor: Colors.transparent,
          side: BorderSide(color: context.appColors.secondaryLabel),
        ),
      for (var i = 0; i < tokens.length; i++)
        Builder(
          builder: (_) {
            final label = tokenLabel(
              tokens[i],
              data,
              l,
              titleOf: titleOf,
              dateFormat: format,
            );
            final text = Text(label.text, style: label.removed ? struck : null);
            void remove() => notifier.setTokens([
              for (var j = 0; j < tokens.length; j++)
                if (j != i) tokens[j],
            ]);
            final tooltip = l.notesTokenRemoveTooltip(label.text);
            return ios
                ? Chip(
                    label: text,
                    deleteIcon: const Icon(CupertinoIcons.xmark_circle_fill),
                    deleteButtonTooltipMessage: tooltip,
                    onDeleted: remove,
                  )
                : InputChip(
                    label: text,
                    deleteButtonTooltipMessage: tooltip,
                    onDeleted: remove,
                  );
          },
        ),
    ];
  }

  List<Widget> _suggestionsAndRecents(NotesListData data, AppLocalizations l) {
    final q = data.query;
    if (q.text.trim().isNotEmpty) {
      final suggestions = suggestTokens(
        q.text,
        data,
        q.tokens,
        l,
        titleOf: _titleOf(data, l),
      );
      if (suggestions.isEmpty) return const [];
      return [
        SliverToBoxAdapter(
          child: _SectionBox(
            header: l.notesSuggestionsHeader,
            headerIcon: Icons.manage_search,
            children: [
              for (final s in suggestions)
                ListTile(
                  dense: true,
                  leading: Icon(s.icon),
                  title: Text(s.label),
                  onTap: () => _applySuggestion(s.token),
                ),
            ],
          ),
        ),
      ];
    }
    if (!_focus.hasFocus || q.tokens.isNotEmpty) return const [];
    final recents = ref.watch(recentSearchesProvider).value ?? const [];
    if (recents.isEmpty) return const [];
    final titleOf = _titleOf(data, l);
    final format = DateFormat.yMd(Localizations.localeOf(context).toString());
    String describe(RecentSearch r) => [
      if (r.text.isNotEmpty) r.text,
      for (final t in r.tokens)
        tokenLabel(t, data, l, titleOf: titleOf, dateFormat: format).text,
    ].join(' · ');
    return [
      SliverToBoxAdapter(
        // Taps in here count as inside the text field, so they do not unfocus
        // it (which would remove this section before the tap lands).
        child: TextFieldTapRegion(
          child: _SectionBox(
            header: l.notesRecentSearches,
            trailing: TextButton(
              onPressed: () =>
                  ref.read(recentSearchesProvider.notifier).clear(),
              child: Text(l.notesRecentSearchesClear),
            ),
            children: [
              for (final r in recents)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.history),
                  title: Text(describe(r)),
                  onTap: () => _applyRecent(r),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  /// The scope choice only matters while searching inside a narrower source.
  /// Judged on the effective query, so an open saved search counts.
  bool _showScope(NoteQuery? q) =>
      q != null &&
      (q.text.trim().isNotEmpty || q.tokens.isNotEmpty) &&
      q.source is! AllSource;

  String _sourceLabel(
    NotesListData data,
    AppLocalizations l, [
    NoteSource? source,
  ]) {
    final src = source ?? data.query.source;
    switch (src) {
      case DomainSource(:final key, :final catalogId):
        final cat = catalogId == null ? null : data.catalogsById[catalogId];
        return cat != null ? catalogLabel(cat.name, l) : domainLabel(key, l);
      case PinnedSource():
        return l.notesGroupPinned;
      case TodaySource():
        return l.notesGroupToday;
      case FlaggedSource(:final color):
        return color == null ? l.notesFiltered : flagName(color, l);
      case TagSource(:final tagId):
        final name = tagNameOf(data, tagId);
        return name == null ? l.notesFiltered : l.notesTokenTag(name);
      case SmartSource():
        // ref.read: this also runs from event handlers; the build path
        // already rebuilds on saved-search changes via the effective query.
        final found = savedSearchFor(src, ref.read(notesSmartFiltersProvider));
        return found == null
            ? l.notesFiltered
            : smartFilterDisplayName(found, l);
      default:
        return l.notesFiltered;
    }
  }

  Widget _scopeToggle(
    NotesListData data,
    NoteQuery effective,
    AppLocalizations l,
  ) {
    final notifier = ref.read(notesListStateProvider.notifier);
    final all = l.notesScopeAll;
    final current = l.notesScopeCurrent(
      _sourceLabel(data, l, effective.source),
    );
    final scope = data.query.scope;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
      child: ios
          ? SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<NoteScope>(
                groupValue: scope,
                onValueChanged: (v) {
                  if (v != null) notifier.setScope(v);
                },
                children: {
                  NoteScope.currentSource: Text(current),
                  NoteScope.all: Text(all),
                },
              ),
            )
          : SegmentedButton<NoteScope>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: NoteScope.currentSource,
                  label: Text(current),
                ),
                ButtonSegment(value: NoteScope.all, label: Text(all)),
              ],
              selected: {scope},
              onSelectionChanged: (s) => notifier.setScope(s.first),
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
    final source = data.query.source;
    if (source is SmartSource &&
        savedSearchFor(source, ref.watch(notesSmartFiltersProvider)) == null) {
      // Deleted here or on another device while open.
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            icon: Icons.bookmark_remove_outlined,
            message: l.notesSavedSearchMissing,
            actionLabel: l.notesShowAllNotes,
            onAction: () => notifier.setSource(const AllSource()),
          ),
        ),
      ];
    }
    if (results.isEmpty) {
      final Widget empty;
      if (data.all.isEmpty) {
        empty = AppEmptyState(icon: Icons.note_outlined, message: l.notesEmpty);
      } else if (text.isNotEmpty || data.query.tokens.isNotEmpty) {
        empty = AppEmptyState(
          icon: Icons.search_off,
          message: text.isNotEmpty
              ? l.notesNoMatches(text)
              : l.notesNoMatchesFilters,
          actionLabel: l.notesSearchClearAction,
          onAction: () => notifier.setQuery(
            data.query.copyWith(text: '', tokens: const []),
          ),
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
      for (final w in normalizeForSearch(
        ref.watch(notesEffectiveQueryProvider)?.text ?? data.query.text,
      ).split(' '))
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
      _recordRecent();
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
      final catalogName = note.catalogId == null
          ? null
          : data.catalogsById[note.catalogId]?.name;
      final state = data.stateOf(note);
      final isIos = Theme.of(context).platform == TargetPlatform.iOS;
      void select() =>
          ref.read(notesMultiSelectProvider.notifier).enter(note.id);
      final rowWidget = NoteRow(
        hit: hit,
        density: density,
        domainKey: domain,
        catalogName: catalogName,
        parentTitle: parentTitleOf(note, domain),
        tags: data.tagsByNoteId[note.id] ?? const [],
        date: groupingDateOf(note, data.query.sort),
        highlightWords: highlightWords,
        now: now,
        onTap: () => open(note),
        // iOS opens its context menu instead (below).
        onLongPress: isIos
            ? null
            : () => showNoteActionsSheet(
                context,
                ref,
                note: note,
                state: state,
                catalogName: catalogName,
                onSelect: select,
              ),
      );
      final swipeRow = NoteSwipeActions(
        key: ValueKey(note.id),
        note: note,
        state: state,
        catalogName: catalogName,
        enabled: true,
        child: rowWidget,
      );
      if (!isIos) return swipeRow;
      return NoteContextMenu(
        note: note,
        state: state,
        catalogName: catalogName,
        onSelect: select,
        preview: rowWidget,
        child: swipeRow,
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

/// A titled list section between the search box and the results.
class _SectionBox extends StatelessWidget {
  const _SectionBox({
    required this.header,
    required this.children,
    this.headerIcon,
    this.trailing,
  });

  final String header;
  final IconData? headerIcon;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 0),
          child: Row(
            children: [
              if (headerIcon != null) ...[
                Icon(headerIcon, size: 16, color: c.secondaryLabel),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    header,
                    style: DesignTokens.caption.copyWith(
                      color: c.secondaryLabel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}
