import 'package:flutter/material.dart';
import 'package:folo/app/theme/app_theme.dart';

/// A password input with a reveal toggle.
///
/// Stateful for one reason: whether the value is currently visible is local
/// widget state.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.label,
    this.helper,
    this.validator,
    this.enabled = true,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? Function(String?)? validator;
  final bool enabled;
  final void Function(String)? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: !_revealed,
      enabled: widget.enabled,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _revealed = !_revealed),
          icon: AnimatedSwitcher(
            duration: context.motion(AppMotion.fast),
            child: Icon(
              _revealed
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              key: ValueKey(_revealed),
            ),
          ),
          tooltip: _revealed ? 'Hide password' : 'Show password',
        ),
      ),
    );
  }
}
