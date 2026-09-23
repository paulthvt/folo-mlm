import 'package:flutter/material.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_typography.dart';

/// Screen header (`docs/design/components.md` #24): the eyebrow carries the date,
/// the title carries the place. No shadow and no border — the canvas colour is
/// the whole chrome.
///
/// A plain widget rather than an `AppBar` because it scrolls with the content and
/// its title is two lines of different styles.
class FoloTopBar extends StatelessWidget {
  const FoloTopBar({
    required this.title,
    this.eyebrow,
    this.large = false,
    this.action,
    super.key,
  });

  final String title;

  /// Uppercased by the style — pass it in sentence case.
  final String? eyebrow;

  /// Desktop uses the 32px `display` style, mobile the 24px `headline`.
  final bool large;

  /// One trailing ghost action, at most.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folo = FoloColors.of(context);
    final eyebrowText = eyebrow;
    final trailing = action;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrowText != null) ...[
                  Text(
                    eyebrowText.toUpperCase(),
                    style: AppTypography.overline.copyWith(
                      color: folo.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(
                  title,
                  style: large
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.headlineSmall,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
