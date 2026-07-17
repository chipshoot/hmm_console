// Sensitive-attachment path convention. Sensitivity is carried by a
// dedicated `sensitive` path segment so the storage layer can decide
// to encrypt/decrypt from the path alone — IVaultStore signatures and
// callers stay unchanged. Kept out of vault_path.dart (which mirrors a
// .NET spec) so that cross-repo file is untouched.

import '../../util/uuid.dart';
import 'vault_path.dart';

/// The reserved path segment that marks an attachment as sensitive.
const String sensitiveSegment = 'sensitive';

/// True iff any POSIX segment of [path] equals [sensitiveSegment].
bool isSensitiveVaultPath(String path) => path.split('/').contains(sensitiveSegment);

/// Build a validated vault path for a sensitive attachment:
/// `attachments/note-<noteId>/sensitive/<uuid>.<ext>`.
String buildSensitiveAttachmentPath({required int noteId, required String ext}) {
  return vaultRelativePathJoin([
    'attachments',
    'note-$noteId',
    sensitiveSegment,
    '${generateUuid()}.$ext',
  ]);
}
