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
    this.onRefresh,
    this.bottomBar,
    this.rekeyNavBarOnTitleChange = false,
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

  /// Pull-to-refresh: a [CupertinoSliverRefreshControl] under the iOS/macOS
  /// nav bar, a [RefreshIndicator] around the scroll view elsewhere.
  final Future<void> Function()? onRefresh;

  /// Optional bar pinned under the scroll view (e.g. a bulk-action bar). The
  /// caller wraps it in a SafeArea.
  final Widget? bottomBar;

  /// Re-creates the iOS nav bar when [title] changes. The bar keeps showing
  /// its first title when only the text changes (e.g. "3 selected"), but a
  /// re-key resets its scroll state, so only screens whose title changes in
  /// place opt in.
  final bool rekeyNavBarOnTitleChange;

  bool _isApple(TargetPlatform p) =>
      p == TargetPlatform.iOS || p == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final bg = backgroundColor ?? context.appColors.groupedBackground;

    final Widget navBar = _isApple(platform)
        ? CupertinoSliverNavigationBar(
            key: rekeyNavBarOnTitleChange ? ValueKey(title) : null,
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
            // With a drawer, Material would put its own menu button here and
            // drop the back arrow; the page owns its menu action instead.
            automaticallyImplyLeading: drawer == null || leading != null,
            leading:
                leading ??
                (drawer != null && ModalRoute.of(context)?.canPop == true
                    ? const BackButton()
                    : null),
            actions: actions,
            backgroundColor: bg,
            pinned: true,
          );

    final refresh = onRefresh;
    final scrollView = CustomScrollView(
      slivers: [
        navBar,
        if (refresh != null && _isApple(platform))
          CupertinoSliverRefreshControl(onRefresh: refresh),
        ...slivers,
      ],
    );

    return Scaffold(
      backgroundColor: bg,
      drawer: drawer,
      drawerEnableOpenDragGesture: false,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      body: refresh == null || _isApple(platform)
          ? scrollView
          : RefreshIndicator(onRefresh: refresh, child: scrollView),
    );
  }
}
