import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hmm_console/core/data/local/database.dart';
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

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
