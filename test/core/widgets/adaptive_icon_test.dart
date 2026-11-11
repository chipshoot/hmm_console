import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/widgets/adaptive_icon.dart';

void main() {
  for (final (platform, apple) in [
    (TargetPlatform.iOS, true),
    (TargetPlatform.macOS, true),
    (TargetPlatform.android, false),
  ]) {
    testWidgets('$platform picks the ${apple ? 'Apple' : 'Material'} glyph', (
      t,
    ) async {
      late IconData picked;
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (c) {
              picked = adaptiveIcon(
                c,
                material: Icons.tune,
                apple: CupertinoIcons.line_horizontal_3_decrease_circle,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        picked,
        apple ? CupertinoIcons.line_horizontal_3_decrease_circle : Icons.tune,
      );
    });
  }
}
