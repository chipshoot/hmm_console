import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/auth_change_provider.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/auth/presentation/presentation.dart';
import 'package:hmm_console/features/dashboard/presentation/presentation.dart';
import 'package:hmm_console/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:hmm_console/features/onboarding/providers/onboarding_provider.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/insurance_policies_screen.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/vehicle_notes_screen.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/insurance_policy_form_screen.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/scheduled_service_form_screen.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/scheduled_services_screen.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/service_record_form_screen.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/service_records_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_create_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_edit_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_management_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_selector_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/gas_log_form_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/gas_log_list_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/gas_station_management_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_shell_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/raw_content_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/subsystems_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/subsystem_notes_screen.dart';
import 'package:hmm_console/features/settings/presentation/screens/settings_screen.dart';

final routerConfig = Provider<GoRouter>(
  (ref) => GoRouter(
    redirect: (context, state) {
      final userState = ref.watch(routerAuthStateProvider);

      final isAuthenticated = userState.value != null && userState.value!;

      final isAuthPath = state.fullPath?.startsWith('/auth') ?? false;
      if (!isAuthenticated && !isAuthPath) {
        return '/auth';
      }
      // Phase E onboarding gate: authenticated user who hasn't picked
      // a path yet (new install / migrating from another device) gets
      // routed to the onboarding screen before they can reach the
      // dashboard. The screen marks the flag itself and goes home on
      // either branch.
      final onboardingDone = ref.watch(onboardingCompletedProvider);
      final isOnboardingPath = state.fullPath == '/onboarding';
      if (isAuthenticated && !onboardingDone && !isOnboardingPath) {
        return '/onboarding';
      }
      // Conversely, if the user lands back on /onboarding after it's
      // done (e.g. via a deep link), bounce them home — the flow is
      // one-shot.
      if (isAuthenticated && onboardingDone && isOnboardingPath) {
        return '/';
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
        path: '/onboarding',
        name: RouterNames.onboarding.name,
        builder: (context, state) => const OnboardingScreen(),
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
              GoRoute(
                path: ':id/insurance',
                name: RouterNames.insurancePolicies.name,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return InsurancePoliciesScreen(automobileId: id);
                },
                routes: [
                  GoRoute(
                    path: 'new',
                    name: RouterNames.insurancePolicyCreate.name,
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      return InsurancePolicyFormScreen(automobileId: id);
                    },
                  ),
                  GoRoute(
                    path: ':policyId/edit',
                    name: RouterNames.insurancePolicyEdit.name,
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      final policyId =
                          int.parse(state.pathParameters['policyId']!);
                      return InsurancePolicyFormScreen(
                        automobileId: id,
                        policyId: policyId,
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: ':id/services',
                name: RouterNames.serviceRecords.name,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ServiceRecordsScreen(automobileId: id);
                },
                routes: [
                  GoRoute(
                    path: 'new',
                    name: RouterNames.serviceRecordCreate.name,
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      return ServiceRecordFormScreen(automobileId: id);
                    },
                  ),
                  GoRoute(
                    path: ':recordId/edit',
                    name: RouterNames.serviceRecordEdit.name,
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      final recordId =
                          int.parse(state.pathParameters['recordId']!);
                      return ServiceRecordFormScreen(
                        automobileId: id,
                        recordId: recordId,
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: ':id/scheduled-services',
                name: RouterNames.scheduledServices.name,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ScheduledServicesScreen(automobileId: id);
                },
                routes: [
                  GoRoute(
                    path: 'new',
                    name: RouterNames.scheduledServiceCreate.name,
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      return ScheduledServiceFormScreen(automobileId: id);
                    },
                  ),
                  GoRoute(
                    path: ':scheduleId/edit',
                    name: RouterNames.scheduledServiceEdit.name,
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      final scheduleId =
                          int.parse(state.pathParameters['scheduleId']!);
                      return ScheduledServiceFormScreen(
                        automobileId: id,
                        scheduleId: scheduleId,
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: ':id/notes',
                name: RouterNames.vehicleNotes.name,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return VehicleNotesScreen(automobileId: id);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/gas-stations',
        name: RouterNames.gasStationManagement.name,
        builder: (context, state) => const GasStationManagementScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: RouterNames.settings.name,
        builder: (context, state) => const SettingsScreen(),
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
      GoRoute(
        path: '/notes',
        name: RouterNames.notesList.name,
        builder: (context, state) => const NotesShellScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: RouterNames.noteCreate.name,
            builder: (context, state) {
              final p = state.uri.queryParameters['parent'];
              return NoteEditorScreen(
                  presetParentId: p == null ? null : int.tryParse(p));
            },
          ),
          GoRoute(
            path: 'subsystems',
            name: RouterNames.subsystems.name,
            builder: (context, state) => const SubsystemsScreen(),
            routes: [
              GoRoute(
                path: ':anchorId',
                name: RouterNames.subsystemNotes.name,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['anchorId']!);
                  final name = state.uri.queryParameters['name'] ?? 'Subsystem';
                  return SubsystemNotesScreen(anchorId: id, anchorName: name);
                },
              ),
            ],
          ),
          GoRoute(
            path: ':id',
            name: RouterNames.noteDetail.name,
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return NoteDetailScreen(noteId: id);
            },
            routes: [
              GoRoute(
                path: 'edit',
                name: RouterNames.noteEdit.name,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return NoteEditorScreen(noteId: id);
                },
              ),
              GoRoute(
                path: 'raw',
                name: RouterNames.noteRaw.name,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return RawContentScreen(noteId: id);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  ),
);
