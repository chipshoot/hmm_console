import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachments_pulled_signal.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../domain/contact_initials.dart';
import '../../domain/entities/contact.dart';

/// A contact's photo in a circle of [size]: the picked-but-unsaved [pending]
/// bytes, else the stored photo (unless [removed]), else initials, else a
/// person or building icon. Like iOS Contacts; the photo is centred and
/// fills the circle (no crop screen).
class ContactPhoto extends ConsumerWidget {
  const ContactPhoto({
    super.key,
    required this.contact,
    required this.size,
    this.pending,
    this.removed = false,
  });

  final Contact contact;
  final double size;
  final PickedImageBytes? pending;
  final bool removed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = _Initials(contact: contact, size: size);
    Widget child;
    final stored = removed ? null : contact.photo;
    if (pending != null) {
      child = Image.memory(
        pending!.bytes,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (stored != null) {
      // Watched only when there is a photo, so photo-less lists never open
      // the vault.
      final resolver = ref.watch(attachmentResolverProvider);
      final retryOn = ref.watch(attachmentsPulledSignalProvider);
      child = resolver.when(
        loading: () => fallback,
        error: (_, _) => fallback,
        data: (r) => AttachmentImage(
          ref: stored,
          resolver: r,
          fit: BoxFit.cover,
          loadingPlaceholder: fallback,
          errorPlaceholder: fallback,
          retryOn: retryOn,
        ),
      );
    } else {
      return fallback;
    }
    return ClipOval(
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.contact, required this.size});

  final Contact contact;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = contactInitials(contact);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
      child: initials == null
          ? Icon(
              contact.contactType == ContactType.organization
                  ? Icons.business_outlined
                  : Icons.person_outline,
              size: size * 0.5,
            )
          : Text(
              initials,
              style: TextStyle(
                fontSize: size * (initials.length > 1 ? 0.36 : 0.42),
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
