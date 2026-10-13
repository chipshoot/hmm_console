import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../../../core/data/attachments/widgets/fullscreen_image.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../core/data/vault/vault_session.dart';
import '../../../../core/data/attachments/widgets/sensitive_attachment_image.dart';
import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../data/cheatsheet_launcher.dart';
import '../../data/cheatsheet_resolver.dart';
import '../../domain/entities/card_style.dart';
import '../../domain/entities/cheatsheet_card.dart';
import '../../domain/entities/cheatsheet_row.dart';
import '../../domain/entities/cheatsheet_source.dart';
import '../../states/cheatsheets_state.dart';
import '../../states/derived_field_registry_provider.dart';
import '../look/card_header.dart';
import '../look/cheatsheet_palette.dart';

final cheatsheetResolverProvider = Provider<CheatsheetResolver>(
  (ref) => CheatsheetResolver(
    ref.watch(hmmNoteRepositoryProvider),
    ref.watch(derivedFieldRegistryProvider),
  ),
);

/// Opens the note a row points at.
///
/// Rows reference notes by **uuid** (stable across devices) but the note route
/// takes the **local int id**, so this is a lookup, not a string swap. A
/// source that hasn't synced to this device yet has no local row to open — the
/// row already renders as "source removed", so this does nothing rather than
/// navigating somewhere wrong.
final cheatsheetOpenSourceProvider =
    Provider<void Function(BuildContext, String)>(
      (ref) => (context, noteUuid) async {
        final note = await ref
            .read(hmmNoteRepositoryProvider)
            .getNoteByUuid(noteUuid);
        if (note == null || !context.mounted) return;
        context.pushNamed(
          RouterNames.noteDetail.name,
          pathParameters: {'id': '${note.id}'},
        );
      },
    );

final cheatsheetEditCardProvider =
    Provider<void Function(BuildContext, String)>(
      (ref) =>
          (context, cardId) => context.pushNamed(
            RouterNames.cheatsheetEdit.name,
            pathParameters: {'id': cardId},
          ),
    );

/// Resolves every row of a card, in order.
final cheatsheetResolvedRowsProvider = FutureProvider.autoDispose
    .family<List<ResolvedValue>, String>((ref, cardId) async {
      final cards = await ref.watch(cheatsheetsStateProvider.future);
      final card = _findCard(cards, cardId);
      if (card == null) return const [];

      final resolver = ref.watch(cheatsheetResolverProvider);
      final out = <ResolvedValue>[];
      for (final row in card.rows) {
        out.add(await resolver.resolve(row));
      }
      return out;
    });

CheatsheetCard? _findCard(List<CheatsheetCard> cards, String id) {
  for (final c in cards) {
    if (c.id == id) return c;
  }
  return null;
}

/// Read-only view of a card with its values resolved live.
class CheatsheetDetailScreen extends ConsumerWidget {
  const CheatsheetDetailScreen({super.key, required this.cardId});

  final String cardId;

