import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/auth_change_provider.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/auth/presentation/presentation.dart';
import 'package:hmm_console/features/dashboard/presentation/presentation.dart';

final routerConfig = Provider<GoRouter>(
  (ref) => GoRouter(
    redirect: (context, state) {
      final userState = ref.watch(routerAuthStateProvider);

      final isAuthenticated = userState.value != null && userState.value!;

      final isAuthPath = state.fullPath?.startsWith('/auth') ?? false;
      if (!isAuthenticated && !isAuthPath) {
        return '/auth';
      }
      return null;
    },
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: RouterNames.dashboard.name,
        builder: (context, state) => DashboardScreen(),
      ),
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
  ),
);
