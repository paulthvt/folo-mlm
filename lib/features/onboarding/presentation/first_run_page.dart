import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/business_model/business_model_copy.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:loomia/features/auth/presentation/auth_failure_copy.dart';
import 'package:loomia/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:loomia/features/contacts/presentation/add_person_sheet.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Shown once, after sign-up, in two steps: which company the user works
/// with, then who they already work with. One decision per step.
///
/// The step is local state, not a route, so the router's onboarding guard
/// stays as it is. Back on the second step — the button or the system
/// gesture — returns to the first.
class FirstRunPage extends StatefulWidget {
  const FirstRunPage({super.key});

  @override
  State<FirstRunPage> createState() => _FirstRunPageState();
}

class _FirstRunPageState extends State<FirstRunPage> {
  bool _askCompany = true;

  void _show({required bool company}) => setState(() => _askCompany = company);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _askCompany,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _show(company: true);
      },
      child: _askCompany
          ? FirstRunCompanyStep(onChosen: () => _show(company: false))
          : FirstRunPeopleStep(onBack: () => _show(company: true)),
    );
  }
}

/// Step 1. Tapping a company saves it and moves on: nothing is preselected
/// and there is no Next, the tap is the answer. A failure stays here.
class FirstRunCompanyStep extends ConsumerStatefulWidget {
  const FirstRunCompanyStep({required this.onChosen, super.key});

  final VoidCallback onChosen;

  @override
  ConsumerState<FirstRunCompanyStep> createState() =>
      _FirstRunCompanyStepState();
}

class _FirstRunCompanyStepState extends ConsumerState<FirstRunCompanyStep> {
  bool _busy = false;
  AuthFailure? _failure;

  Future<void> _choose(BusinessModel model) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateBusinessModel(model);
      if (mounted) widget.onChosen();
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = failure;
        });
      }
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
            Text(l10n.businessModelQuestion, style: text.titleLarge),
            Text(l10n.firstRunCompanyBody, style: text.bodyMedium),
          ],
        ),
        if (failure != null) FormError(authFailureCopy(l10n, failure)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            for (final model in const [
              BusinessModel.doterra,
              BusinessModel.other,
            ])
              Card(
                key: ValueKey('business-model-${model.name}'),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: Text(businessModelLabel(l10n, model)),
                  subtitle: Text(switch (model) {
                    BusinessModel.doterra => l10n.firstRunDoterraDetail,
                    BusinessModel.other => l10n.firstRunOtherDetail,
                  }),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _busy ? null : () => _choose(model),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Step 2: who the user already works with. Every way out, Skip included,
/// marks the account onboarded, so it never comes back.
///
/// The web has no address book to read: there, only Add someone.
class FirstRunPeopleStep extends ConsumerStatefulWidget {
  const FirstRunPeopleStep({required this.onBack, super.key});

  /// Back to step 1.
  final VoidCallback onBack;

  @override
  ConsumerState<FirstRunPeopleStep> createState() => _FirstRunPeopleStepState();
}

class _FirstRunPeopleStepState extends ConsumerState<FirstRunPeopleStep> {
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

    // No "Welcome" here: step 1 said it (Figma 212:3241).
    return AuthScaffold(
      onBack: widget.onBack,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
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
