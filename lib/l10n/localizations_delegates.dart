import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Use this, not `AppLocalizations.localizationsDelegates`: gen-l10n still
/// registers flutter_localizations' Material strings, a type material_ui
/// widgets never look up, so date pickers and tooltips would stay in English.
const localizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
