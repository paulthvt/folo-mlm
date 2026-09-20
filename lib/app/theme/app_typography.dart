import 'package:flutter/material.dart';

/// Typography ramp.
///
/// PLACEHOLDER — currently the Material 3 ramp with no custom font. When the
/// design system lands, set [fontFamily] and override only the styles that
/// differ; everything else keeps inheriting.
abstract final class AppTypography {
  static const String? fontFamily = null;

  static TextTheme textTheme(ColorScheme scheme) {
    final base = Typography.material2021(colorScheme: scheme);
    final ramp = scheme.brightness == Brightness.dark ? base.white : base.black;
    return fontFamily == null ? ramp : ramp.apply(fontFamily: fontFamily);
  }
}
