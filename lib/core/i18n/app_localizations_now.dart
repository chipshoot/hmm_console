import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../l10n/gen/app_localizations.dart';
import 'locale_provider.dart';

/// [AppLocalizations] for the app's language right now (the chosen locale,
/// else the platform's, else English), built without a BuildContext.
final appLocalizationsNowProvider = Provider<AppLocalizations>((ref) {
  final chosen = ref.watch(localeProvider);
  final platform = PlatformDispatcher.instance.locale;
  final locale = AppLocalizations.supportedLocales.firstWhere(
    (s) => s.languageCode == (chosen ?? platform).languageCode,
    orElse: () => const Locale('en'),
  );
  final l = lookupAppLocalizations(locale);
  // Normally loaded by the Material localizations; make sure (the data is
  // bundled, so this completes synchronously).
  unawaited(initializeDateFormatting(l.localeName));
  return l;
});
