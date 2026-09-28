import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_typography.dart';
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
    final folo = FoloColors.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(color: folo.textMuted),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: onTap == null ? null : theme.colorScheme.primary,
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
