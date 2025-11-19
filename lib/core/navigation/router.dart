import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/auth/presentation/presentation.dart';

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

  static GoRouter config = GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(
        path: '/auth',
        name: RouterNames.login.name,
        builder: (context, state) => LoginScreen(),
        routes: [
          GoRoute(
            path: 'register',
            name: RouterNames.register.name,
            builder: (context, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: 'forgot-password',
            name: RouterNames.forgotPassword.name,
            builder: (context, state) => ForgotPasswordScreen(),
          ),
        ],
      ),
    ],
  );
}
