// lib/features/notes/query/note_text_index.dart
import '../../../core/util/search_normalize.dart';
import '../../contacts/domain/contact_name.dart';
import '../../contacts/domain/pinyin_transcriber.dart';

/// Folded search text for one note. Read-time only; never persisted.
class NoteTextIndex {
  const NoteTextIndex({
    required this.titleFolded,
    required this.bodyFolded,
    required this.parentTitleFolded,
    required this.tagNamesFolded,
    required this.pinyinFull,
    required this.pinyinInitials,
    required this.body,
  });

  final String titleFolded;
  final String bodyFolded;
  final String parentTitleFolded;
  final List<String> tagNamesFolded;

  /// Each Han run of title / parent title / tags, joined (`zhangsan`) and
  /// space-separated (`zhang san`); empty without Han text.
  final String pinyinFull;

  /// Initials per Han run (`zs`); empty without Han text.
  final String pinyinInitials;

  /// Unfolded plain text, for previews of entity notes and range mapping.
  final String body;
}

NoteTextIndex buildNoteTextIndex({
  required String title,
  required String body,
  String? parentTitle,
  List<String> tagNames = const [],
  required PinyinTranscriber pinyin,
}) {
  final full = <String>[];
  final initials = <String>[];
  for (final text in [title, parentTitle ?? '', ...tagNames]) {
    if (!ContactName.hasChinese(text)) continue;
    for (final (han, run) in ContactName.hanRuns(text)) {
      if (!han) continue;
      final syl = pinyin.given(run).where((s) => s.isNotEmpty).toList();
      if (syl.isEmpty) continue;
      full
        ..add(syl.join())
        ..add(syl.join(' '));
      initials.add(syl.map((s) => s[0]).join());
    }
  }
  return NoteTextIndex(
    titleFolded: foldForMatch(title),
    bodyFolded: foldForMatch(body),
    parentTitleFolded: foldForMatch(parentTitle ?? ''),
    tagNamesFolded: [for (final t in tagNames) foldForMatch(t)],
    pinyinFull: full.join(' '),
    pinyinInitials: initials.join(' '),
    body: body,
  );
}

typedef NoteTextKey = ({
  int noteId,
  String version,
  String locale,
  String parentTitle,
  String tags,
});

/// One entry per note id; a different key for the same id is a miss.
class NoteTextIndexCache {
  final _entries = <int, (NoteTextKey, NoteTextIndex)>{};

  NoteTextIndex? lookup(NoteTextKey key) {
    final e = _entries[key.noteId];
    return e != null && e.$1 == key ? e.$2 : null;
  }

  void store(NoteTextKey key, NoteTextIndex index) =>
      _entries[key.noteId] = (key, index);

  void retainOnly(Set<int> noteIds) =>
      _entries.removeWhere((id, _) => !noteIds.contains(id));

  int get length => _entries.length;
}
