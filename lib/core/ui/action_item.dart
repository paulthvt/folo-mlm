import 'package:flutter/material.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/folo_avatar.dart';
import 'package:folo/core/ui/folo_chip.dart';

/// The unit of Today — a suggestion, not a task (`docs/design/components.md` #12).
///
/// [reason] is required on purpose: it is what makes the item an offer instead of
/// a demand (design principle #4).
class ActionItem extends StatelessWidget {
  const ActionItem({
    required this.name,
    required this.reason,
    this.chip,
    this.onOpen,
    this.onResolve,
    this.resolveLabel = 'Mark as done',
    super.key,
  });

  final String name;
  final String reason;

  /// Usually an accent chip, and only when a real date drives the item.
  final Widget? chip;

  /// Opening the row opens the person.
  final VoidCallback? onOpen;

  /// Resolves in one tap; the caller collapses the row over
  /// `AppMotion.medium`.
  final VoidCallback? onResolve;
  final String resolveLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folo = FoloColors.of(context);
    final chipWidget = chip;

    return Material(
      color: folo.surfaceDefault,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: folo.borderSubtle),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoloAvatar(name: name),
              const SizedBox(width: AppSpacing.ms),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(reason, style: theme.textTheme.bodySmall),
                    if (chipWidget != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      chipWidget,
                    ],
                  ],
                ),
              ),
              if (onResolve != null) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: onResolve,
                  tooltip: resolveLabel,
                  icon: const Icon(Icons.check_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The accent chip an [ActionItem] uses when a real date drives it — kept here
/// so the "accent means a date" rule lives next to its only caller.
class DateChip extends StatelessWidget {
  const DateChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) =>
      FoloChip(label: label, tone: ChipTone.accent, icon: Icons.event_rounded);
}
