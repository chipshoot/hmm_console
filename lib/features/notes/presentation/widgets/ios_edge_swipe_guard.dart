import 'package:flutter/material.dart';

/// On iOS a drag that starts this close to the left edge belongs to the
/// route's back swipe, not to a row's start swipe pane.
const double kIosBackSwipeEdge = 20.0;

/// Tells [builder] whether a row's swipe panes are enabled. On iOS it is
/// false while a touch is down within [kIosBackSwipeEdge] of the left edge,
/// so the back swipe wins; on other platforms it is always true.
class IosEdgeSwipeGuard extends StatefulWidget {
  const IosEdgeSwipeGuard({super.key, required this.builder});

  final Widget Function(bool enabled) builder;

  @override
  State<IosEdgeSwipeGuard> createState() => _IosEdgeSwipeGuardState();
}

class _IosEdgeSwipeGuardState extends State<IosEdgeSwipeGuard> {
  bool _edgeDown = false;

  void _setEdge(bool v) {
    if (v != _edgeDown) setState(() => _edgeDown = v);
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(!_edgeDown);
    if (Theme.of(context).platform != TargetPlatform.iOS) return child;
    return Listener(
      onPointerDown: (e) => _setEdge(e.position.dx < kIosBackSwipeEdge),
      onPointerUp: (_) => _setEdge(false),
      onPointerCancel: (_) => _setEdge(false),
      child: child,
    );
  }
}
