// lib/features/contacts/domain/pinyin_transcriber.dart

/// Romanizes Chinese name parts for sorting and search. Read-time only:
/// nothing it returns is ever persisted. Behind an interface so the library
/// can be swapped and tests can use a fake.
abstract interface class PinyinTranscriber {
  /// Surname mode: a polyphonic leading surname reads as a surname
  /// (曾 → zeng, 单 → shan). Toneless lowercase syllables for Han text;
  /// non-Han text is split on whitespace and passed through unchanged.
  List<String> family(String text);

  /// Same as [family] without surname handling.
  List<String> given(String text);
}
