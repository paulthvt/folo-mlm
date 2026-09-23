import 'package:flutter/material.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_typography.dart';

/// The only structural divider in the product (`docs/design/components.md` #10):
/// no rules, no card headers, no chevrons — space and this header do all the
/// grouping (design principle #6).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;

  /// Null with an [actionLabel] set renders the label as a plain count.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final folo = FoloColors.of(context);
    final label = actionLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.ms),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppTypography.overline.copyWith(color: folo.textMuted),
            ),
          ),
          if (label != null)
            if (onAction == null)
              Text(
                label,
                style: AppTypography.caption.copyWith(color: folo.textMuted),
              )
            else
              TextButton(
                onPressed: onAction,
                child: Text(label, style: AppTypography.label),
              ),
        ],
      ),
    );
  }
}
