import 'package:flutter/material.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_typography.dart';
import 'package:folo/core/ui/folo_progress_bar.dart';

/// Own intent vs. own progress (`docs/design/components.md` #17). Pace is never
/// red and never a comparison with another person (design principle #5).
class GoalCard extends StatelessWidget {
  const GoalCard({
    required this.title,
    required this.value,
    required this.target,
    required this.pace,
    this.behindPace = false,
    this.timeLeft,
    super.key,
  });

  final String title;

  /// Where the user is.
  final int value;

  /// What they aimed for. The bar is [value] / [target].
  final int target;

  /// "Slightly behind pace" / "On pace" — direction, never a verdict.
  final String pace;

  /// Behind pace takes the warm secondary ink; on pace stays muted.
  final bool behindPace;

  /// "11 days left" — how much time is left, never a percentage.
  final String? timeLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folo = FoloColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                Text(
                  pace,
                  style: AppTypography.caption.copyWith(
                    color: behindPace ? folo.secondaryText : folo.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$value',
                  style: AppTypography.numeric.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'of $target',
                  style: AppTypography.body.copyWith(color: folo.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.ms),
            FoloProgressBar(
              value: target == 0 ? 0 : value / target,
              trailingLabel: timeLeft,
            ),
          ],
        ),
      ),
    );
  }
}
