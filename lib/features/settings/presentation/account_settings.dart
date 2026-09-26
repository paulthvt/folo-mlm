import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/auth_validation_copy.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/settings/presentation/settings_action.dart';
import 'package:folo/features/settings/presentation/widgets/settings_group.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Name, email, delete account.
///
/// Deleting needs no navigation here: the session ends, and the router's
/// redirect takes the user to /welcome.
class AccountSettings extends ConsumerStatefulWidget {
  const AccountSettings({super.key});

  @override
  ConsumerState<AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends ConsumerState<AccountSettings>
    with SettingsAction {
  Future<void> _editName(String current) async {
    final name = await FoloDialog.show<String>(
      context,
      (context) => _NameForm(initial: current),
    );
    if (name != null && name != current) {
      await run((auth) => auth.updateFirstName(name));
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await FoloDialog.show<bool>(context, (context) {
      final l10n = AppLocalizations.of(context);
      final scheme = Theme.of(context).colorScheme;
      return FoloDialog(
        title: l10n.settingsDeleteTitle,
        body: l10n.settingsDeleteBody,
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
            child: Text(l10n.settingsDeleteConfirm),
          ),
        ],
      );
    });
    if (confirmed == true) await run((auth) => auth.deleteAccount());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final account = ref.watch(accountProvider);
    final error = failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (account != null) ...[
          SettingsGroup(
            children: [
              ListTile(
                title: Text(l10n.authFirstNameLabel),
                subtitle: account.firstName.isEmpty
                    ? null
                    : Text(account.firstName),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: busy ? null : () => _editName(account.firstName),
              ),
              ListTile(
                title: Text(l10n.authEmailLabel),
                subtitle: Text(account.email),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (error != null) ...[
          FormError(authFailureCopy(l10n, error)),
          const SizedBox(height: AppSpacing.md),
        ],
        SettingsGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              iconColor: scheme.error,
              textColor: scheme.error,
              title: Text(l10n.settingsDeleteAccount),
              onTap: busy ? null : _confirmDelete,
            ),
          ],
        ),
      ],
    );
  }
}

/// Pops with the trimmed name, or null when cancelled.
class _NameForm extends StatefulWidget {
  const _NameForm({required this.initial});

  final String initial;

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    return Form(
      key: _form,
      child: FoloDialog(
        title: l10n.settingsEditNameTitle,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _submit,
            child: Text(material.saveButtonLabel),
          ),
        ],
        child: TextFormField(
          controller: _name,
          autofocus: true,
          validator: (value) => firstNameFieldError(l10n, value),
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.givenName],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: InputDecoration(labelText: l10n.authFirstNameLabel),
        ),
      ),
    );
  }
}
