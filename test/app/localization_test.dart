import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/l10n/app_localizations.dart';

Widget _host(Locale? locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Text(AppLocalizations.of(context).todayTitle),
  ),
);

void main() {
  testWidgets('English is supported', (tester) async {
    await tester.pumpWidget(_host(const Locale('en')));
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('French renders French', (tester) async {
    await tester.pumpWidget(_host(const Locale('fr')));
    expect(find.text('Aujourd’hui'), findsOneWidget);
  });

  // A phone set to a language nobody has translated must still show the app,
  // not a crash and not an empty string.
  testWidgets('an untranslated locale falls back to English', (tester) async {
    await tester.pumpWidget(_host(const Locale('de')));
    expect(find.text('Today'), findsOneWidget);
  });
}
