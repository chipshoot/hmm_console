import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_media_card_list.dart';

// A valid 1x1 transparent PNG so Image.memory can decode it.
final _pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC');

PickedImageBytes _pick() =>
    PickedImageBytes(bytes: _pngBytes, originalName: 'a.jpg');

void main() {
  testWidgets('renders one card per pending pick with a remove button',
      (t) async {
    var removed = -1;
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: NoteMediaCardList(
            saved: const [],
            pending: [_pick(), _pick()],
            onRemovePending: (i) => removed = i,
          ),
        ),
      ),
    ));
    expect(find.byType(NoteMediaCard), findsNWidgets(2));
    expect(find.byIcon(Icons.close), findsNWidgets(2));
    await t.tap(find.byIcon(Icons.close).first);
    expect(removed, 0);
  });

  testWidgets('readonly (no pending) shows no remove buttons', (t) async {
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: NoteMediaCardList(
              saved: const [], pending: [_pick()], readOnly: true),
        ),
      ),
    ));
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
