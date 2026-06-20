import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';

/// Opens a file at [path] in the OS default app. Wrapped in a provider so
/// tests can stub the platform call.
typedef FileOpener = Future<void> Function(String path);

final fileOpenerProvider = Provider<FileOpener>(
  (ref) => (path) => OpenFilex.open(path).then((_) {}),
);

/// Resolve [attachment]'s bytes, write them to a temp file (named after the
/// ref), and open it with the OS. Returns an error string on failure, null on
/// success. Best-effort — never throws.
Future<String?> openAttachment(WidgetRef ref, AttachmentRef attachment) async {
  try {
    final resolver = await ref.read(attachmentResolverProvider.future);
    final bytes = await resolver.resolve(attachment);
    if (bytes == null) return 'File is not available on this device.';
    final name = attachment is VaultRef
        ? (attachment.originalName ?? p.basename(attachment.path))
        : 'attachment';
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes);
    await ref.read(fileOpenerProvider)(file.path);
    return null;
  } catch (e) {
    return 'Could not open file: $e';
  }
}
