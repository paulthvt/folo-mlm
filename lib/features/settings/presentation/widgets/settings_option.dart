import 'package:material_ui/material_ui.dart';

/// One choice in a list of them: its label, a check when chosen.
class SettingsOption extends StatelessWidget {
  const SettingsOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.translation = '',
    super.key,
  });

  final String label;

  /// Hidden when empty or the same as [label].
  final String translation;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final showTranslation = translation.isNotEmpty && translation != label;
    return Semantics(
      selected: selected,
      child: ListTile(
        title: Text(label),
        subtitle: showTranslation ? Text(translation) : null,
        trailing: selected ? const Icon(Icons.check_rounded) : null,
        onTap: onTap,
      ),
    );
  }
}
