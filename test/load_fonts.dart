import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads the app's real font files. Tests render every family as Ahem boxes
/// otherwise; call from `setUpAll` wherever pixels matter.
Future<void> loadAppFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json'));
  for (final family in manifest as List) {
    final loader = FontLoader(family['family'] as String);
    for (final font in family['fonts'] as List) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}