  /// Confirms, then deletes. Destructive and one tap from the card, so it asks
  /// first — and says plainly that the referenced notes survive, since a card
  /// is a view onto them, not a container for them.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    // Captured before the await: `ref.read` throws once this widget is
    // unmounted, and the dialog is an await gap during which that can happen.
    final cheatsheets = ref.read(cheatsheetsStateProvider.notifier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.cheatsheetDeleteTitle),
        content: const Text(
          'The notes it references are not deleted — only this card.',
        ),
        actions: [
          TextButton(
            key: const Key('delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            key: const Key('delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await cheatsheets.remove(cardId);
    } catch (e) {
      // A delete that silently didn't happen is worse than one that failed
      // loudly — the user walks away believing the card is gone.
      // Type only: the error text can quote stored values.
      debugPrint(
        'CheatsheetDetail: deleting card $cardId failed '
        '(${e.runtimeType}); the card is still stored.',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.cheatsheetDeleteFailed)));
      return;
    }
    // The card this screen shows no longer exists; staying would strand the
    // user on a not-found state.
    if (context.mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cards = ref.watch(cheatsheetsStateProvider);
    final card = _findCard(cards.value ?? const [], cardId);

    if (cards.isLoading && card == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (card == null) {
      return Scaffold(
        body: Center(
          key: const Key('detail-not-found'),
          child: Text(l.cheatsheetGone),
        ),
      );
    }

    final resolved = ref.watch(cheatsheetResolvedRowsProvider(cardId));
    final brightness = Theme.of(context).brightness;
    final bar = headerBarColors(card, brightness);
    final look = card.look;
    final palette = CheatsheetPalette.of(look.theme, brightness);

    return Scaffold(
      appBar: AppBar(
        // The bar carries the card's colour so edit/delete stay legible
        // against it; a cover card gets the darkened theme with white.
        backgroundColor: bar.background,
        foregroundColor: bar.foreground,
        title: Text(card.title),
        actions: [
          const HelpButton(helpId: HelpId.cheatsheetDetail),
          HmmIconButton(
            key: const Key('detail-edit'),
            icon: Icons.edit_outlined,
            tooltip: l.cheatsheetEditTooltip,
            onPressed: () =>
                ref.read(cheatsheetEditCardProvider)(context, cardId),
          ),
          HmmIconButton(
            key: const Key('detail-delete'),
            icon: Icons.delete_outline,
            tooltip: l.cheatsheetDeleteTooltip,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        children: [
          CardHeader(key: const Key('detail-header'), card: card),
          ...resolved.when<List<Widget>>(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [Center(child: Text('$e'))],
            data: (values) => [
              for (var i = 0; i < card.rows.length; i++)
                _RowTile(
                  index: i,
                  row: card.rows[i],
                  value: i < values.length ? values[i] : const ResolvedValue(),
                  layout: look.layout,
                  colors: palette,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row in either layout. The value widget — and with it every state
/// (unbound "—", "source removed", an image, a tappable call/map value) — is
/// built once and placed by [layout], so both layouts behave identically.
class _RowTile extends ConsumerWidget {
  const _RowTile({
    required this.index,
    required this.row,
    required this.value,
    required this.layout,
    required this.colors,
  });

  final int index;
  final CheatsheetRow row;
  final ResolvedValue value;
  final CardLayout layout;
  final CardColors colors;

  Future<void> _launch(BuildContext context, WidgetRef ref, String text) async {
    final l = AppLocalizations.of(context);
    try {
      await ref.read(launchActionProvider)(row.valueAction, text);
    } on Exception catch (e) {
      // Exceptions only. A missing handler app is an expected, recoverable
      // outcome worth reporting; an Error is a defect, and showing it as
      // "could not open that" would disguise a bug as a normal failure.
      // Type only: the error can quote the value (a number or address).
      debugPrint(
        'CheatsheetDetail: launching ${row.valueAction.name} failed '
        '(${e.runtimeType}); showed the user a message.',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.cheatsheetOpenFailed)));
    }
  }

  Widget _valueWidget(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).disabledColor,
      fontStyle: FontStyle.italic,
    );
    if (value.unbound) {
      return Text('—', key: Key('row-$index-unbound'), style: muted);
    }
    if (value.missing) {
      return Text(
        'source removed',
        key: Key('row-$index-missing'),
        style: muted,
      );
    }
    if (value.image != null) {
      return _ImageValue(
        key: Key('row-$index-image'),
        image: value.image!,
        label: row.label,
      );
    }
    final text = value.text ?? '';
    final action = row.valueAction;
    return InkWell(
      key: Key('row-$index-value'),
      onTap: action == ValueAction.none
          ? null
          : () => _launch(context, ref, text),
      child: Text(
        text,
        style: action == ValueAction.none
            ? null
            : TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget? _openSourceButton(BuildContext context, WidgetRef ref) {
    final CheatsheetSource? source = row.source;
    if (!row.openSource || source == null) return null;
    final l = AppLocalizations.of(context);
    return HmmIconButton(
      key: Key('row-$index-open-source'),
      icon: Icons.open_in_new,
      tooltip: l.cheatsheetOpenSourceTooltip,
      onPressed: () =>
          ref.read(cheatsheetOpenSourceProvider)(context, source.noteUuid),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valueWidget = _valueWidget(context, ref);
    final trailing = _openSourceButton(context, ref);

    if (layout == CardLayout.facts) {
      return ListTile(
        title: Text(row.label),
        subtitle: valueWidget,
        trailing: trailing,
      );
    }

    final emoji = row.emoji;
    return Container(
      key: Key('keypoint-$index'),
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.background, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number on the theme colour in its own text colour, so the pair
          // is covered by the palette's AA test.
          // At least a 28px circle; two digits or large text grow it into a
          // pill instead of clipping the number.
          Container(
            key: Key('keypoint-$index-number'),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (emoji != null && isSingleEmoji(emoji))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(emoji, key: Key('keypoint-$index-emoji')),
                      ),
                    Expanded(
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                valueWidget,
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// An image row: a photo ID or insurance card, shown as a tappable thumbnail.
///
/// Sensitive images (a licence is always one) go through
/// [SensitiveAttachmentImage], so a locked vault shows a tap-to-unlock lock
/// rather than a broken image — the two must never look alike to someone
/// holding out their phone at an accident scene.
class _ImageValue extends ConsumerStatefulWidget {
  const _ImageValue({super.key, required this.image, required this.label});

  final VaultRef image;
  final String label;

  @override
  ConsumerState<_ImageValue> createState() => _ImageValueState();
}

class _ImageValueState extends ConsumerState<_ImageValue> {
  @override
  void initState() {
    super.initState();
    // The session status can be stale on first build; without a refresh the
    // tile shows the lock over an image it could already decrypt.
    if (widget.image.sensitive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(vaultSessionProvider.notifier).refresh();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolverAsync = ref.watch(attachmentResolverProvider);
    final resolver = resolverAsync.value;
    final unlocked =
        !widget.image.sensitive ||
        ref.watch(vaultSessionProvider) == VaultStatus.unlocked;

    final Widget image;
    if (resolverAsync.hasError) {
      // A resolver that failed to build will never produce one; a spinner
      // would wait forever on a card someone is showing at a roadside.
      image = Center(
        key: Key(
          '${widget.key is ValueKey ? (widget.key as ValueKey).value : 'image'}-error',
        ),
        child: const Icon(Icons.broken_image_outlined),
      );
    } else if (resolver == null) {
      image = const Center(child: CircularProgressIndicator.adaptive());
    } else if (widget.image.sensitive) {
      image = SensitiveAttachmentImage(
        ref: widget.image,
        resolver: resolver,
        fit: BoxFit.contain,
        semanticLabel: widget.label,
      );
    } else {
      image = AttachmentImage(
        ref: widget.image,
        resolver: resolver,
        fit: BoxFit.contain,
        semanticLabel: widget.label,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 180,
          width: double.infinity,
          // Only an image that can actually render opens full screen; while
          // locked, the tap belongs to the lock placeholder's unlock flow.
          child: unlocked
              ? GestureDetector(
                  onTap: () => showFullscreenImage(context, widget.image),
                  child: image,
                )
              : image,
        ),
      ),
    );
  }
}
