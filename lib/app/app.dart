import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/app_router.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/l10n/app_localizations.dart';

/// Application root: wires router + theme. Keep this widget free of any
/// feature logic.
class FoloApp extends ConsumerWidget {
  const FoloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      // A product name is not translated, so there is no appTitle key.
      title: 'Folo',
      debugShowCheckedModeBanner: false,
      // Generated from the ARB files present, so a new locale needs no edit here.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
    );
  }
}
