import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Answers "what should I do today?" from arm's length
/// (`docs/design/components.md` #11).
///
/// The only filled colour block in the product. Its colour is identical in light
/// and dark, which is why the labels on it can be white at 78% in both modes.
class TodayHero extends StatelessWidget {
  const TodayHero({
    required this.eyebrow,
    required this.headline,
    this.compact = true,
    super.key,
  });

  final String eyebrow;

  /// A sentence. The count lives inside it so it cannot read as a quota.
  final String headline;

  /// Mobile keeps `title-lg`; desktop steps the headline up to `headline`.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quiet = scheme.onPrimary.withValues(alpha: 0.78);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: AppTypography.overline.copyWith(color: quiet),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            headline,
            style: (compact ? AppTypography.titleLarge : AppTypography.headline)
                .copyWith(color: scheme.onPrimary),
          ),
        ],
      ),
    );
  }
}
