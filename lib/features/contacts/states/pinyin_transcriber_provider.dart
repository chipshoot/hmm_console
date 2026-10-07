// lib/features/contacts/states/pinyin_transcriber_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pinyin_pro_transcriber.dart';
import '../domain/pinyin_transcriber.dart';

/// Watched only by the contacts list and the contact edit form, so the
/// dictionary is first touched on those screens, never on the dashboard.
/// Tests override it with a fake.
final pinyinTranscriberProvider = Provider<PinyinTranscriber>(
  (ref) => const DefaultPinyinTranscriber(),
);
