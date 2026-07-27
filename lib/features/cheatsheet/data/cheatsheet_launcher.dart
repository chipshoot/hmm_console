import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/util/launch_actions.dart';
import '../domain/entities/cheatsheet_source.dart';

/// Raised when a URI could not be handed to any app. Callers surface this to
/// the user — unlike a markdown link, a cheatsheet value somebody deliberately
/// tapped should not fail silently.
class LaunchActionException implements Exception {
  const LaunchActionException(this.uri);

  final Uri uri;

  @override
  String toString() => 'LaunchActionException: could not launch $uri';
}

/// The URI [action] implies for [value], or null when there is nothing to
/// launch (`none`, or a blank value).
Uri? uriForAction(ValueAction action, String value) {
  if (value.trim().isEmpty) return null;
  return switch (action) {
    ValueAction.call => telUri(value),
    ValueAction.map => mapsUri(value),
    ValueAction.none => null,
  };
}

/// Opens [value] according to [action].
///
/// Throws [LaunchActionException] when no app can handle it. The detail screen
/// catches that and shows a message; failing loudly here is what lets it.
Future<void> launchAction(ValueAction action, String value) async {
  final uri = uriForAction(action, value);
  if (uri == null) return;
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) throw LaunchActionException(uri);
}

/// Overridable so widget tests never reach url_launcher.
final launchActionProvider =
    Provider<Future<void> Function(ValueAction, String)>(
  (ref) => launchAction,
);
