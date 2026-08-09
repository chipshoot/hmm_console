import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// The path of the screen the user is actually looking at.
///
/// Do NOT use `router.routeInformationProvider.value.uri.path` or
/// `routerDelegate.currentConfiguration.uri` for this. Both report the
/// *location*, and go_router does not move the location on an imperative
/// `push()` — it appends an [ImperativeRouteMatch] instead. This app
/// navigates by push everywhere (dashboard tiles, launcher), so those
/// APIs return "/" no matter which screen is on top.
///
/// That was a real bug: the quick panel keyed its actions off the location
/// and therefore showed the home-screen action set (Sync alone) on every
/// screen in the app.
///
/// The last entry in `currentConfiguration.matches` is the top of the
/// navigation stack whether it got there by `go()` or `push()`, and its
/// `matchedLocation` is the concrete path with parameters filled in
/// (e.g. `/automobiles/manage/7/services`) — which is what the panel needs
/// to build a vehicle-scoped create action.
/// Uses [RouteMatchList.last], go_router's own "last leaf" getter, rather
/// than `.matches.last`. They differ once a ShellRoute exists: the raw list's
/// last element is then the `ShellRouteMatch`, whose `matchedLocation` is the
/// shell's location, not the child screen's — which would reintroduce this
/// same bug wearing a different hat. There is no ShellRoute in the app today;
/// this keeps it from becoming a landmine if one is added.
String currentRoutePath(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  if (config.isEmpty) {
    // Not a real "user is at home" state — route resolution produced
    // nothing, and the panel will render the home action set as though it
    // had. Log rather than assert: a router with no matches is a normal
    // setup in widget tests that mount the overlay without one, so crashing
    // debug builds over it would be wrong.
    debugPrint('currentRoutePath: GoRouter reported no matches; '
        'falling back to "/" (panel will show the home actions)');
    return '/';
  }
  return config.last.matchedLocation;
}
