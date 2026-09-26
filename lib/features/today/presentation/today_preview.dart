import 'package:flutter/widget_previews.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/today/domain/today_snapshot.dart';
import 'package:folo/features/today/presentation/today_page.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:folo/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Today in both modes and both layouts, for `flutter widget-preview start`.
///
/// The sample book of contacts lives here and only here: the app itself has no
/// repository yet, so it renders the empty state (see [todaySnapshotProvider]).
/// Nothing in the app imports this file.
@Preview(group: 'Today', name: 'Mobile — light', size: Size(390, 844))
Widget todayMobileLight() => _app(AppTheme.light, sampleToday);

@Preview(group: 'Today', name: 'Mobile — dark', size: Size(390, 844))
Widget todayMobileDark() => _app(AppTheme.dark, sampleToday);

@Preview(group: 'Today', name: 'Desktop — light', size: Size(1440, 900))
Widget todayDesktopLight() => _app(AppTheme.light, sampleToday);

@Preview(group: 'Today', name: 'Desktop — dark', size: Size(1440, 900))
Widget todayDesktopDark() => _app(AppTheme.dark, sampleToday);

@Preview(group: 'Today', name: 'Empty — light', size: Size(390, 844))
Widget todayEmptyLight() => _app(AppTheme.light, null);

Widget _app(ThemeData theme, TodaySnapshot? snapshot) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // The preview is its own app: without the delegates, any component that
    // reads AppLocalizations throws here.
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: TodayView(snapshot: snapshot),
  );
}
