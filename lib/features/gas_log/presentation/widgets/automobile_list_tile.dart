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
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner photo. Vehicles benefit from prominence (the photo
            // carries plate / color / condition that the subtitle can
            // only approximate); few cars per user, so the vertical
            // real estate isn't expensive.
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildBanner(ref, colorScheme),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          automobile.displayName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() => [
        if (automobile.plate != null && automobile.plate!.isNotEmpty)
          automobile.plate!,
        if (automobile.color != null && automobile.color!.isNotEmpty)
          automobile.color!,
        '${automobile.meterReading} $distanceLabel',
      ].join(' • ');

  Widget _buildBanner(WidgetRef ref, ColorScheme cs) {
    final photo = automobile.primaryImage;
    if (photo == null) return _fallbackBanner(cs);

    final resolverAsync = ref.watch(attachmentResolverProvider);
    return resolverAsync.when(
      data: (resolver) => AttachmentImage(
        ref: photo,
        resolver: resolver,
        fit: BoxFit.cover,
        loadingPlaceholder: _fallbackBanner(cs),
        errorPlaceholder: _fallbackBanner(cs),
      ),
      loading: () => _fallbackBanner(cs),
      error: (_, _) => _fallbackBanner(cs),
    );
  }

  Widget _fallbackBanner(ColorScheme cs) {
    return Container(
      color: cs.secondaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.directions_car,
        size: 56,
        color: cs.onSecondaryContainer,
      ),
    );
  }
}
