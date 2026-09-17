import 'package:flutter/material.dart';

import '../sync_indicator_state.dart';

/// A presence-style dot for one [SyncIndicatorState].
///
/// Sized to sit on the corner of a 36px avatar. Semantic colours are fixed
/// hex rather than theme tokens: green/orange/red must mean the same thing
/// on both light and dark, and the theme accent already means "this app".
class SyncStatusDot extends StatelessWidget {
  const SyncStatusDot({super.key, required this.state, this.size = 13});

  final SyncIndicatorState state;
  final double size;

  static const _synced = Color(0xFF34C759);
  static const _waiting = Color(0xFFFF9F0A);
  static const _failed = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    // Local mode: no cloud, no dot. Absence is the signal.
    if (state == SyncIndicatorState.none) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final colour = switch (state) {
      SyncIndicatorState.synced => _synced,
      SyncIndicatorState.syncing => scheme.primary,
      SyncIndicatorState.waiting => _waiting,
      SyncIndicatorState.failed => _failed,
      SyncIndicatorState.none => Colors.transparent,
    };
    // Motion is the only thing that says "happening now"; it is also the
    // first thing to drop for anyone who has asked for less of it.
    final pulse = state == SyncIndicatorState.syncing &&
        !MediaQuery.of(context).disableAnimations;

    return SizedBox(
      key: const Key('syncStatusDot'),
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (pulse) _Pulse(colour: colour, size: size),
          DecoratedBox(
            key: const Key('syncStatusFill'),
            decoration: BoxDecoration(
              color: colour,
              shape: BoxShape.circle,
              // Ring in the surface colour so the dot reads as sitting ON
              // the avatar rather than cut into it.
              border: Border.all(color: scheme.surface, width: 2.5),
            ),
            child: SizedBox(width: size, height: size),
          ),
        ],
      ),
    );
  }
}

/// An expanding, fading ring behind the dot while a sync is in flight.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.colour, required this.size});

  final Color colour;
  final double size;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const Key('syncStatusPulse'),
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        final grow = widget.size * 0.4 * t;
        return Positioned(
          left: -grow,
          top: -grow,
          right: -grow,
          bottom: -grow,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.colour.withValues(alpha: 0.6 * (1 - t)),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}
