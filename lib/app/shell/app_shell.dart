import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/core/ui/folo_avatar.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// Chrome around every signed-in screen (`docs/design/components.md` #23).
///
/// Desktop: the 248px sidebar. Tablet: the same sidebar collapsed to a 72px
/// icon rail. Mobile: nothing — there is no bottom bar until a second real
/// destination exists, and Settings is reached from [AccountButton] in the
/// screen's top bar instead.
///
/// ponytail: the design moves these edges to 840px (rail/bottom bar) and 1100px
/// (rail/sidebar); size classes are used until the bottom bar exists and the
/// difference is visible.
class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  /// The current path, to mark the active destination.
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = context.screenSize;
    if (!size.usesSideNavigation) return child;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Sidebar(location: location, expanded: size.isDesktop),
        // A route's modal barrier blocks the semantics of everything painted
        // before it; without this boundary screen readers never see the sidebar.
        Expanded(child: Semantics(container: true, child: child)),
      ],
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.location, required this.expanded});

  static const double _expandedWidth = 248;
  static const double _railWidth = 72;

  final String location;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folo = FoloColors.of(context);
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(accountProvider);

    return Material(
      color: folo.surfaceSunken,
      child: Container(
        width: expanded ? _expandedWidth : _railWidth,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: folo.borderSubtle)),
        ),
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.ms),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.xs,
              children: [
                if (expanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.ms,
                      AppSpacing.sm,
                      AppSpacing.ms,
                      AppSpacing.lg,
                    ),
                    // Set type until there is a real logo, as on /welcome.
                    child: Text(
                      'Folo',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                _SidebarItem(
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: l10n.navToday,
                  selected: location == Routes.today,
                  expanded: expanded,
                  onTap: () => context.go(Routes.today),
                ),
                const Spacer(),
                if (account != null)
                  _SidebarItem(
                    icon: FoloAvatar(
                      name: account.displayName,
                      size: AvatarSize.dense,
                    ),
                    label: account.displayName,
                    semanticLabel: l10n.settingsTitle,
                    selected: location.startsWith(Routes.settings),
                    expanded: expanded,
                    onTap: () => context.go(Routes.settings),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 44px (a pointer is precise), radius 12, active = `primary/container`, hover
/// = `primary/muted` (#22). Collapsed, the label becomes the semantic label —
/// an icon never carries meaning alone.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
    this.semanticLabel,
  });

  final Widget icon;
  final String label;

  /// When what the item does differs from what it shows (the account block
  /// shows a name and opens Settings).
  final String? semanticLabel;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final folo = FoloColors.of(context);
    // Labels the content, not the tile: the tile keeps its own tap action and
    // selected state for screen readers.
    final content = Semantics(
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: expanded
          ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
          : Center(child: icon),
    );
    return ListTile(
      minTileHeight: 44,
      contentPadding: expanded
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.ms)
          : EdgeInsets.zero,
      horizontalTitleGap: AppSpacing.ms,
      selected: selected,
      selectedTileColor: scheme.primaryContainer,
      selectedColor: scheme.onPrimaryContainer,
      hoverColor: folo.primaryMuted,
      leading: expanded ? ExcludeSemantics(child: icon) : null,
      title: content,
      titleTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
      ),
      onTap: onTap,
    );
  }
}

/// Opens Settings from a screen's top bar, where there is no sidebar (mobile).
/// Pushed, not gone to, so back returns to the screen it was opened from.
class AccountButton extends ConsumerWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    if (account == null) return const SizedBox.shrink();
    return IconButton(
      onPressed: () => context.push(Routes.settings),
      icon: Semantics(
        label: AppLocalizations.of(context).settingsTitle,
        excludeSemantics: true,
        child: FoloAvatar(name: account.displayName, size: AvatarSize.dense),
      ),
    );
  }
}
