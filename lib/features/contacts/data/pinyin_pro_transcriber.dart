// lib/features/contacts/data/pinyin_pro_transcriber.dart
import 'package:pinyin_pro_flutter/pinyin_pro_flutter.dart' as pp;

import '../domain/contact_name.dart';
import '../domain/pinyin_transcriber.dart';

/// [PinyinTranscriber] on `pinyin_pro_flutter`, chosen by the 2026-10-06
/// spike. Han runs are transcribed one at a time so mixed text never depends
/// on the library's non-Chinese handling.
class DefaultPinyinTranscriber implements PinyinTranscriber {
  const DefaultPinyinTranscriber();

  static final _ws = RegExp(r'\s+');

  @override
  List<String> family(String text) => _transcribe(text, surname: true);

  @override
  List<String> given(String text) => _transcribe(text, surname: false);

  List<String> _transcribe(String text, {required bool surname}) {
    final out = <String>[];
    var first = true;
    for (final (han, run) in ContactName.hanRuns(text.trim())) {
      if (han) {
        out.addAll(_han(run, surname: surname && first));
      } else {
        out.addAll(run.split(_ws).where((s) => s.isNotEmpty));
      }
      first = false;
    }
    return out;
  }

  static List<String> _han(String run, {required bool surname}) {
    final result = pp.pinyin(
      run,
      options: pp.PinyinOptions(
        toneType: pp.ToneType.none,
        returnType: pp.PinyinReturnType.array,
        surname: surname ? pp.SurnameMode.head : pp.SurnameMode.off,
      ),
    );
    return [
      for (final s in result as List)
        if ((s as String).trim().isNotEmpty) s.trim().toLowerCase(),
    ];
  }
}
