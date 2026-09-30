import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// One thing known about a person: a label over its value. The value wraps and
/// the row grows with it.
class FactRow extends StatelessWidget {
  const FactRow({
    required this.label,
    required this.value,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;

  /// Opens the value elsewhere — an email address in the mail app.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(color: colors.textMuted),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: onTap == null ? null : colors.primaryText,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: content,
    );
  }
}
