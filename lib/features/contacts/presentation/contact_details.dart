import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/core/ui/fact_row.dart';
import 'package:folo/core/ui/folo_avatar.dart';
import 'package:folo/core/ui/folo_chip.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/section_header.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The digits and `+` of a phone number, which is what `tel:` and `sms:` want.
String _dialable(String phone) => phone.replaceAll(RegExp(r'[^\d+]'), '');

/// A text when there is a phone, else Instagram, else nothing.
Uri? messageUri(Person person) {
  final phone = person.phone;
  if (phone != null) return Uri(scheme: 'sms', path: _dialable(phone));
  var handle = person.instagram?.trim();
  if (handle != null) {
    if (handle.startsWith('@')) handle = handle.substring(1);
    return Uri.https('instagram.com', '/$handle');
  }
  return null;
}

Uri? callUri(Person person) {
  final phone = person.phone;
  return phone == null ? null : Uri(scheme: 'tel', path: _dialable(phone));
}

typedef _Action = ({String label, IconData icon, VoidCallback onTap});

/// One person: who they are, how to reach them, where it stands, what you
/// know. A pure view; the page owns saving and navigation.
///
/// `NEXT STEP` is not here yet: it arrives whole with #57.
class ContactDetails extends StatelessWidget {
  const ContactDetails({
    required this.person,
    required this.onStatus,
    required this.onEdit,
    required this.onDelete,
    required this.onLog,
    required this.onMove,
    required this.onLaunch,
    required this.onRefresh,
    this.history,
    super.key,
  });

  final Person person;

  /// The tapped status, or null when the selected one was tapped again.
  final ValueChanged<ProspectStatus?> onStatus;
  final VoidCallback onEdit;

  /// Called once the user has confirmed.
  final VoidCallback onDelete;
  final ValueChanged<Uri> onLaunch;
  final Future<void> Function() onRefresh;
  final VoidCallback onLog;

  /// Called with the stage picked in ⋯; the page confirms and saves.
  final ValueChanged<Stage> onMove;

  /// The `HISTORY` section, below what you know.
  final Widget? history;

  List<_Action> _actions(AppLocalizations l10n) => [
    (
      label: l10n.contactLogSomething,
      icon: Icons.edit_note_rounded,
      onTap: onLog,
    ),
    for (final stage in Stage.values)
      if (stage != person.stage)
        (
          label: moveToLabel(l10n, stage),
          icon: Icons.swap_horiz_rounded,
          onTap: () => onMove(stage),
        ),
    (label: l10n.contactEditDetails, icon: Icons.edit_outlined, onTap: onEdit),
  ];

  /// A sheet on mobile, a menu elsewhere; the same items either way.
  Widget _more(BuildContext context, AppLocalizations l10n) {
    final actions = _actions(l10n);
    final _Action delete = (
      label: l10n.contactDeleteName(firstName(person)),
      icon: Icons.delete_outline_rounded,
      onTap: () => _confirmDelete(context),
    );
    const icon = Icon(Icons.more_horiz_rounded);

    if (context.screenSize.isMobile) {
      return IconButton(
        tooltip: l10n.contactMore,
        icon: icon,
        onPressed: () async {
          final chosen = await showModalBottomSheet<VoidCallback>(
            context: context,
            // Sized to its items, not capped at 9/16 of the screen.
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => _MoreSheet(
              title: person.name,
              actions: actions,
              delete: delete,
            ),
          );
          // Run once the sheet is gone, from this page's context.
          if (!context.mounted) return;
          chosen?.call();
        },
      );
    }
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<VoidCallback>(
      tooltip: l10n.contactMore,
      icon: icon,
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem(value: action.onTap, child: Text(action.label)),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: delete.onTap,
          child: Text(delete.label, style: TextStyle(color: error)),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.contactDeleteTitle(person.name),
      body: l10n.contactDeleteBody,
      action: l10n.contactDeleteConfirm,
    );
    if (confirmed) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final folo = FoloColors.of(context);
    final message = messageUri(person);
    final call = callUri(person);
    final email = person.email;
    final status = person.prospectStatus;
    final facts = [
      (l10n.factNeeds, person.needs, null),
      (l10n.factProducts, person.products, null),
      (l10n.factProfession, person.profession, null),
      (l10n.factPhone, person.phone, null),
      (
        l10n.factEmail,
        email,
        email == null ? null : Uri(scheme: 'mailto', path: email),
      ),
      (l10n.factInstagram, person.instagram, null),
      (l10n.factAddress, person.address, null),
      (l10n.factNotes, person.notes, null),
    ].where((fact) => fact.$2 != null).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(
          context.screenSize.isDesktop ? AppSpacing.xl : AppSpacing.md,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoloAvatar(name: person.name, size: AvatarSize.header),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [
                    Text(person.name, style: theme.textTheme.headlineSmall),
                    Text(
                      l10n.contactSince(
                        stageLabel(l10n, person.stage),
                        person.stageSince.toLocal(),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: folo.textMuted,
                      ),
                    ),
                    FoloChip(label: stageLabel(l10n, person.stage)),
                  ],
                ),
              ),
              _more(context, l10n),
            ],
          ),
          if (message != null || call != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              spacing: AppSpacing.sm,
              children: [
                if (message != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => onLaunch(message),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text(l10n.contactMessage),
                    ),
                  ),
                if (call != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onLaunch(call),
                      icon: const Icon(Icons.call_outlined),
                      label: Text(l10n.contactCall),
                    ),
                  ),
              ],
            ),
          ],
          if (person.stage == Stage.prospect) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(title: l10n.contactSectionWhereItStands),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final option in ProspectStatus.values)
                  ChoiceChip(
                    label: Text(statusLabel(l10n, option)),
                    selected: option == status,
                    onSelected: (_) =>
                        onStatus(option == status ? null : option),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: l10n.contactSectionWhatYouKnow,
            actionLabel: l10n.contactEdit,
            onAction: onEdit,
          ),
          if (facts.isEmpty)
            Text(
              l10n.contactNothingYet,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: folo.textMuted,
              ),
            )
          else
            for (final (label, value, link) in facts)
              FactRow(
                label: label,
                value: value!,
                onTap: link == null ? null : () => onLaunch(link),
              ),
          if (history case final history?) ...[
            const SizedBox(height: AppSpacing.lg),
            history,
          ],
        ],
      ),
    );
  }
}

/// ⋯ on mobile: the person's name, their actions, then Delete apart.
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.title,
    required this.actions,
    required this.delete,
  });

  final String title;
  final List<_Action> actions;
  final _Action delete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;

    Widget tile(_Action action, {Color? color}) => ListTile(
      leading: Icon(action.icon, color: color),
      title: Text(action.label, style: TextStyle(color: color)),
      onTap: () => Navigator.pop(context, action.onTap),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            Card(child: Column(children: [for (final a in actions) tile(a)])),
            Card(child: tile(delete, color: error)),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
