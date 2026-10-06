import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/util/address_regions.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// Opens the searchable state / province picker for [country]: a Cupertino
/// popup on iOS, a Material bottom sheet elsewhere. Resolves to null when
/// dismissed. Searches code, English name, Chinese name and pinyin.
Future<AddressRegion?> showRegionPicker(
  BuildContext context, {
  required String country,
  required String title,
  String? selected,
}) {
  final sheet = _RegionSheet(
    country: country,
    title: title,
    selected: selected,
  );
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<AddressRegion>(
      context: context,
      builder: (_) => CupertinoPopupSurface(child: sheet),
    );
  }
  return showModalBottomSheet<AddressRegion>(
    context: context,
    isScrollControlled: true,
    builder: (_) => sheet,
  );
}

class _RegionSheet extends StatefulWidget {
  const _RegionSheet({
    required this.country,
    required this.title,
    this.selected,
  });

  final String country;
  final String title;
  final String? selected;

  @override
  State<_RegionSheet> createState() => _RegionSheetState();
}

class _RegionSheetState extends State<_RegionSheet> {
  late List<AddressRegion> _hits = regionsFor(widget.country);

  void _search(String q) =>
      setState(() => _hits = searchRegions(widget.country, q));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isIos = theme.platform == TargetPlatform.iOS;
    final height = MediaQuery.sizeOf(context).height * 0.7;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(widget.title, style: theme.textTheme.titleMedium),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: isIos
                      ? CupertinoSearchTextField(
                          key: const Key('region-search'),
                          placeholder: l.contactAddressRegionSearchHint,
                          onChanged: _search,
                        )
                      : TextField(
                          key: const Key('region-search'),
                          autofocus: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: l.contactAddressRegionSearchHint,
                          ),
                          onChanged: _search,
                        ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _hits.length,
                    itemBuilder: (context, i) {
                      final r = _hits[i];
                      final selected = r.code == widget.selected;
                      final style = selected
                          ? theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            )
                          : theme.textTheme.bodyLarge;
                      return InkWell(
                        key: Key('region-${r.code}'),
                        onTap: () => Navigator.of(context).pop(r),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(r.displayName, style: style),
                              ),
                              Text(
                                r.pinyin ?? r.code,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
