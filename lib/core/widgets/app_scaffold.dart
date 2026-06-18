import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Platform-adaptive scaffold with a large title. iOS/macOS get a
/// [CupertinoSliverNavigationBar] (collapsing large title); Android gets an
/// MD3 [SliverAppBar.large]. Body is supplied as [slivers].
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.backgroundColor,
    this.drawer,
  });

  final String title;
  final List<Widget> slivers;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  /// Optional left slide-in panel, opened only via a button (open-drag gesture
  /// is disabled so it never conflicts with the iOS back-swipe).
  final Widget? drawer;

  bool _isApple(TargetPlatform p) =>
      p == TargetPlatform.iOS || p == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final bg = backgroundColor ?? context.appColors.groupedBackground;

    final Widget navBar = _isApple(platform)
        ? CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            leading: leading,
            trailing: actions == null
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: actions!),
            backgroundColor: bg,
            border: null,
          )
        : SliverAppBar.large(
            title: Text(title),
            leading: leading,
            actions: actions,
            backgroundColor: bg,
            pinned: true,
          );

    return Scaffold(
      backgroundColor: bg,
      drawer: drawer,
      drawerEnableOpenDragGesture: false,
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(slivers: [navBar, ...slivers]),
    );
  }
}
