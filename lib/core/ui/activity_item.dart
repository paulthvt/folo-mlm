import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// One thing that happened (`docs/design/components.md` #14). Reads as memory,
/// not as an audit log: no edit metadata, no author.
class ActivityItem extends StatelessWidget {
  const ActivityItem({
    required this.title,
    required this.meta,
    this.showRailLine = true,
    super.key,
  });

  final String title;

  /// Date · kind, e.g. "2 days ago · Call".
  final String meta;

  /// Off on the last item in a list.
  final bool showRailLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folo = FoloColors.of(context);

    // IntrinsicHeight so the rail can fill the height of the text beside it
    // without either side knowing the other's size.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AppSpacing.md,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.xs),
                  width: AppSpacing.sm,
                  height: AppSpacing.sm,
                  decoration: BoxDecoration(
                    color: folo.borderStrong,
                    shape: BoxShape.circle,
                  ),
                ),
                if (showRailLine)
                  Expanded(
                    child: Container(width: 2, color: folo.borderSubtle),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.ms),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: showRailLine ? AppSpacing.md : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    meta,
                    style: AppTypography.caption.copyWith(
                      color: folo.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
