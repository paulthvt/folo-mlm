import 'package:material_ui/material_ui.dart';

/// Colour tokens, mirroring the Figma collection `Folo/color`
/// (see `docs/design/design-system.md` §1). Figma is the source of truth; this
/// file is its Dart projection, so token names match one-to-one.
///
/// Two homes for a token:
/// * `ColorScheme` when Material already has a slot with the same meaning,
/// * [FoloColors] when it does not (sunken surfaces, borders, muted ink,
///   accent, progress track, focus ring, semantic states).
///
/// Widgets read `Theme.of(context).colorScheme` and `FoloColors.of(context)`.
/// Never a literal colour.
abstract final class AppColors {
  static const light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF235C46), // primary/base — identical in both modes
    onPrimary: Color(0xFFFFFFFF), // text/on-primary
    primaryContainer: Color(0xFFDAE8DF),
    onPrimaryContainer: Color(0xFF143C2C),
    secondary: Color(0xFF6F9339),
    onSecondary: Color(0xFF14200A), // text/on-secondary
    secondaryContainer: Color(0xFFE9EFD6),
    onSecondaryContainer: Color(0xFF41590F),
    error: Color(0xFFA83B2A),
    onError: Color(0xFFFFFFFF), // semantic/on-error
    errorContainer: Color(0xFFFADEDA),
    onErrorContainer: Color(0xFF5E1A11),
    surface: Color(0xFFFBFBF8), // surface/canvas
    onSurface: Color(0xFF16201A), // text/primary
    onSurfaceVariant: Color(0xFF4C5751), // text/secondary
    surfaceContainerLowest: Color(0xFFFFFFFF), // surface/default
    surfaceContainerLow: Color(0xFFFFFFFF), // surface/raised
    surfaceContainer: Color(0xFFF4F4EE), // surface/sunken
    surfaceContainerHigh: Color(0xFFF4F4EE),
    surfaceContainerHighest: Color(0xFFF2F2EC), // surface/disabled
    outline: Color(0xFFC9CFC0), // border/strong
    outlineVariant: Color(0xFFE6E8E1), // border/subtle
    shadow: Color(0xFF16201A),
    scrim: Color(0xFF16201A),
    inverseSurface: Color(0xFF16201A),
    onInverseSurface: Color(0xFFFBFBF8),
  );

  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF235C46),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF16291F),
    onPrimaryContainer: Color(0xFF8BD1AE),
    secondary: Color(0xFFA8C765),
    onSecondary: Color(0xFF14200A),
    secondaryContainer: Color(0xFF232C12),
    onSecondaryContainer: Color(0xFFC2DA8C),
    error: Color(0xFFF08E7C),
    onError: Color(0xFF241110),
    errorContainer: Color(0xFF33201C),
    onErrorContainer: Color(0xFFFFDAD3),
    surface: Color(0xFF0C1210),
    onSurface: Color(0xFFECF1ED),
    onSurfaceVariant: Color(0xFFB7C2BA),
    surfaceContainerLowest: Color(0xFF111814), // surface/sunken
    surfaceContainerLow: Color(0xFF151E19), // surface/default
    surfaceContainer: Color(0xFF151E19),
    surfaceContainerHigh: Color(0xFF1C2620), // surface/raised
    surfaceContainerHighest: Color(0xFF1C2620),
    outline: Color(0xFF3A4840),
    outlineVariant: Color(0xFF26312B),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFECF1ED),
    onInverseSurface: Color(0xFF16201A),
  );
}

/// The colour tokens `ColorScheme` has no slot for.
///
/// `FoloColors.of(context)` is the only way widgets should reach them.
@immutable
class FoloColors extends ThemeExtension<FoloColors> {
  const FoloColors({
    required this.surfaceDefault,
    required this.surfaceSunken,
    required this.surfaceRaised,
    required this.surfaceDisabled,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textMuted,
    required this.textDisabled,
    required this.primaryHover,
    required this.primaryText,
    required this.primaryMuted,
    required this.secondaryText,
    required this.secondaryTrack,
    required this.accent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.focus,
  });

  /// Cards, rows, bars.
  final Color surfaceDefault;

  /// Search field, sidebar, wells.
  final Color surfaceSunken;

  /// Menus, sheets, dialogs. In dark this steps *up* instead of adding shadow.
  final Color surfaceRaised;
  final Color surfaceDisabled;

  /// The default 1px hairline.
  final Color borderSubtle;

  /// Unchecked controls, dividers that must be seen.
  final Color borderStrong;

  /// Metadata, overlines, captions.
  final Color textMuted;
  final Color textDisabled;

  /// Pointer hover on a primary fill; also the hero's own progress track.
  final Color primaryHover;

