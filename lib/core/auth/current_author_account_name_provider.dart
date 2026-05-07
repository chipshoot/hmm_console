import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/current_user_provider.dart';
import '../data/local/database.dart';
import '../data/repository_providers.dart';

/// Active user's IdP-issued subject claim. Used everywhere we need to scope
/// local data to the signed-in user (matches `Author.AccountName` server-side,
/// which the Hmm.ServiceApi `CurrentUserAuthorProvider` keys off).
///
/// Throws if no user is signed in. The router guards every feature screen with
/// an auth-redirect, so anything reaching this provider is by definition
/// post-login — a throw here surfaces routing bugs loudly instead of silently
/// returning anonymous data.
final currentAuthorAccountNameProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError(
      'currentAuthorAccountNameProvider read with no signed-in user. '
      'A feature screen reached the data layer before the auth-redirect '
      'kicked in — check router_config.dart.',
    );
  }
  return user.uid;
});

/// Materialized [Author] row for the current user. Auto-provisions on first
/// read (mirrors the server-side `CurrentUserAuthorProvider.CreateUserAuthor`
/// behaviour so first-write paths just work).
final currentAuthorProvider = FutureProvider<Author>((ref) async {
  final accountName = ref.watch(currentAuthorAccountNameProvider);
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(authorRepositoryProvider);
  return repo.getOrCreateDefaultAuthor(
    accountName,
    description: user?.displayName,
    avatarUrl: user?.photoUrl,
  );
});
