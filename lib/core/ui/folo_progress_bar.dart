import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Pace, not score (`docs/design/components.md` #7).
enum ProgressTone {
  /// Olive on its own track. The default everywhere.
  secondary,

  /// Only inside the Today hero, where the surface is `primary/base`.
  primary,
}

/// A pill track with an optional caption row. The right caption says how much
/// time is left — never a verdict (design principle #5).
class FoloProgressBar extends StatelessWidget {
  const FoloProgressBar({
    required this.value,
    this.tone = ProgressTone.secondary,
    this.leadingLabel,
    this.trailingLabel,
    super.key,
  });

  final double value;
  final ProgressTone tone;
  final String? leadingLabel;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final folo = FoloColors.of(context);
    final onPrimary = tone == ProgressTone.primary;
    final track = onPrimary ? folo.primaryHover : folo.secondaryTrack;
    // Inside the hero the captions sit on `primary/base`, so they take the
    // on-primary ink the hero uses rather than a surface ink.
    final captionInk = onPrimary
        ? scheme.onPrimary.withValues(alpha: 0.78)
        : folo.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          // The bar grows into its new value instead of jumping: the movement is
          // the only thing that says progress was made (§7, 240ms).
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value.clamp(0, 1)),
            duration: context.motion(AppMotion.medium),
            curve: AppMotion.standard,
            builder: (context, animated, child) => LinearProgressIndicator(
              value: animated,
              backgroundColor: track,
              color: onPrimary ? scheme.secondary : null,
            ),
          ),
        ),
        if (leadingLabel != null || trailingLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    leadingLabel ?? '',
                    style: AppTypography.caption.copyWith(color: captionInk),
                  ),
                ),
                Text(
                  trailingLabel ?? '',
                  style: AppTypography.caption.copyWith(color: captionInk),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
