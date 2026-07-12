import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/inline_insert.dart';

void main() {
  test('inserts a pending image at the caret and moves the caret past it', () {
    final c = TextEditingController(text: 'ABCD');
    c.selection = const TextSelection.collapsed(offset: 2); // between B and C
    insertImageAtCursor(c, 'u1', 'photo.png');
    expect(c.text,
        'AB\n\n![photo.png](hmm-attachment://pending/u1)\n\nCD');
    // caret sits right after the inserted block (before "CD")
    expect(c.selection.baseOffset,
        'AB\n\n![photo.png](hmm-attachment://pending/u1)\n\n'.length);
  });

  test('appends when there is no valid selection', () {
    final c = TextEditingController(text: 'X');
    // default selection is -1 (invalid)
    insertImageAtCursor(c, 'u2', 'a.png');
    expect(c.text, 'X\n\n![a.png](hmm-attachment://pending/u2)\n\n');
  });
}
