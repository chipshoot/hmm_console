import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import '../data/repository_providers.dart';
import 'owner_id.dart';

/// Materialized [Author] row for the device owner. Keyed by the owner id, so
/// it resolves in every data mode with nobody signed in. Auto-provisions on
/// first read (mirrors the server-side `CurrentUserAuthorProvider` behaviour
/// so first-write paths just work).
final currentAuthorProvider = FutureProvider<Author>((ref) async {
  final ownerId = await ref.watch(ownerIdProvider.future);
  final repo = ref.watch(authorRepositoryProvider);
  return repo.getOrCreateDefaultAuthor(ownerId);
});
