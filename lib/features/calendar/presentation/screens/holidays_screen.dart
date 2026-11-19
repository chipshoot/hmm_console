import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/help/undoable_action.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/holiday_cache.dart';
import '../../data/holiday_sources.dart';
import '../../domain/holidays.dart';
import '../../domain/region_names.dart';
import '../../states/holiday_providers.dart';
import '../../states/holiday_settings_providers.dart';

/// Country names from the last fetched available-countries list.
final holidayCountryNamesProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
      final list = await ref.watch(holidayCacheProvider).readCountries();
      return {for (final c in list) c.code: c.name};
    });

typedef _Status = ({DateTime? fetchedAt, bool nextNotPublished, int nextYear});

/// This device's cache state for one source: when the current year was
/// fetched, and whether next year is known not to be published yet.
final _holidayStatusProvider = FutureProvider.autoDispose
    .family<_Status, String>((ref, sourceId) async {
      final cache = ref.watch(holidayCacheProvider);
      final year = DateTime.now().year;
      final cur = await cache.read(sourceId, year);
      final next = await cache.read(sourceId, year + 1);
      return (
        fetchedAt: cur?.fetchedAt,
        nextNotPublished: next?.status == CachedStatus.notPublished,
        nextYear: year + 1,
      );
    });

String _countryName(String code, Map<String, String> names, bool zh) {
  if (code == 'CN' && zh) return '中国';
  return names[code] ?? code;
}

bool _isApple(BuildContext context) {
  final p = Theme.of(context).platform;
  return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
}

/// Subscribed holiday regions: add, remove (with undo), and the way into
/// My holidays.
class HolidaysScreen extends ConsumerStatefulWidget {
  const HolidaysScreen({super.key});

