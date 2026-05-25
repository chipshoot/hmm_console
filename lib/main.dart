import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/i18n/locale_provider.dart';
import 'package:hmm_console/core/navigation/router.dart';
import 'package:hmm_console/core/theme/theme.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'firebase_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // if(kDebugMode) {
  //   await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  // }

  final db = await createHmmDatabase();

  runApp(ProviderScope(
    overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
    ],
    child: const MainApp(),
  ));
}

/// ConsumerStatefulWidget rather than ConsumerWidget so we have an
/// `initState`/`dispose` to hook the auto-sync controller's binding
/// observer in. Reading `syncControllerProvider` in `initState` is what
/// constructs + retains the singleton; calling `.start()` registers the
/// WidgetsBindingObserver so lifecycle transitions reach auto-sync.
class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  @override
  void initState() {
    super.initState();
    // Build + start the auto-sync controller. Reading via `ref.read`
    // here is intentional — we never want a rebuild to recreate this
    // singleton; the orchestrator changing under it (data mode switch)
    // is handled by `ref.onDispose` in the provider.
    ref.read(syncControllerProvider).start();
  }

  @override
  void dispose() {
    // Symmetry with initState. `Provider.onDispose` would also fire on
    // ProviderScope teardown, but doing it here too keeps the lifecycle
    // pairing explicit.
    ref.read(syncControllerProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      theme: AppTheme.lightThemeData,
      darkTheme: AppTheme.darkThemeData,
      themeMode: ThemeMode.system,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(AppRouter.config),
    );
  }
}
