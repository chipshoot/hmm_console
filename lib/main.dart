import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hmm_console/core/navigation/router.dart';
import 'package:hmm_console/core/theme/theme.dart';
import 'firebase_options.dart';
import 'core/di/service_locator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize dependency injection
  ServiceLocator.setupDependencies();

  // if(kDebugMode) {
  //   await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  // }

  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: "hmm message",
      theme: AppTheme.lightThemeData,
      darkTheme: AppTheme.darkThemeData,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(AppRouter.config),
    );
    //return MaterialApp(home: DashboardScreen());
  }
}