  /// Primary used as *ink*. Flips between modes — `colorScheme.primary` does
  /// not, and fails contrast on a dark surface.
  final Color primaryText;

  /// Hover wash, selected row.
  final Color primaryMuted;

  /// "On pace", pace labels.
  final Color secondaryText;

  /// Track under a `secondary` progress bar.
  final Color secondaryTrack;

  /// Date-anchored marks only — a birthday, a promised call-back. Never
  /// judgement (see design principle #4).
  final Color accent;
  final Color accentContainer;
  final Color onAccentContainer;

  final Color success;
  final Color successContainer;

  /// System states only (sync, permission) — deliberately a deeper bronze than
  /// [accent] so the two cannot be confused.
  final Color warning;
  final Color warningContainer;

  final Color info;
  final Color infoContainer;

  /// 2px focus-visible ring.
  final Color focus;

  static const light = FoloColors(
    surfaceDefault: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF4F4EE),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceDisabled: Color(0xFFF2F2EC),
    borderSubtle: Color(0xFFE6E8E1),
    borderStrong: Color(0xFFC9CFC0),
    textMuted: Color(0xFF64706A),
    textDisabled: Color(0xFFA2A99F),
    primaryHover: Color(0xFF1B4A38),
    primaryText: Color(0xFF1F5540),
    primaryMuted: Color(0xFFEDF3EF),
    secondaryText: Color(0xFF4F6B1F),
    secondaryTrack: Color(0xFFD7E2B6),
    accent: Color(0xFFB08B2A),
    accentContainer: Color(0xFFF6EBCD),
    onAccentContainer: Color(0xFF6E5410),
    success: Color(0xFF2E7D5B),
    successContainer: Color(0xFFDCEFE4),
    warning: Color(0xFF8A5A16),
    warningContainer: Color(0xFFF7E2C8),
    info: Color(0xFF2C6B7A),
    infoContainer: Color(0xFFDDEDF1),
    focus: Color(0xFF235C46),
  );

  static const dark = FoloColors(
    surfaceDefault: Color(0xFF151E19),
    surfaceSunken: Color(0xFF111814),
    surfaceRaised: Color(0xFF1C2620),
    surfaceDisabled: Color(0xFF1A211C),
    borderSubtle: Color(0xFF26312B),
    borderStrong: Color(0xFF3A4840),
    textMuted: Color(0xFF97A59D),
    textDisabled: Color(0xFF5C6861),
    primaryHover: Color(0xFF2C6E55),
    primaryText: Color(0xFF66BE94),
    primaryMuted: Color(0xFF101A15),
    secondaryText: Color(0xFFA8C765),
    secondaryTrack: Color(0xFF38471C),
    accent: Color(0xFFD9B75E),
    accentContainer: Color(0xFF2E2612),
    onAccentContainer: Color(0xFFE6CE8E),
    success: Color(0xFF5FC196),
    successContainer: Color(0xFF13291F),
    warning: Color(0xFFE2A85C),
    warningContainer: Color(0xFF2F2513),
    info: Color(0xFF74BDCB),
    infoContainer: Color(0xFF14282E),
    focus: Color(0xFF66BE94),
  );

  /// Throws if the extension is missing, which only happens outside
  /// [AppTheme] — a bug, not a case to fall back from.
  static FoloColors of(BuildContext context) =>
      Theme.of(context).extension<FoloColors>()!;

  /// No field-by-field override exists because nothing needs one: the two
  /// instances above are the whole palette.
  @override
  FoloColors copyWith() => this;

  @override
  FoloColors lerp(FoloColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return FoloColors(
      surfaceDefault: c(surfaceDefault, other.surfaceDefault),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceDisabled: c(surfaceDisabled, other.surfaceDisabled),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      borderStrong: c(borderStrong, other.borderStrong),
      textMuted: c(textMuted, other.textMuted),
      textDisabled: c(textDisabled, other.textDisabled),
      primaryHover: c(primaryHover, other.primaryHover),
      primaryText: c(primaryText, other.primaryText),
      primaryMuted: c(primaryMuted, other.primaryMuted),
      secondaryText: c(secondaryText, other.secondaryText),
      secondaryTrack: c(secondaryTrack, other.secondaryTrack),
      accent: c(accent, other.accent),
      accentContainer: c(accentContainer, other.accentContainer),
      onAccentContainer: c(onAccentContainer, other.onAccentContainer),
      success: c(success, other.success),
      successContainer: c(successContainer, other.successContainer),
      warning: c(warning, other.warning),
      warningContainer: c(warningContainer, other.warningContainer),
      info: c(info, other.info),
      infoContainer: c(infoContainer, other.infoContainer),
      focus: c(focus, other.focus),
    );
  }
}
