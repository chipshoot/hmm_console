import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../core/data/attachments/widgets/sensitive_attachment_image.dart';
import '../../../../core/data/vault/encrypted_vault_store.dart'
    show VaultLockedException;
import '../../../../core/data/vault/vault_session.dart';
import '../../domain/entities/card_style.dart';
import '../../domain/entities/cheatsheet_card.dart';
import 'cheatsheet_palette.dart';

/// Title ink over a cover photo.
const Color kCoverTextColor = Color(0xFFFFFFFF);

/// Subtitle ink over a cover photo (90% white).
const Color kCoverSubtitleColor = Color(0xE6FFFFFF);

/// The band drawn behind the title/subtitle block over a cover. A photo can
/// be pure white exactly where the text sits, so the text never relies on
/// the gradient scrim alone: 60% black keeps white text at 5.7:1 and the
/// 90%-white subtitle at 5.0:1 even over white (`card_surface_test.dart`).
const Color kCoverTextBand = Color(0x99000000);

/// The laid-out height of [lines] lines of [style] at the ambient text scale,
/// so a tile or header can grow with large accessibility text instead of
/// overflowing. With [text] and [maxWidth], measures that text as it wraps
/// at that width instead, still capped at [lines] lines.
double lookTextHeight(
  BuildContext context,
  TextStyle? style, {
  int lines = 1,
  String? text,
  double maxWidth = double.infinity,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text ?? List.filled(lines, 'Ag').join('\n'),
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: lines,
    ellipsis: text == null ? null : '\u2026',
  )..layout(maxWidth: maxWidth);
  final height = painter.height;
  painter.dispose();
  return height;
}

/// Text colours for whatever is drawn on a [CardSurface], and whether a
/// sensitive cover is being withheld because the vault is locked.
class CardInk {
  const CardInk({
    required this.foreground,
    required this.subtitle,
    required this.overCover,
    required this.coverLocked,
    this.textBand = const Color(0x00000000),
  });

  final Color foreground;
  final Color subtitle;

  /// Painted behind the title/subtitle block: [kCoverTextBand] over a cover,
  /// transparent over a theme (the palette is already AA there).
  final Color textBand;
  final bool overCover;
  final bool coverLocked;
}

/// Draws a [CardPattern] in [ink] (the foreground at [kPatternInkOpacity]).
///
/// The palette's AA contrast assumes the ink lands as ONE layer, so each
/// pattern is built as a single path drawn once: where shapes overlap (grid
/// crossings) the fill is still painted a single time, never stacked.
class CardPatternPainter extends CustomPainter {
  CardPatternPainter({required this.pattern, required this.ink});

  final CardPattern pattern;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final paint = Paint()..color = ink;
    switch (pattern) {
      case CardPattern.none:
        return;
      case CardPattern.dots:
        for (var y = 6.0; y < size.height; y += 12) {
          for (var x = 6.0; x < size.width; x += 12) {
            path.addOval(Rect.fromCircle(center: Offset(x, y), radius: 1.6));
          }
        }
      case CardPattern.stripes:
        for (var x = -size.height; x < size.width; x += 10) {
          path
            ..moveTo(x, size.height)
            ..lineTo(x + size.height, 0);
        }
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
      case CardPattern.grid:
        // Rects share one nonZero-filled path: crossings are painted once.
        for (var x = 0.0; x <= size.width; x += 14) {
          path.addRect(Rect.fromLTWH(x, 0, 1, size.height));
        }
        for (var y = 0.0; y <= size.height; y += 14) {
          path.addRect(Rect.fromLTWH(0, y, size.width, 1));
        }
      case CardPattern.waves:
        // 14px apart with +-3 amplitude: the 1.5px strokes never touch.
        for (var y = 8.0; y < size.height + 8; y += 14) {
          path.moveTo(0, y);
          for (var x = 0.0; x <= size.width; x += 4) {
            path.lineTo(x, y + 3 * math.sin(x / 24 * 2 * math.pi));
          }
        }
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CardPatternPainter oldDelegate) =>
      oldDelegate.pattern != pattern || oldDelegate.ink != ink;
}

/// The card's background — theme colour + pattern, or the cover photo under
/// a darkening scrim — with [builder]'s content on top in matching ink.
///
/// Failure is always the theme: a missing or undecryptable cover falls back
/// silently (logging the card id and error type only), and a sensitive cover
/// on a locked vault shows the theme with `ink.coverLocked`. Only when
/// [allowUnlock] is true (the detail header) does a locked cover offer the
/// shared tap-to-unlock tile; a wallet tile must never prompt.
class CardSurface extends ConsumerStatefulWidget {
  const CardSurface({
    super.key,
    required this.card,
    required this.builder,
    this.pendingCoverBytes,
    this.allowUnlock = false,
    this.coverCacheWidth,
  });

  final CheatsheetCard card;
  final Widget Function(BuildContext context, CardInk ink) builder;

  /// A just-picked cover not yet in the vault (the designer preview).
  final Uint8List? pendingCoverBytes;

