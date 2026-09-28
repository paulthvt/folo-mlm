import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/shell/app_shell.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/presentation/add_person_sheet.dart';
import 'package:folo/features/contacts/presentation/contact_list.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Opens a person: beside the list on desktop (the URL changes, the list keeps
/// its scroll and filter), pushed above it elsewhere so back returns to it.
void openContact(BuildContext context, String id) {
  final location = Routes.contactLocation(id);
  if (context.screenSize.isDesktop) {
    context.go(location);
  } else {
    unawaited(context.push(location));
  }
}

/// Reloads the book while the old list stays on screen. A failure says so in a
/// SnackBar instead of replacing the list with the error state.
Future<void> refreshPeople(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    ref.invalidate(peopleProvider);
    await ref.read(peopleProvider.future);
  } on PeopleFailure {
    messenger.showSnackBar(SnackBar(content: Text(l10n.contactsRefreshFailed)));
  }
}

/// The Contacts destination. On desktop it also holds [pane], the selected
/// person or an empty state, beside the list.
class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({this.pane, this.selectedId, super.key});

  final Widget? pane;
  final String? selectedId;

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  /// Fixed, like the Settings list, so a resized window narrows the pane.
  static const double _listWidth = 440;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Nothing is realtime: coming back to the app is when changes made on
  /// another device are most likely waiting. Quiet — a failure here keeps the
  /// list and says nothing; the user did not ask.
  void _onResume() {
    if (!ref.read(peopleProvider.notifier).isStaleAt(DateTime.now())) return;
    ref.refresh(peopleProvider.future).ignore();
  }

  Future<void> _add() async {
    final person = await showAddPerson(context);
    if (person != null && mounted) openContact(context, person.id);
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleProvider);
    final list = people.value;
    final sideNavigation = context.screenSize.usesSideNavigation;
    final pane = widget.pane;

    final Widget body;
    if (list != null) {
      body = ContactList(
        people: list,
        onOpen: (person) => openContact(context, person.id),
        onAdd: _add,
        onRefresh: () => refreshPeople(context, ref),
        selectedId: widget.selectedId,
        showRefresh: sideNavigation,
        accountAction: sideNavigation ? null : const AccountButton(),
      );
    } else if (people.hasError) {
      body = PeopleLoadError(onRetry: () => ref.invalidate(peopleProvider));
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SafeArea(
        child: pane == null
            ? body
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: _listWidth,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: FoloColors.of(context).borderSubtle,
                        ),
                      ),
                    ),
                    child: body,
                  ),
                  Expanded(child: pane),
                ],
              ),
      ),
    );
  }
}

/// The book could not be loaded and there is nothing to show instead. #46
/// replaces it with the shared offline presentation.
class PeopleLoadError extends StatelessWidget {
  const PeopleLoadError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l10n.contactsLoadError,
        body: l10n.contactsLoadErrorBody,
        actionLabel: l10n.contactsRetry,
        onAction: onRetry,
      ),
    );
  }
}
