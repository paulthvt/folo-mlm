import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:material_ui/material_ui.dart';

/// ConfirmDialog (`docs/design/components.md` #19), and any short form: a
/// bottom sheet on mobile, a centred dialog elsewhere, the same internals.
class FoloDialog extends StatelessWidget {
  const FoloDialog({
    required this.title,
    required this.actions,
    this.body,
    this.child,
    super.key,
  });

  static const double _maxWidth = 480;

  final String title;
  final String? body;

  /// A form field, under the body.
  final Widget? child;

  /// The safe action first, then the primary one: side by side they read
  /// left to right; stacked in a sheet the primary one goes on top.
  final List<Widget> actions;

  static Future<T?> show<T>(BuildContext context, WidgetBuilder builder) =>
      context.screenSize.isMobile
      ? showModalBottomSheet<T>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: builder,
        )
      : showDialog<T>(
          context: context,
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: builder(context),
            ),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = context.screenSize.isMobile;
    final bodyText = body;

    return Padding(
      // Keeps a sheet's field above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      // `useSafeArea` only clears the top; this clears the system navigation
      // bar under a sheet.
      child: SafeArea(
        top: false,
        child: Padding(
          padding: mobile
              ? const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                )
              : const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.ms,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (bodyText != null)
                Text(
                  bodyText,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ?child,
              const SizedBox(height: AppSpacing.xs),
              if (mobile)
                ...actions.reversed
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: AppSpacing.sm,
                  children: actions,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
