import 'package:flutter/material.dart';
import 'package:folo/app/theme/app_spacing.dart';

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
    return Container(
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
    );
  }
}
