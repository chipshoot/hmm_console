import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/glucose_units.dart';

/// The mg/dL | mmol/L choice: Cupertino segments on iOS, Material otherwise.
Widget glucoseUnitToggle({
  Key key = const Key('glucose-unit'),
  required bool apple,
  required GlucoseUnit unit,
  required ValueChanged<GlucoseUnit> onChanged,
}) {
  if (apple) {
    return CupertinoSlidingSegmentedControl<GlucoseUnit>(
      key: key,
      groupValue: unit,
      children: {
        for (final u in GlucoseUnit.values)
          u: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(u.wire),
          ),
      },
      onValueChanged: (u) {
        if (u != null) onChanged(u);
      },
    );
  }
  return SegmentedButton<GlucoseUnit>(
    key: key,
    showSelectedIcon: false,
    segments: [
      for (final u in GlucoseUnit.values)
        ButtonSegment(value: u, label: Text(u.wire)),
    ],
    selected: {unit},
    onSelectionChanged: (v) => onChanged(v.first),
  );
}
