import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/core/ui/labeled_field.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/contact_channel.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Add someone: a sheet on mobile, a dialog elsewhere. Resolves to the saved
/// person, or null when dismissed.
Future<Person?> showAddPerson(BuildContext context) =>
    FoloDialog.show<Person>(context, (_) => const _AddPersonForm());

class _AddPersonForm extends ConsumerStatefulWidget {
  const _AddPersonForm();

  @override
  ConsumerState<_AddPersonForm> createState() => _AddPersonFormState();
}

class _AddPersonFormState extends ConsumerState<_AddPersonForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _reach = TextEditingController();
  Stage _stage = Stage.prospect;
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
    _reach.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final channel = guessChannel(_reach.text);
    String? value(ChannelKind kind) =>
        channel?.kind == kind ? channel!.value : null;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final owner = ref.read(accountProvider)?.email;
      final people = peopleProvider(owner);
      final workflows = ref.read(workflowsProvider(owner)).value ?? const [];
      final person = await ref
          .read(people.notifier)
          .add(
            (
              name: _name.text.trim(),
              stage: _stage,
              phone: value(ChannelKind.phone),
              email: value(ChannelKind.email),
              instagram: value(ChannelKind.instagram),
            ),
            workflow: defaultFor(workflows, _stage),
            today: today(),
          );
      if (mounted) Navigator.pop(context, person);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;
    // Loads the workflows, so the default is there by the time Add is tapped.
    ref.watch(workflowsProvider(ref.watch(accountProvider)?.email));

    return Form(
      key: _form,
      child: FoloDialog(
        title: l10n.addPersonTitle,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(material.saveButtonLabel),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
            LabeledField(
              label: l10n.addPersonName,
              child: TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.addPersonNameRequired
                    : null,
              ),
            ),
            LabeledField(
              label: l10n.addPersonReach,
              child: TextFormField(
                controller: _reach,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final stage in Stage.values)
                  ChoiceChip(
                    label: Text(stageLabel(l10n, stage)),
                    selected: _stage == stage,
                    onSelected: (_) => setState(() => _stage = stage),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
