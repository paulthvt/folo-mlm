import 'package:loomia/app/theme/app_spacing.dart';
import 'package:material_ui/material_ui.dart';

/// A form field under its label, as in Figma: the label sits above the box
/// and never floats, since a moving label costs legibility. Screen readers
/// hear it as the field's name.
class LabeledField extends StatelessWidget {
  const LabeledField({required this.label, required this.child, super.key});

  final String label;

  /// The field, its decoration without a `labelText`.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Text(label, style: Theme.of(context).inputDecorationTheme.labelStyle),
          child,
        ],
      ),
    );
  }
}
