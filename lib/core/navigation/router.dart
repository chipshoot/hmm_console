import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/core/navigation/router_config.dart';

class AppRouter {
  static Future<T?> go<T>(
    context,
    RouterNames routerName, {
    Map<String, String> pathParameters = const {},
  }) {
    return GoRouter.of(
      context,
    ).pushNamed<T>(routerName.name, pathParameters: pathParameters);
  }

  static Provider<GoRouter> config = routerConfig;
}
