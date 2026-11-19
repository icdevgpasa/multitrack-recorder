import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// English by default; Polish when the phone's language is Polish.
Locale resolveAppLocale(List<Locale>? deviceLocales) {
  final primary = deviceLocales == null || deviceLocales.isEmpty
      ? null
      : deviceLocales.first;
  return primary?.languageCode == 'pl'
      ? const Locale('pl')
      : const Locale('en');
}
