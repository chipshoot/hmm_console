import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/adaptive_icon.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/glucose_range.dart';
import '../../domain/glucose_reading.dart';
import '../../domain/glucose_units.dart';

String glucoseContextLabel(GlucoseContext c, AppLocalizations l) => switch (c) {
  GlucoseContext.fasting => l.glucoseContextFasting,
  GlucoseContext.beforeMeal => l.glucoseContextBeforeMeal,
  GlucoseContext.afterMeal => l.glucoseContextAfterMeal,
  GlucoseContext.bedtime => l.glucoseContextBedtime,
  GlucoseContext.other => l.glucoseContextOther,
};

String _bandLabel(GlucoseBand b, AppLocalizations l) => switch (b) {
  GlucoseBand.below => l.glucoseBandBelow,
  GlucoseBand.inRange => l.glucoseBandIn,
  GlucoseBand.above => l.glucoseBandAbove,
};

/// Readable on light and dark surfaces.
Color glucoseBandColor(GlucoseBand b, ColorScheme scheme) => switch (b) {
  GlucoseBand.below => Colors.orange.shade700,
  GlucoseBand.inRange => Colors.green.shade600,
  GlucoseBand.above => scheme.error,
};

/// One reading: value in the display unit, tag, band against the range (when
/// set), the recorded time and a Health or typed marker. Tap opens it; long
/// press opens the row menu; swiping left asks to delete (the callback
/// decides; the row never leaves the list by itself).
class GlucoseRow extends StatelessWidget {
  const GlucoseRow({
    super.key,
    required this.reading,
    required this.unit,
    required this.range,
    required this.onTap,
    required this.onMenu,
    required this.onDelete,
  });

  final GlucoseReading reading;
  final GlucoseUnit unit;
  final GlucoseRange? range;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = reading;
    final w = r.takenAt.wall;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: w.hour, minute: w.minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final band = bandFor(r.glucose, range);
    final fromHealth = r.source == GlucoseSource.appleHealth;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final tile = ListTile(
      title: Text(
        r.glucose.display(unit),
        style: r.draft ? TextStyle(color: theme.disabledColor) : null,
      ),
      subtitle: r.context == null
          ? null
          : Text(glucoseContextLabel(r.context!, l)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (band != null) ...[
            Icon(
              Icons.circle,
              size: 10,
              color: glucoseBandColor(band, theme.colorScheme),
            ),
            const SizedBox(width: 4),
            Text(_bandLabel(band, l), style: muted),
            const SizedBox(width: 12),
          ],
          Text(time, style: muted),
          const SizedBox(width: 8),
          Icon(
            fromHealth
                ? adaptiveIcon(
                    context,
                    material: Icons.favorite_border,
                    apple: CupertinoIcons.heart,
                  )
                : adaptiveIcon(
                    context,
                    material: Icons.edit_outlined,
                    apple: CupertinoIcons.pencil,
                  ),
            size: 16,
            semanticLabel: fromHealth ? l.glucoseFromHealth : l.glucoseTyped,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: onTap,
      onLongPress: onMenu,
    );

    return Dismissible(
      key: ValueKey('glucose-row-${r.id}'),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          Icons.delete_outline,
          semanticLabel: l.commonDelete,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      // The delete runs and the list rebuilds from the repository's change
      // stream, so Undo can bring the row back.
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: tile,
    );
  }
}
