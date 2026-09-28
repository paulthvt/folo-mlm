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

enum _More { edit, delete }

/// One person: who they are, how to reach them, where it stands, what you
/// know. A pure view; the page owns saving and navigation.
///
/// `NEXT STEP` and `HISTORY` are not here yet: they arrive whole with #57 and
/// #56.
class ContactDetails extends StatelessWidget {
  const ContactDetails({
    required this.person,
    required this.onStatus,
    required this.onEdit,
    required this.onDelete,
    required this.onLaunch,
    required this.onRefresh,
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

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await FoloDialog.show<bool>(context, (context) {
      final l10n = AppLocalizations.of(context);
      final scheme = Theme.of(context).colorScheme;
      return FoloDialog(
        title: l10n.contactDeleteTitle(person.name),
        body: l10n.contactDeleteBody,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.contactDeleteConfirm),
          ),
        ],
      );
    });
    if (confirmed == true) onDelete();
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
              PopupMenuButton<_More>(
                tooltip: l10n.contactMore,
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (choice) => switch (choice) {
                  _More.edit => onEdit(),
                  _More.delete => _confirmDelete(context),
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _More.edit,
                    child: Text(l10n.contactEditDetails),
                  ),
                  PopupMenuItem(
                    value: _More.delete,
                    child: Text(
                      l10n.contactDelete,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
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
        ],
      ),
    );
  }
}
