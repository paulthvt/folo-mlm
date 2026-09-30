import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Form-level failure: "we could not sign you in", as opposed to a field being
/// wrong (that is the text field's own error state).
///
/// This is one of only two places red appears outside a destructive action.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The message appears in response to a tap, so it grows and fades in rather
    // than snapping into the column (§7, 180ms). Callers mount and unmount it,
    // which is why the entrance is the only animated direction.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.motion(AppMotion.quick),
      curve: AppMotion.decelerate,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Align(heightFactor: t, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.ms),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Icon(Icons.error_outline_rounded, size: 20, color: scheme.error),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
