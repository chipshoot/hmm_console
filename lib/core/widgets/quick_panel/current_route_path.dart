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
String currentRoutePath(GoRouter router) {
  final matches = router.routerDelegate.currentConfiguration.matches;
  if (matches.isEmpty) return '/';
  return matches.last.matchedLocation;
}