  final bool allowUnlock;

  /// Decode the cover no wider than this many device pixels (tiles only; the
  /// detail header decodes at full size).
  final int? coverCacheWidth;

  @override
  ConsumerState<CardSurface> createState() => _CardSurfaceState();
}

class _CoverResult {
  const _CoverResult(this.bytes, {this.locked = false});
  final Uint8List? bytes;
  final bool locked;
}

class _CardSurfaceState extends ConsumerState<CardSurface> {
  Future<_CoverResult>? _cover;
  String? _coverPath;

  @override
  void initState() {
    super.initState();
    // The session status can be stale on first build; without a refresh the
    // surface would show the lock over a cover it could already decrypt.
    if (widget.card.cover?.sensitive ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(vaultSessionProvider.notifier).refresh();
      });
    }
  }

  Future<_CoverResult> _load(VaultRef cover) async {
    final cardId = widget.card.id;
    try {
      final resolver = await ref.read(attachmentResolverProvider.future);
      final bytes = await resolver.resolve(cover);
      if (bytes == null) {
        debugPrint(
          'CardSurface: card $cardId cover is missing; '
          'showing its theme.',
        );
      }
      return _CoverResult(bytes);
    } on VaultLockedException {
      // Relocked between the status check and the read.
      return const _CoverResult(null, locked: true);
    } catch (e) {
      // Type only: the error can quote the vault path.
      debugPrint(
        'CardSurface: card $cardId cover could not load '
        '(${e.runtimeType}); showing its theme.',
      );
      return const _CoverResult(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final look = card.look;
    final colors = CheatsheetPalette.of(
      look.theme,
      Theme.of(context).brightness,
    );

    final pending = widget.pendingCoverBytes;
    if (pending != null) return _overCover(context, pending);

    final cover = card.cover;
    if (cover == null) return _themed(context, colors, look.pattern);

    final unlockResolver = widget.allowUnlock && cover.sensitive
        ? ref.watch(attachmentResolverProvider).value
        : null;

    if (cover.sensitive &&
        ref.watch(vaultSessionProvider) != VaultStatus.unlocked) {
      // Drop the memo: decrypted bytes must not outlive a relock, and a
      // cached "locked" read must not outlive the next unlock.
      _forgetCover();
      return _themed(
        context,
        colors,
        look.pattern,
        lockedCover: cover,
        unlockResolver: unlockResolver,
      );
    }

    // Memoised per cover path so a rebuild never re-reads the vault.
    if (_cover == null || _coverPath != cover.path) {
      _coverPath = cover.path;
      _cover = _load(cover);
    }
    return FutureBuilder<_CoverResult>(
      future: _cover,
      builder: (context, snap) {
        final result = snap.data;
        final bytes = result?.bytes;
        if (bytes != null) return _overCover(context, bytes);
        final locked = result?.locked ?? false;
        // Relocked mid-read: forget it so the next build (the session
        // catching up, then an unlock) reads again instead of reusing it.
        if (locked) _forgetCover();
        return _themed(
          context,
          colors,
          look.pattern,
          lockedCover: locked ? cover : null,
          unlockResolver: unlockResolver,
        );
      },
    );
  }

  void _forgetCover() {
    _cover = null;
    _coverPath = null;
  }

  Widget _themed(
    BuildContext context,
    CardColors colors,
    CardPattern pattern, {
    VaultRef? lockedCover,
    IAttachmentResolver? unlockResolver,
  }) {
    final locked = lockedCover != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          key: const Key('card-surface-themed'),
          decoration: BoxDecoration(color: colors.background),
          child: CustomPaint(
            painter: CardPatternPainter(
              pattern: pattern,
              ink: colors.patternInk,
            ),
          ),
        ),
        widget.builder(
          context,
          CardInk(
            foreground: colors.foreground,
            subtitle: colors.subtitle,
            overCover: false,
            coverLocked: locked,
          ),
        ),
        // Null checks on the parameters themselves, so both promote.
        if (lockedCover != null && widget.allowUnlock && unlockResolver != null)
          Positioned(
            top: 12,
            right: 12,
            width: 72,
            height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SensitiveAttachmentImage(
                ref: lockedCover,
                resolver: unlockResolver,
              ),
            ),
          ),
      ],
    );
  }

  Widget _overCover(BuildContext context, Uint8List bytes) => Stack(
    fit: StackFit.expand,
    children: [
      Image.memory(
        bytes,
        key: const Key('card-surface-cover'),
        fit: BoxFit.cover,
        cacheWidth: widget.coverCacheWidth,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      ),
      const DecoratedBox(
        key: Key('card-surface-scrim'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.4, 1],
            colors: [Color(0x59000000), Color(0x00000000), Color(0xA6000000)],
          ),
        ),
      ),
      widget.builder(
        context,
        const CardInk(
          foreground: kCoverTextColor,
          subtitle: kCoverSubtitleColor,
          overCover: true,
          coverLocked: false,
          textBand: kCoverTextBand,
        ),
      ),
    ],
  );
}
