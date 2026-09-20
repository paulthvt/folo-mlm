import 'package:flutter/material.dart';

/// Single source of truth for colour.
///
/// PLACEHOLDER VALUES — the visual identity is defined in a later step.
/// Replace the two schemes below and the whole app follows; never hard-code a
/// colour in a widget, read `Theme.of(context).colorScheme` instead.
abstract final class AppColors {
  static const _seed = Color(0xFF2F6F62);

  static final ColorScheme light = ColorScheme.fromSeed(seedColor: _seed);

  static final ColorScheme dark = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.dark,
  );
}