  @override
  ConsumerState<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends ConsumerState<HolidaysScreen> {
  void _offline(AppLocalizations l) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.calendarHolidaysOffline)));
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final zh = l.localeName.startsWith('zh');
    final dio = ref.read(holidayDioProvider);
    final cache = ref.read(holidayCacheProvider);
    final now = DateTime.now();

    final countries = await fetchAvailableCountries(dio);
    if (!mounted) return;
    if (countries == null) return _offline(l);
    unawaited(
      cache
          .writeCountries(countries)
          .then((_) {
            if (mounted) ref.invalidate(holidayCountryNamesProvider);
          })
          .catchError((Object _) {}),
    );

    final existing = ref.read(holidayRegionsProvider);
    final wholeTaken = {
      for (final r in existing)
        if (r.region == null) r.country,
    };
    final offered =
        [
          for (final c in countries)
            if (!wholeTaken.contains(c.code)) c,
        ]..sort(
          (a, b) => _countryName(a.code, {
            a.code: a.name,
          }, zh).compareTo(_countryName(b.code, {b.code: b.name}, zh)),
        );

    final countryPick = await _pick<String>(
      context,
      title: l.calendarHolidays,
      searchHint: l.calendarHolidaysSearch,
      items: [
        for (final c in offered)
          (
            value: c.code,
            label:
                '${flagEmoji(c.code)}  ${_countryName(c.code, {c.code: c.name}, zh)}',
          ),
      ],
    );
    if (countryPick == null || !mounted) return;
    final country = countryPick.value;

    String? region;
    if (country != 'CN') {
      final codes = await regionCodesIn(dio, country, now.year);
      if (!mounted) return;
      if (codes == null) return _offline(l);
      if (codes.isNotEmpty) {
        final taken = {
          for (final r in ref.read(holidayRegionsProvider))
            if (r.country == country && r.region != null) r.region,
        };
        final names = [
          for (final c in codes)
            if (!taken.contains(c)) (code: c, name: regionName(c)),
        ]..sort((a, b) => a.name.compareTo(b.name));
        final picked = await _pick<String?>(
          context,
          title: _countryName(country, {
            for (final c in countries) c.code: c.name,
          }, zh),
          searchHint: l.calendarHolidaysSearch,
          items: [
            (value: null, label: l.calendarHolidaysWholeCountry),
            for (final n in names) (value: n.code, label: n.name),
          ],
        );
        if (picked == null) return;
        region = picked.value;
      }
    }
    if (!mounted) return;
    final added = await ref
        .read(holidayRegionsProvider.notifier)
        .add(country, region);
    if (!added || !mounted) return;
    final refresher = ref.read(holidayRefresherProvider);
    unawaited(
      refresher
          .refresh(ref.read(holidayRegionsProvider), {now.year})
          .then((_) {
            if (mounted) ref.invalidate(_holidayStatusProvider);
          })
          .catchError((Object _) {}),
    );
  }

  void _remove(HolidayRegion r, String name) {
    final l = AppLocalizations.of(context);
    final notifier = ref.read(holidayRegionsProvider.notifier);
    final previous = ref.read(holidayRegionsProvider);
    unawaited(
      showUndoableAction(
        context,
        run: () => notifier.remove(r.sourceId),
        undo: () => notifier.restore(previous),
        done: l.calendarHolidaysRemoved(name),
        failed: l.calendarHolidaysRemoveFailed(name),
        undone: l.calendarHolidaysRestored(name),
        undoFailed: l.calendarHolidayUndoFailed,
        busyKey: ('holiday-remove', r.sourceId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final zh = l.localeName.startsWith('zh');
    final apple = _isApple(context);
    final regions = ref.watch(holidayRegionsProvider);
    final names =
        ref.watch(holidayCountryNamesProvider).asData?.value ?? const {};

    String titleOf(HolidayRegion r) =>
        '${flagEmoji(r.country)}  ${_countryName(r.country, names, zh)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.calendarHolidays),
        actions: [
          if (apple)
            HmmIconButton(
              icon: Icons.add,
              tooltip: l.calendarHolidaysAdd,
              onPressed: _add,
            ),
          const HelpButton(helpId: HelpId.calendarHolidays),
        ],
      ),
      floatingActionButton: apple
          ? null
          : FloatingActionButton(
              tooltip: l.calendarHolidaysAdd,
              onPressed: _add,
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            for (final r in regions)
              Dismissible(
                key: Key('holiday-region-${r.sourceId}'),
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                ),
                onDismissed: (_) => _remove(
                  r,
                  r.region == null
                      ? _countryName(r.country, names, zh)
                      : regionName(r.region!),
                ),
                child: _RegionTile(
                  region: r,
                  title: titleOf(r),
                  subtitleName: r.region == null
                      ? l.calendarHolidaysWholeCountry
                      : regionName(r.region!),
                ),
              ),
            const Divider(height: 1),
            ListTile(
              key: const Key('holiday-mine'),
              leading: const Icon(Icons.edit_calendar_outlined),
              title: Text(l.calendarHolidaysMine),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/calendar/holidays/mine'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionTile extends ConsumerWidget {
  const _RegionTile({
    required this.region,
    required this.title,
    required this.subtitleName,
  });

  final HolidayRegion region;
  final String title;
  final String subtitleName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final status = ref
        .watch(_holidayStatusProvider(region.sourceId))
        .asData
        ?.value;
    final parts = <String>[subtitleName];
    if (status?.fetchedAt != null) {
      String date;
      try {
        date = DateFormat.yMMMd(l.localeName).format(status!.fetchedAt!);
      } catch (_) {
        date = ymd(status!.fetchedAt!);
      }
      parts.add(l.calendarHolidaysUpdated(date));
    }
    if (status != null && status.nextNotPublished) {
      parts.add(l.calendarHolidaysNotPublished(status.nextYear));
    }
    return ListTile(
      tileColor: Theme.of(context).scaffoldBackgroundColor,
      leading: Container(
        key: Key('holiday-swatch-${region.sourceId}'),
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: kHolidayPalette[region.color % kHolidayPalette.length],
          shape: BoxShape.circle,
        ),
      ),
      title: Text(title),
      subtitle: Text(parts.join(' · ')),
    );
  }
}

typedef _Item<T> = ({T value, String label});

/// A searchable list in a platform sheet. Null when dismissed; a chosen
/// value (possibly null, like "Whole country") comes wrapped in [_Chosen].
Future<_Chosen<T>?> _pick<T>(
  BuildContext context, {
  required String title,
  required String searchHint,
  required List<_Item<T>> items,
}) {
  final apple = _isApple(context);
  Widget sheet() => _PickerSheet<T>(
    title: title,
    searchHint: searchHint,
    items: items,
    apple: apple,
  );
  if (apple) {
    return showCupertinoModalPopup<_Chosen<T>>(
      context: context,
      builder: (ctx) => Material(
        color: Theme.of(ctx).colorScheme.surface,
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: sheet(),
        ),
      ),
    );
  }
  return showModalBottomSheet<_Chosen<T>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) =>
        SizedBox(height: MediaQuery.of(ctx).size.height * 0.8, child: sheet()),
  );
}

class _Chosen<T> {
  const _Chosen(this.value);
  final T value;
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.searchHint,
    required this.items,
    required this.apple,
  });

  final String title;
  final String searchHint;
  final List<_Item<T>> items;
  final bool apple;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final i in widget.items)
        if (q.isEmpty || i.label.toLowerCase().contains(q)) i,
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: widget.apple
              ? CupertinoSearchTextField(
                  key: const Key('holiday-picker-search'),
                  placeholder: widget.searchHint,
                  onChanged: (v) => setState(() => _q = v),
                )
              : TextField(
                  key: const Key('holiday-picker-search'),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: widget.searchHint,
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: shown.length,
            itemBuilder: (ctx, i) => ListTile(
              title: Text(shown[i].label),
              onTap: () => Navigator.of(ctx).pop(_Chosen<T>(shown[i].value)),
            ),
          ),
        ),
      ],
    );
  }
}
