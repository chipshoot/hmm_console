import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/presentation/widgets/media_toolbar.dart';

void main() {
  testWidgets('photo + camera buttons fire onPick with the right source',
      (t) async {
    AttachmentPickSource? picked;
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(
        bottomNavigationBar:
            MediaToolbar(onPick: (s) => picked = s, onPickFile: () {}),
      ),
    ));
    await t.tap(find.byIcon(Icons.photo_library_outlined));
    expect(picked, AttachmentPickSource.gallery);
    await t.tap(find.byIcon(Icons.camera_alt_outlined));
    expect(picked, AttachmentPickSource.camera);
  });

  testWidgets('PDF button fires onPickFile', (t) async {
    var tapped = false;
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(
        bottomNavigationBar:
            MediaToolbar(onPick: (_) {}, onPickFile: () => tapped = true),
      ),
    ));
    await t.tap(find.byIcon(Icons.picture_as_pdf_outlined));
    expect(tapped, isTrue);
  });
}
