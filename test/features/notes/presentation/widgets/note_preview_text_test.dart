import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_preview_text.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(extensions: const [AppColors.light]),
  home: Scaffold(body: child),
);

List<TextSpan> _leaves(WidgetTester t) {
  final root = t.widget<RichText>(find.byType(RichText).first).text as TextSpan;
  final out = <TextSpan>[];
  void walk(InlineSpan s) {
    if (s is TextSpan) {
      if (s.text != null) out.add(s);
      s.children?.forEach(walk);
    }
  }

  walk(root);
  return out;
}

void main() {
  test('runs carry styles and no raw markers', () {
    final runs = previewRuns(
      '# Head\n**b** _i_ `c` [l](https://x)\n- [ ] milk\n- one',
    );
    expect(previewPlain(runs), 'Head b i c l ☐ milk • one');
    expect(runs.firstWhere((r) => r.text == 'b').style, PreviewStyle.bold);
    expect(runs.firstWhere((r) => r.text == 'i').style, PreviewStyle.italic);
    expect(runs.firstWhere((r) => r.text == 'c').style, PreviewStyle.code);
    expect(runs.firstWhere((r) => r.text == 'l').style, PreviewStyle.link);
  });

  test('checked task, images, html and fenced code', () {
    final runs = previewRuns(
      '- [x] done\n\n![p](a.jpg)\n\n```\ncode\n```\n\nend <b>bold</b>',
    );
    expect(previewPlain(runs), '☑ done end bold');
  });

  test('loose task list keeps its boxes', () {
    expect(previewPlain(previewRuns('- [x] a\n\n- [ ] b')), '☑ a ☐ b');
  });

  test('image-only note has an empty preview', () {
    expect(
      previewPlain(previewRuns('![p](hmm-attachment://attachments/a.jpg)')),
      isEmpty,
    );
  });

  test('long note stops at the line budget', () {
    expect(
      previewPlain(previewRuns('word ' * 20000)).length,
      lessThanOrEqualTo(400),
    );
  });

  test('only a bounded prefix of a long note is parsed', () {
    // A reference definition past the first 4,000 characters is never seen,
    // so the early [foo] stays plain text instead of becoming a link.
    final md = '[foo] intro\n\n${'filler line\n' * 500}\n[foo]: http://x\n';
    final runs = previewRuns(md);
    expect(previewPlain(runs), startsWith('[foo] intro'));
    expect(runs.where((r) => r.style == PreviewStyle.link), isEmpty);
    // Short notes still resolve it.
    final short = previewRuns('[foo] intro\n\n[foo]: http://x\n');
    expect(short.first, (text: 'foo', style: PreviewStyle.link));
  });

  test('the prefix cut never splits a surrogate pair', () {
    final md = '${'a' * 3999}\u{1F600}${'b' * 100}';
    expect(boundedPreviewSource(md).runes.last, 0x1F600);
    expect(boundedPreviewSource(md).length, 4001);
  });

  test('the prefix is cut at a line boundary when there is one', () {
    final md = '${'x' * 3000}\n${'y' * 2000}';
    expect(boundedPreviewSource(md), '${'x' * 3000}\n');
  });

  testWidgets('highlights a matched word without changing the text', (t) async {
    await t.pumpWidget(
      _wrap(
        NotePreviewText(
          runs: previewRuns('Buy **Crème**'),
          maxLines: 2,
          highlightWords: ['creme'],
        ),
      ),
    );
    final leaves = _leaves(t);
    expect(leaves.map((s) => s.text).join(), 'Buy Crème');
    final hit = leaves.singleWhere((s) => s.text == 'Crème');
    expect(hit.style?.backgroundColor, isNotNull);
    expect(
      leaves.where((s) => s.text == 'Buy ').single.style?.backgroundColor,
      isNull,
    );
  });

  testWidgets('a match splits a run at its edges', (t) async {
    await t.pumpWidget(
      _wrap(
        NotePreviewText(
          runs: previewRuns('abcdef'),
          maxLines: 1,
          highlightWords: ['cd'],
        ),
      ),
    );
    final leaves = _leaves(t);
    expect(leaves.map((s) => s.text).toList(), ['ab', 'cd', 'ef']);
    expect(leaves[1].style?.backgroundColor, isNotNull);
  });

  testWidgets('plain runs (entity notes) render verbatim', (t) async {
    await t.pumpWidget(
      _wrap(
        const NotePreviewText(
          runs: [(text: 'Plain **text**', style: PreviewStyle.plain)],
          maxLines: 3,
        ),
      ),
    );
    expect(_leaves(t).map((s) => s.text).join(), 'Plain **text**');
    expect(t.widget<RichText>(find.byType(RichText).first).maxLines, 3);
  });
}
