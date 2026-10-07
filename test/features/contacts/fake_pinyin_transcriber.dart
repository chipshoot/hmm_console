// test/features/contacts/fake_pinyin_transcriber.dart
import 'package:hmm_console/features/contacts/domain/contact_name.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';

/// Deterministic table transcriber. An unmapped Han character throws, so a
/// test can never pass on pinyin it did not declare. [throwOn] inputs throw a
/// StateError to model a dictionary failure.
class FakePinyinTranscriber implements PinyinTranscriber {
  FakePinyinTranscriber({this.throwOn = const {}});

  final Set<String> throwOn;
  int calls = 0;

  static const _compound = {'欧阳': ['ou', 'yang']};
  static const _chars = {
    '张': ['zhang'],
    '伟': ['wei'],
    '吕': ['lǚ'],
    '李': ['li'],
    '丽': ['li'],
    '王': ['wang'],
    '娜': ['na'],
    '明': ['ming'],
    '曾': ['zeng'],
    '林': ['lin'],
    '人': ['ren'],
    '民': ['min'],
    '医': ['yi'],
    '院': ['yuan'],
  };

  @override
  List<String> family(String text) => _run(text, surname: true);

  @override
  List<String> given(String text) => _run(text, surname: false);

  List<String> _run(String text, {required bool surname}) {
    calls++;
    if (throwOn.contains(text)) throw StateError('dictionary unavailable');
    final out = <String>[];
    for (final (han, part) in ContactName.hanRuns(text.trim())) {
      if (!han) {
        out.addAll(part.split(RegExp(r'\s+')).where((s) => s.isNotEmpty));
        continue;
      }
      var rest = part;
      if (surname) {
        for (final e in _compound.entries) {
          if (rest.startsWith(e.key)) {
            out.addAll(e.value);
            rest = rest.substring(e.key.length);
            break;
          }
        }
      }
      for (final r in rest.runes) {
        final s = _chars[String.fromCharCode(r)];
        if (s == null) throw ArgumentError('unmapped Han character');
        out.addAll(s);
      }
    }
    return out;
  }
}
