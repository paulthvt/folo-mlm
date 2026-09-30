import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/core/ui/folo_top_bar.dart';
import 'package:material_ui/material_ui.dart';

/// A Settings screen: its top bar, then [child], centred and scrolling.
class SettingsScroll extends StatelessWidget {
  const SettingsScroll({
    required this.title,
    required this.child,
    this.eyebrow,
    super.key,
  });

  final String title;

  /// Above [title], e.g. a workflow's stage.
  final String? eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final desktop = context.screenSize.isDesktop;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: EdgeInsets.all(desktop ? AppSpacing.xl : AppSpacing.md),
          children: [
            FoloTopBar(title: title, eyebrow: eyebrow, large: desktop),
            child,
          ],
        ),
      ),
    );
  }
}
