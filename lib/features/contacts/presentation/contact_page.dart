import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/back.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/contact_details.dart';
import 'package:folo/features/contacts/presentation/contacts_page.dart';
import 'package:folo/features/contacts/presentation/edit_person_form.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// One person on mobile and tablet: a screen of its own above the list.
class ContactPage extends StatelessWidget {
  const ContactPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => backOr(context, Routes.contacts)),
      ),
      body: SafeArea(top: false, child: ContactPane(id: id)),
    );
  }
}

/// Desktop, nobody selected: the pane beside the list.
class ContactsNoSelection extends StatelessWidget {
  const ContactsNoSelection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: EmptyState(
        icon: Icons.people_outline,
        title: l10n.contactNoSelectionTitle,
        body: l10n.contactNoSelectionBody,
      ),
    );
  }
}

/// A person found in the loaded book (there is no second fetch), wired to
/// saving, navigation and the other apps. Shared by [ContactPage] and the
/// desktop pane.
class ContactPane extends ConsumerWidget {
  const ContactPane({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final book = peopleProvider(ref.watch(accountProvider)?.email);
    final people = ref.watch(book);
    final list = people.value;
    if (list == null) {
      return people.hasError
          ? PeopleLoadError(onRetry: () => ref.invalidate(book))
          : const Center(child: CircularProgressIndicator());
    }

    final person = list.where((person) => person.id == id).firstOrNull;
    if (person == null) {
      // Deleted elsewhere, or a bad link.
      return Center(
        child: EmptyState(
          icon: Icons.person_off_outlined,
          title: l10n.contactMissingTitle,
          body: l10n.contactMissingBody,
          actionLabel: l10n.contactBackToContacts,
          onAction: () => context.go(Routes.contacts),
        ),
      );
    }

    return ContactDetails(
      person: person,
      onStatus: (status) => unawaited(_setStatus(context, ref, person, status)),
      onEdit: () => unawaited(showEditPerson(context, person)),
      onDelete: () => unawaited(_delete(context, ref)),
      onLaunch: (uri) => unawaited(_launch(context, uri)),
      onRefresh: () => refreshPeople(context, ref),
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    Person person,
    ProspectStatus? status,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(peopleProvider(ref.read(accountProvider)?.email).notifier)
          .setStatus(person, status);
    } on PeopleFailure catch (failure) {
      // The controller has already put the chip back.
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }

  /// Leaves the screen first, so it never shows the missing state for the
  /// person just deleted; a failure brings nothing back but a SnackBar, and
  /// the person is still in the list.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      peopleProvider(ref.read(accountProvider)?.email).notifier,
    );
    if (context.screenSize.isDesktop) {
      context.go(Routes.contacts);
    } else {
      backOr(context, Routes.contacts);
    }
    try {
      await controller.remove(id);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    bool opened;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      // No app for the scheme throws on some platforms instead of returning
      // false.
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.contactLaunchFailed)));
    }
  }
}
