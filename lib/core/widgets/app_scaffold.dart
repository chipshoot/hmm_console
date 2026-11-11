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
    this.leadingActions,
    this.largeTitleFollowsPane = false,
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

  /// Buttons placed right after the back button (or [leading]) on the left
  /// of the top bar.
  final List<Widget>? leadingActions;

  /// iOS: choose the large-title layout from this scaffold's own shape, not
  /// the screen's. A tall pane on a landscape iPad then keeps its large title
  /// row instead of squeezing the title between the top-bar buttons.
  final bool largeTitleFollowsPane;

  bool _isApple(TargetPlatform p) =>
      p == TargetPlatform.iOS || p == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final bg = backgroundColor ?? context.appColors.groupedBackground;
    final extra = leadingActions ?? const <Widget>[];
    final canPop = ModalRoute.of(context)?.canPop == true;
    final titleText = Text(title, maxLines: 1, overflow: TextOverflow.ellipsis);

    final Widget navBar;
    if (_isApple(platform)) {
      final Widget? appleLeading = extra.isEmpty
          ? leading
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading ??
                    (canPop
                        // Not CupertinoNavigationBarBackButton: it asserts
                        // while the bar is copied into a route transition.
                        ? CupertinoButton(
                            key: const Key('appScaffoldBack'),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(44, 44),
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: Semantics(
                              label: MaterialLocalizations.of(
                                context,
                              ).backButtonTooltip,
                              child: const Icon(CupertinoIcons.back, size: 28),
                            ),
                          )
                        : const SizedBox.shrink()),
                ...extra,
              ],
            );
      final Widget bar = CupertinoSliverNavigationBar(
        key: rekeyNavBarOnTitleChange ? ValueKey(title) : null,
        largeTitle: titleText,
        leading: appleLeading,
        trailing: actions == null
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions!),
        backgroundColor: bg,
        border: null,
      );
      navBar = !largeTitleFollowsPane
          ? bar
          // The bar picks its layout from the orientation; give it the
          // pane's shape so only this subtree sees the change. Measured
          // inside the scroll view so the screen's tree (and its scroll
          // position) stays the same when the option flips.
          : SliverLayoutBuilder(
              builder: (context, c) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(c.crossAxisExtent, c.viewportMainAxisExtent),
                ),
                child: bar,
              ),
            );
    } else {
      final Widget? base =
          leading ?? (drawer != null && canPop ? const BackButton() : null);
      final implyBack = drawer == null || leading != null;
      final Widget? materialLeading = extra.isEmpty
          ? base
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                base ??
                    (canPop && implyBack
                        ? const BackButton()
                        : const SizedBox.shrink()),
                ...extra,
              ],
            );
      navBar = SliverAppBar.large(
        title: titleText,
        // With a drawer, Material would put its own menu button here and
        // drop the back arrow; the page owns its menu action instead.
        automaticallyImplyLeading: implyBack,
        leading: materialLeading,
        leadingWidth: extra.isEmpty
            ? null
            : (canPop || leading != null ? 56.0 : 8.0) + 48.0 * extra.length,
        actions: actions,
        backgroundColor: bg,
        pinned: true,
      );
    }

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
