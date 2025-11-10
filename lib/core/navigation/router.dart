import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/auth/presentation/presentation.dart';

class AppRouter {
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
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
        ],
      ),
    ],
  );
}
