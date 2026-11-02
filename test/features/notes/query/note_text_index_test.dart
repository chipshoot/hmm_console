import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';
import 'package:hmm_console/features/notes/query/note_text_index.dart';

class _Fake implements PinyinTranscriber {
  static const _m = {'张': 'zhang', '三': 'san'};
  @override
  List<String> given(String text) => [
    for (final r in text.runes)
      _m[String.fromCharCode(r)] ?? String.fromCharCode(r),
  ];
  @override
  List<String> family(String text) => given(text);
}

NoteTextIndex _idx(String title) =>
    buildNoteTextIndex(title: title, body: 'Body Ünder', pinyin: _Fake());

void main() {
  test('Han title gets pinyin full and initials', () {
    final i = _idx('张三 notes');
    expect(i.pinyinFull, contains('zhangsan'));
    expect(i.pinyinFull, contains('zhang san'));
    expect(i.pinyinInitials, contains('zs'));
    expect(i.titleFolded, '张三 notes');
    expect(i.bodyFolded, 'body under');
    expect(i.body, 'Body Ünder');
  });

  test('no Han text leaves pinyin empty; tags and parent are folded', () {
    final i = buildNoteTextIndex(
      title: 'Café',
      body: '',
      parentTitle: 'Car',
      tagNames: ['À'],
      pinyin: _Fake(),
    );
    expect(i.pinyinFull, '');
    expect(i.pinyinInitials, '');
    expect(i.titleFolded, 'cafe');
    expect(i.parentTitleFolded, 'car');
    expect(i.tagNamesFolded, ['a']);
  });

  test('Han in parent title and tags is covered', () {
    final i = buildNoteTextIndex(
      title: 'x',
      body: '',
      parentTitle: '张',
      tagNames: ['三'],
      pinyin: _Fake(),
    );
    expect(i.pinyinInitials, 'z s');
  });

  test('cache key includes version and locale', () {
    final cache = NoteTextIndexCache();
    final idx = _idx('a');
    const k = (
      noteId: 1,
      version: 'a1',
      locale: 'en',
      parentTitle: '',
      tags: '',
    );
    cache.store(k, idx);
    expect(cache.lookup(k), same(idx));
    expect(
      cache.lookup((
        noteId: 1,
        version: 'a2',
        locale: 'en',
        parentTitle: '',
        tags: '',
      )),
      isNull,
    );
    expect(
      cache.lookup((
        noteId: 1,
        version: 'a1',
        locale: 'zh',
        parentTitle: '',
        tags: '',
      )),
      isNull,
    );
  });

  test('retainOnly drops purged notes', () {
    final cache = NoteTextIndexCache();
    final idx = _idx('a');
    cache.store((
      noteId: 1,
      version: '',
      locale: 'en',
      parentTitle: '',
      tags: '',
    ), idx);
    cache.store((
      noteId: 2,
      version: '',
      locale: 'en',
      parentTitle: '',
      tags: '',
    ), idx);
    cache.retainOnly({2});
    expect(cache.length, 1);
  });
}
