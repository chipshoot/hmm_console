import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models/hmm_note.dart';

/// What "Share…" hands to the system share sheet: the subject, then the
/// body after a blank line. A note without a body shares its subject alone.
String shareTextFor(HmmNote note) {
  final body = note.content;
  if (body == null || body.isEmpty) return note.subject;
  return '${note.subject}\n\n$body';
}

/// Seam over the system share sheet, so tests need no platform channel.
abstract interface class NoteSharer {
  Future<void> shareText(String text);
}

/// The only place `share_plus` is used.
class SharePlusNoteSharer implements NoteSharer {
  const SharePlusNoteSharer();

  @override
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}

final noteSharerProvider = Provider<NoteSharer>(
  (ref) => const SharePlusNoteSharer(),
);
