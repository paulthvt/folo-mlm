import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/core/ui/folo_avatar.dart';
import 'package:material_ui/material_ui.dart';

/// A person in a list: avatar, name, one line of context, a trailing chip.
class ContactRow extends StatelessWidget {
  const ContactRow({
    required this.name,
    this.subtitle,
    this.trailing,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String name;
  final String? subtitle;
  final Widget? trailing;

  /// The person open beside the list, on desktop.
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = subtitle;
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer,
      selectedColor: scheme.onPrimaryContainer,
      hoverColor: FoloColors.of(context).surfaceSunken,
      leading: FoloAvatar(name: name, size: AvatarSize.row),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: text == null
          ? null
          : Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
