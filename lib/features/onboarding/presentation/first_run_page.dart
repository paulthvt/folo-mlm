import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/contacts/presentation/add_person_sheet.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Shown once, after sign-up: who the user already works with. Every way out,
/// Skip included, marks the account onboarded, so it never comes back.
///
/// The web has no address book to read: there, only Add someone.
class FirstRunPage extends ConsumerStatefulWidget {
  const FirstRunPage({super.key});

  @override
  ConsumerState<FirstRunPage> createState() => _FirstRunPageState();
}

class _FirstRunPageState extends ConsumerState<FirstRunPage> {
  bool _busy = false;
  AuthFailure? _failure;

  /// Marks the account, then goes to [location], with [above] pushed on top
  /// so back returns to [location] rather than out of the app. A failure
  /// stays here.
  Future<void> _leaveTo(String location, {String? above}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).markOnboarded();
      if (!mounted) return;
      context.go(location);
      if (above != null) unawaited(context.push(above));
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = failure;
        });
      }
    }
  }

  Future<void> _add() async {
    final person = await showAddPerson(context);
    if (person != null && mounted) {
      await _leaveTo(Routes.contactLocation(person.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final failure = _failure;

    return AuthScaffold(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            Text(l10n.firstRunEyebrow, style: text.displaySmall),
            Text(l10n.firstRunTitle, style: text.titleLarge),
            Text(
              kIsWeb ? l10n.firstRunBodyWeb : l10n.firstRunBody,
              style: text.bodyMedium,
            ),
          ],
        ),
        if (failure != null) FormError(authFailureCopy(l10n, failure)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (kIsWeb)
              FilledButton(
                onPressed: _busy ? null : _add,
                child: Text(l10n.contactsAdd),
              )
            else ...[
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _leaveTo(
                        Routes.contacts,
                        above: Routes.importContacts,
                      ),
                icon: const Icon(Icons.contacts_outlined),
                label: Text(l10n.contactsImport),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _add,
                child: Text(l10n.contactsAdd),
              ),
            ],
            TextButton(
              onPressed: _busy ? null : () => _leaveTo(Routes.today),
              child: Text(l10n.firstRunSkip),
            ),
          ],
        ),
      ],
    );
  }
}
