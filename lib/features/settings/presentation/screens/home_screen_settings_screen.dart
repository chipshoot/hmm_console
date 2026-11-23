import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../dashboard/domain/home_tiles.dart';
import '../../providers/home_hidden_tiles_provider.dart';

/// Settings -> Home screen: a switch per home tile. Synced across devices;
/// the last visible tile's switch is disabled.
class HomeScreenSettingsScreen extends ConsumerWidget {
  const HomeScreenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isApple =
        theme.platform == TargetPlatform.iOS ||
        theme.platform == TargetPlatform.macOS;
    final hidden = ref.watch(homeHiddenTilesProvider);
    final visibleCount = homeTiles
        .where((t) => !hidden.contains(t.route))
        .length;

    return AppScaffold(
      title: l.settingsHomeScreen,
      actions: const [HelpButton(helpId: HelpId.homeScreenSettings)],
      slivers: [
        SliverList.list(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                l.homeScreenSettingsHint,
                style: theme.textTheme.bodySmall,
              ),
            ),
            for (final tile in homeTiles)
              Builder(
                builder: (context) {
                  final visible = !hidden.contains(tile.route);
                  final isLast = visible && visibleCount == 1;
                  final void Function(bool)? onChanged = isLast
                      ? null
                      : (v) => ref
                            .read(homeHiddenTilesProvider.notifier)
                            .setVisible(tile.route, v);
                  final key = ValueKey('home-tile-switch-${tile.route}');
                  return ListTile(
                    leading: Text(
                      tile.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(homeTileTitle(tile, l)),
                    subtitle: isLast
                        ? Text(l.homeScreenSettingsLastVisible)
                        : null,
                    trailing: isApple
                        ? CupertinoSwitch(
                            key: key,
                            value: visible,
                            onChanged: onChanged,
                          )
                        : Switch(
                            key: key,
                            value: visible,
                            onChanged: onChanged,
                          ),
                    onTap: onChanged == null ? null : () => onChanged(!visible),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}
