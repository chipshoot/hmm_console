import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/auth_change_provider.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/auth/presentation/presentation.dart';
import 'package:hmm_console/features/dashboard/presentation/presentation.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_create_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_edit_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_management_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_selector_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/gas_log_form_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/gas_log_list_screen.dart';

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
            builder: (context, state) => RegisterScreen(),
          ),
          GoRoute(
            path: 'forgot-password',
            name: RouterNames.forgotPassword.name,
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/automobiles',
        name: RouterNames.automobileSelector.name,
        builder: (context, state) => const AutomobileSelectorScreen(),
        routes: [
          GoRoute(
            path: 'manage',
            name: RouterNames.automobileManagement.name,
            builder: (context, state) =>
                const AutomobileManagementScreen(),
            routes: [
              GoRoute(
                path: 'new',
                name: RouterNames.automobileCreate.name,
                builder: (context, state) =>
                    const AutomobileCreateScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                name: RouterNames.automobileEdit.name,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return AutomobileEditScreen(automobileId: id);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/gas-logs',
        name: RouterNames.gasLogList.name,
        builder: (context, state) => const GasLogListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: RouterNames.gasLogForm.name,
            builder: (context, state) => const GasLogFormScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return GasLogFormScreen(gasLogId: id);
            },
          ),
        ],
      ),
    ],
  ),
);
