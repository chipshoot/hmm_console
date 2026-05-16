import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../domain/entities/automobile.dart';

class AutomobileListTile extends ConsumerWidget {
  final Automobile automobile;
  final String distanceLabel;
  final VoidCallback? onTap;

  const AutomobileListTile({
    super.key,
    required this.automobile,
    this.distanceLabel = 'mi',
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _buildLeading(context, ref, colorScheme),
        title: Text(
          automobile.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (automobile.plate != null && automobile.plate!.isNotEmpty)
              automobile.plate!,
            if (automobile.color != null && automobile.color!.isNotEmpty)
              automobile.color!,
            '${automobile.meterReading} $distanceLabel',
          ].join(' • '),
        ),
        trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLeading(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) {
    final photo = automobile.primaryImage;
    if (photo == null) return _fallbackAvatar(colorScheme);

    final resolverAsync = ref.watch(attachmentResolverProvider);
    return resolverAsync.when(
      data: (resolver) => SizedBox(
        width: 40,
        height: 40,
        child: ClipOval(
          child: AttachmentImage(
            ref: photo,
            resolver: resolver,
            // Static placeholders inside the circle while the bytes
            // load / if they fail — keeps the layout stable.
            loadingPlaceholder: _fallbackAvatar(colorScheme),
            errorPlaceholder: _fallbackAvatar(colorScheme),
          ),
        ),
      ),
      loading: () => _fallbackAvatar(colorScheme),
      error: (_, _) => _fallbackAvatar(colorScheme),
    );
  }

  Widget _fallbackAvatar(ColorScheme colorScheme) {
    return CircleAvatar(
      backgroundColor: colorScheme.secondaryContainer,
      child: Icon(
        Icons.directions_car,
        color: colorScheme.onSecondaryContainer,
      ),
    );
  }
}
