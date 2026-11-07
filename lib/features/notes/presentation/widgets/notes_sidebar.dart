import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/undoable_action.dart';
import '../../../../core/notes/note_flag.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../query/built_in_smart_filters.dart';
import '../../query/note_query.dart';
import '../../query/note_token_labels.dart';
import '../../query/saved_search.dart';
import '../../states/filter_usage.dart';
import '../../states/notes_list_state.dart';
import '../../states/notes_multi_select.dart';
import '../../states/notes_results_provider.dart';
import '../../states/recently_deleted_provider.dart';
import '../../states/saved_searches_provider.dart';
import '../catalog_labels.dart';
import 'domain_groups.dart';
import 'saved_search_dialogs.dart';

/// The notes side panel: All, Pinned, Flagged (with a row per colour in use),
/// Today, Domains, Tags and Smart filters, with note counts. Shown in a
/// drawer, or docked beside the list on wide screens. [onPicked] runs once
/// after a pick (the drawer closes itself there); the sidebar never pops a
/// route itself.
class NotesSidebar extends ConsumerWidget {
  const NotesSidebar({super.key, required this.data, required this.onPicked});

  final NotesListData data;
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.appColors;
    final notifier = ref.read(notesListStateProvider.notifier);
    final usage = ref.watch(filterUsageProvider).value ?? const {};
    final counts = ref.watch(notesResultsProvider).value?.counts;
    final source = data.query.source;
    final groups = groupByDomain(
      data.catalogsById.values,
      data.countsByCatalog,
      usage,
      domainCounts: data.countsByDomain,
    );
    final smart = ref.watch(notesSmartFiltersProvider);
    final saved = ref.watch(savedSearchesProvider);
    final savedNotifier = ref.read(savedSearchesProvider.notifier);

    // Live tags that hold notes, by name.
    final tags = <({int id, String name, int count})>[];
    (counts?.byTag ?? const <int, int>{}).forEach((id, n) {
      final live = data.liveTagNames;
      if (n <= 0 || (live != null && !live.containsKey(id))) return;
      final name = tagNameOf(data, id);
      if (name != null) tags.add((id: id, name: name, count: n));
    });
    tags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final flagCounts = counts?.byFlag ?? const <int, int>{};
    final flagged = [
      for (final e in flagCounts.entries)
        if (e.value > 0) e,
    ]..sort((a, b) => a.key.compareTo(b.key));
    final flaggedTotal = counts == null
        ? null
        : flagCounts.values.fold<int>(0, (a, b) => a + b);

    void pick(NoteSource s, {String? usageKey}) {
      if (usageKey != null) {
        ref.read(filterUsageProvider.notifier).record(usageKey);
      }
      // A new list: the old ticks would point at notes no longer shown.
      ref.read(notesMultiSelectProvider.notifier).exit();
      notifier.setSource(s);
      onPicked();
    }

