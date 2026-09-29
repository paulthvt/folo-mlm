import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/contact_row.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/core/ui/folo_chip.dart';
import 'package:folo/core/ui/folo_top_bar.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/domain/search_key.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The book: search, stage filter, one row per person, sorted by name.
///
/// A pure function of [people]; the search text and the filter are this
/// widget's own state.
class ContactList extends StatefulWidget {
  const ContactList({
    required this.people,
    required this.onOpen,
    required this.onAdd,
    required this.onRefresh,
    this.selectedId,
    this.showRefresh = false,
    this.accountAction,
    super.key,
  });

  final List<Person> people;
  final ValueChanged<Person> onOpen;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  /// The person open beside the list, on desktop.
  final String? selectedId;

  /// A refresh button, where a mouse cannot pull.
  final bool showRefresh;

  /// Settings, where there is no sidebar to hold it.
  final Widget? accountAction;

  @override
  State<ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<ContactList> {
  String _query = '';

  /// Null is everyone.
  Stage? _stage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final people = widget.people;
    final query = searchKey(_query);
    final shown = [
      for (final person in people)
        if ((_stage == null || person.stage == _stage) &&
            searchKey(person.name).contains(query))
          person,
    ];
    final account = widget.accountAction;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        // Pull to refresh works on a short list too.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          FoloTopBar(
            title: l10n.contactsTitle,
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showRefresh)
                  IconButton(
                    onPressed: widget.onRefresh,
                    tooltip: l10n.contactsRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                IconButton.filledTonal(
                  onPressed: widget.onAdd,
                  tooltip: l10n.contactsAdd,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                ),
                ?account,
              ],
            ),
          ),
          if (people.isEmpty)
            EmptyState(
              icon: Icons.people_outline,
              title: l10n.contactsEmptyTitle,
              body: l10n.contactsEmptyBody,
              actionLabel: l10n.contactsAdd,
              onAction: widget.onAdd,
            )
          else ...[
            TextField(
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.contactsSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.ms),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final (stage, label) in [
                  (null, l10n.contactsFilterEveryone),
                  (Stage.prospect, l10n.contactsFilterProspects),
                  (Stage.customer, l10n.contactsFilterCustomers),
                  (Stage.team, l10n.contactsFilterTeam),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _stage == stage,
                    onSelected: (_) => setState(() => _stage = stage),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.ms),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  l10n.contactsNoMatch,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: FoloColors.of(context).textMuted),
                ),
              )
            else
              for (final person in shown)
                ContactRow(
                  name: person.name,
                  subtitle: contactSubtitle(l10n, person),
                  trailing: FoloChip(label: stageLabel(l10n, person.stage)),
                  selected: person.id == widget.selectedId,
                  onTap: () => widget.onOpen(person),
                ),
          ],
        ],
      ),
    );
  }
}
