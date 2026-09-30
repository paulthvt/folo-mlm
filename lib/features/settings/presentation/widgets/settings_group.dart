import 'package:loomia/app/theme/app_colors.dart';
import 'package:material_ui/material_ui.dart';

/// One group of Settings rows (`SettingsRow` in Figma): a flat hairline card,
/// a hairline between rows, square row highlights so they meet its edges.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  /// `ListTile`s.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTileTheme.merge(
        shape: const RoundedRectangleBorder(),
        titleTextStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        leadingAndTrailingTextStyle: theme.textTheme.bodyMedium?.copyWith(
          color: LoomiaColors.of(context).textMuted,
        ),
        subtitleTextStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        selectedTileColor: LoomiaColors.of(context).primaryMuted,
        selectedColor: theme.colorScheme.onSurface,
        child: Column(
          children: ListTile.divideTiles(
            context: context,
            tiles: children,
          ).toList(),
        ),
      ),
    );
  }
}