    Future<void> guarded(Future<void> Function() run) async {
      final messenger = ScaffoldMessenger.of(context);
      final failed = l.notesSavedSearchUpdateFailed;
      try {
        await run();
      } catch (e) {
        // Type only: the saved search is user content.
        debugPrint(
          'NotesSidebar: saved search update failed (${e.runtimeType})',
        );
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failed)));
      }
    }

    Future<void> onSavedMenu(SavedSearch s, int index) async {
      final action = await showSavedSearchMenu(
        context,
        canMoveUp: index > 0,
        canMoveDown: index < saved.length - 1,
      );
      if (action == null || !context.mounted) return;
      switch (action) {
        case SavedSearchAction.rename:
          final name = await showSavedSearchNameDialog(
            context,
            title: l.notesSavedSearchRenameTitle,
            initial: s.name,
          );
          if (name != null && name.isNotEmpty) {
            await guarded(() => savedNotifier.rename(s.id, name));
          }
        case SavedSearchAction.moveUp:
          await guarded(() => savedNotifier.move(s.id, -1));
        case SavedSearchAction.moveDown:
          await guarded(() => savedNotifier.move(s.id, 1));
        case SavedSearchAction.delete:
          // Close the panel (the drawer pops itself; a docked sidebar does
          // nothing) so the snackbar with Undo is not under a scrim.
          onPicked();
          if (!context.mounted) return;
          await showUndoableAction(
            context,
            run: () => savedNotifier.remove(s.id),
            undo: () => savedNotifier.restore(s),
            done: l.notesSavedSearchDeleted(s.name),
            failed: l.notesSavedSearchDeleteFailed,
            undone: l.notesSavedSearchRestored(s.name),
            undoFailed: l.notesSavedSearchRestoreFailed,
            busyKey: ('deleteSavedSearch', s.id),
          );
      }
    }

    Widget dot(Color color) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    Widget header(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: DesignTokens.caption.copyWith(
            color: c.secondaryLabel,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );

    Widget tile({
      required Widget leading,
      required String title,
      required bool selected,
      required VoidCallback onTap,
      int? count,
      bool indent = false,
      VoidCallback? onLongPress,
    }) => ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: indent ? 36 : 16,
        end: 16,
      ),
      leading: leading,
      title: Text(title),
      selected: selected,
      trailing: (count == null && !selected)
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (count != null) Text('$count'),
                if (selected) ...[
                  if (count != null) const SizedBox(width: 8),
                  Icon(Icons.check, color: c.accent),
                ],
              ],
            ),
      onTap: onTap,
      onLongPress: onLongPress,
    );

    void pickSmart(SavedSearch s) {
      // The smart filter's own text and tokens apply through the source, so
      // what is typed next narrows it.
      final live = data.query;
      ref.read(notesMultiSelectProvider.notifier).exit();
      notifier.setQuery(
        NoteQuery(
          source: SmartSource(savedId: s.id),
          // A sticky "All notes" would make the source a no-op; start from
          // the smart filter's own source.
          scope: NoteScope.currentSource,
          sort: live.sort,
        ),
      );
      onPicked();
    }

    return SafeArea(
      child: ListView(
        children: [
          tile(
            leading: dot(c.tertiaryLabel),
            title: l.notesAll,
            count: counts?.all,
            selected: source == const AllSource(),
            onTap: () => pick(const AllSource()),
          ),
          tile(
            leading: Icon(Icons.push_pin_outlined, color: c.accent),
            title: l.notesTokenPinned,
            count: counts?.pinned,
            selected: source == const PinnedSource(),
            onTap: () => pick(const PinnedSource()),
          ),
          tile(
            leading: Icon(Icons.flag_outlined, color: c.accent),
            title: l.notesSidebarFlagged,
            count: flaggedTotal,
            selected: source == const FlaggedSource(),
            onTap: () => pick(const FlaggedSource()),
          ),
          for (final e in flagged)
            tile(
              indent: true,
              leading: dot(NoteFlagColor.fromStored(e.key)!.color),
              title: flagName(e.key, l),
              count: e.value,
              selected: source == FlaggedSource(color: e.key),
              onTap: () => pick(FlaggedSource(color: e.key)),
            ),
          tile(
            leading: Icon(Icons.today_outlined, color: c.accent),
            title: l.notesGroupToday,
            selected: source == const TodaySource(),
            onTap: () => pick(const TodaySource()),
          ),
          if (groups.isNotEmpty) header(l.notesSidebarDomains),
          for (final g in groups)
            tile(
              leading: dot(g.style.color),
              title: domainLabel(g.key, l),
              count: counts?.byDomain[g.key] ?? (counts == null ? null : 0),
              selected: source == DomainSource(key: g.key),
              onTap: () => pick(DomainSource(key: g.key), usageKey: g.key),
            ),
          header(l.notesSidebarTags),
          for (final t in tags)
            tile(
              leading: Icon(Icons.label_outline, color: c.accent),
              title: t.name,
              count: t.count,
              selected: source == TagSource(tagId: t.id),
              onTap: () =>
                  pick(TagSource(tagId: t.id), usageKey: usageKeyForTag(t.id)),
            ),
          tile(
            leading: Icon(Icons.edit_outlined, color: c.accent),
            title: l.notesManageTagsRow,
            selected: false,
            onTap: () {
              // The drawer may pop on onPicked: take the router first.
              final router = GoRouter.of(context);
              onPicked();
              router.push('/notes/tags');
            },
          ),
          header(l.notesSidebarSmartFilters),
          for (final s in smart)
            if (isBuiltInSmartFilter(s.id))
              tile(
                leading: Icon(Icons.auto_awesome_outlined, color: c.accent),
                title: smartFilterDisplayName(s, l),
                selected: source == SmartSource(savedId: s.id),
                onTap: () => pickSmart(s),
                // A held press must not fall through to a tap; built-ins
                // have no menu.
                onLongPress: () {},
              ),
          if (saved.isNotEmpty) header(l.notesSavedSearchesHeader),
          for (var i = 0; i < saved.length; i++)
            tile(
              leading: Icon(Icons.bookmark_outline, color: c.accent),
              title: saved[i].name,
              selected: source == SmartSource(savedId: saved[i].id),
              onTap: () => pickSmart(saved[i]),
              onLongPress: () => onSavedMenu(saved[i], i),
            ),
          tile(
            leading: Icon(Icons.delete_outline, color: c.accent),
            title: l.notesRecentlyDeletedTitle,
            count: ref.watch(recentlyDeletedProvider).value?.length,
            selected: false,
            onTap: () {
              // The drawer may pop on onPicked: take the router first.
              final router = GoRouter.of(context);
              onPicked();
              router.push('/notes/deleted');
            },
          ),
        ],
      ),
    );
  }
}
