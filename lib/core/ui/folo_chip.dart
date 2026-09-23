import 'package:flutter/material.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_typography.dart';

/// What a chip is allowed to say (`docs/design/components.md` #6). There is no
/// red chip: a chip states a fact, never a judgement.
enum ChipTone {
  /// Taxonomy — Customer, Team.
  neutral,

  /// Relationship state.
  primary,

  /// Pace.
  secondary,

  /// Anchored to a real date only — a birthday, a promised call-back.
  accent,
}

/// A fact about a person.
class FoloChip extends StatelessWidget {
  const FoloChip({
    required this.label,
    this.tone = ChipTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final folo = FoloColors.of(context);
    final (background, ink) = switch (tone) {
      ChipTone.neutral => (folo.surfaceSunken, folo.textMuted),
      ChipTone.primary => (scheme.primaryContainer, scheme.onPrimaryContainer),
      ChipTone.secondary => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      ChipTone.accent => (folo.accentContainer, folo.onAccentContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: AppTypography.caption.copyWith(color: ink)),
        ],
      ),
    );
  }
}
