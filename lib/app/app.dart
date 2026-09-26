import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/app_router.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/account.dart';
import 'package:folo/l10n/app_localizations.dart';

/// Application root: wires router + theme. Keep this widget free of any
/// feature logic.
class FoloApp extends ConsumerWidget {
  const FoloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(accountProvider.select((a) => a?.locale));
    final appearance = ref.watch(
      accountProvider.select((a) => a?.appearance ?? Appearance.system),
    );
    return MaterialApp.router(
      // A product name is not translated, so there is no appTitle key.
      title: 'Folo',
      debugShowCheckedModeBanner: false,
      // Generated from the ARB files present, so a new locale needs no edit here.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The user's choice from Settings; null follows the system.
      locale: locale == null ? null : Locale(locale),
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (appearance) {
        Appearance.system => ThemeMode.system,
        Appearance.light => ThemeMode.light,
        Appearance.dark => ThemeMode.dark,
      },
    );
  }
}
