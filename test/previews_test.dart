import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/theme_preview.dart';
import 'package:folo/core/ui/ui_preview.dart';
import 'package:folo/features/today/presentation/today_preview.dart';
import 'package:material_ui/material_ui.dart';

/// Every `@Preview`, rendered at its preview size and compared against a
/// committed PNG in `goldens/`.
///
/// The previews are their own apps — `flutter widget-preview start` builds each
/// function directly — so a missing localization delegate or a layout assertion
/// only shows up here: no shipped screen goes through these builders.
///
/// Pixels are compared on Linux only. Antialiasing differs per OS, and the
/// committed PNGs come from CI (see the `update-goldens` input in ci.yaml).
/// Elsewhere the previews still have to render without an exception.
void main() {
  final previews = <String, (Size, Widget Function())>{
    'today_mobile_light': (const Size(390, 844), todayMobileLight),
    'today_mobile_dark': (const Size(390, 844), todayMobileDark),
    'today_desktop_light': (const Size(1440, 900), todayDesktopLight),
    'today_desktop_dark': (const Size(1440, 900), todayDesktopDark),
    'today_empty_light': (const Size(390, 844), todayEmptyLight),
    'components_light': (const Size(420, 1800), uiComponentsLight),
    'components_dark': (const Size(420, 1800), uiComponentsDark),
    'tokens_colour_light': (const Size(420, 900), colourTokensLight),
    'tokens_colour_dark': (const Size(420, 900), colourTokensDark),
    'tokens_type_light': (const Size(420, 900), typeRampLight),
    'tokens_type_dark': (const Size(420, 900), typeRampDark),
    'tokens_spacing': (const Size(420, 700), spacingTokens),
    'tokens_components_light': (const Size(420, 760), componentsLight),
    'tokens_components_dark': (const Size(420, 760), componentsDark),
  };

  // Tests render every family as Ahem boxes unless the real files are loaded.
  setUpAll(() async {
    final manifest = jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    );
    for (final family in manifest as List) {
      final loader = FontLoader(family['family'] as String);
      for (final font in family['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  for (final MapEntry(key: name, value: (size, preview)) in previews.entries) {
    testWidgets(name, (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(preview());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      if (Platform.isLinux) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      }
    });
  }
}
