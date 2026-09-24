import 'package:flutter/material.dart';
import 'package:folo/app/theme/app_theme.dart';

/// The single primary action on an auth screen.
///
/// While [busy] the button is disabled, which is what stops a second tap from
/// firing a second request, and the label swaps for a spinner inside a box the
/// size of the label's line so the button does not resize.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: AnimatedSwitcher(
        duration: context.motion(AppMotion.quick),
        switchInCurve: AppMotion.decelerate,
        switchOutCurve: AppMotion.accelerate,
        child: busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}
