import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/driver_licence/presentation/screens/driver_licence_screen.dart';
import '../../features/driver_licence/presentation/screens/licence_show_screen.dart';
import '../../features/driver_licence/states/driver_licence_state.dart';
import 'route_names.dart';

/// The driver's-licence route subtree, spread into the app router.
///
/// Kept as a standalone list so it can be mounted in a bare [GoRouter] under
/// test — the app's own router sits behind an auth redirect, which would turn
/// "does /licence build the licence screen?" into an auth test.
final driverLicenceRoutes = <RouteBase>[
  GoRoute(
    path: '/licence',
    name: RouterNames.driverLicence.name,
    builder: (context, state) => const DriverLicenceScreen(),
    routes: [
      GoRoute(
        path: 'show',
        name: RouterNames.driverLicenceShow.name,
        builder: (context, state) => const _LicenceShowRoute(),
      ),
    ],
  ),
];

/// Reads the licence for the route, so `LicenceShowScreen` itself stays a pure
/// function of the licence it is given — that is what makes its side-mapping
/// testable without a repository.
class _LicenceShowRoute extends ConsumerWidget {
  const _LicenceShowRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licence = ref.watch(driverLicenceStateProvider).value;
    // Nothing saved yet: fall back to the editor rather than a dead screen.
    if (licence == null) return const DriverLicenceScreen();
    return LicenceShowScreen(licence: licence);
  }
}
