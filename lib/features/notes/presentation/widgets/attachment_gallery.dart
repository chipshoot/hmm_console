import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/attachment_providers.dart';

class AttachmentGallery extends ConsumerWidget {
  const AttachmentGallery({super.key, required this.refs});

  final List<AttachmentRef> refs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (refs.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: refs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _Thumb(reference: refs[i]),
      ),
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.reference});
  final AttachmentRef reference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolverAsync = ref.watch(attachmentResolverProvider);
    return resolverAsync.when(
      loading: () => const SizedBox(
          width: 120, child: Center(child: CircularProgressIndicator())),
      error: (err, stack) => const _Placeholder(),
      data: (resolver) => FutureBuilder(
        future: resolver.resolve(reference),
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes == null) return const _Placeholder();
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(bytes, width: 120, fit: BoxFit.cover),
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) => Container(
        width: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_not_supported),
      );
}
