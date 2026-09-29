import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/core/ui/labeled_field.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Edit details: every field but the stage (it moves through ⋯ in #56) and the
/// status (edited on the detail screen). A scrolling sheet on mobile, a dialog
/// elsewhere.
Future<void> showEditPerson(BuildContext context, Person person) =>
    FoloDialog.show<void>(context, (_) => _EditPersonForm(person));

enum _Field {
  name,
  phone,
  email,
  instagram,
  needs,
  products,
  profession,
  address,
  notes,
  why,
  ownGoal,
  timeAvailable,
  wouldLoveTo,
  strengths,
  stuckOn,
}

/// A team member's own profile: only asked while they are on the team.
const _teamFields = {
  _Field.why,
  _Field.ownGoal,
  _Field.timeAvailable,
  _Field.wouldLoveTo,
  _Field.strengths,
  _Field.stuckOn,
};

/// Sentences in their words, not a single value.
const _multiline = {_Field.address, _Field.notes, ..._teamFields};

class _EditPersonForm extends ConsumerStatefulWidget {
  const _EditPersonForm(this.person);

  final Person person;

  @override
  ConsumerState<_EditPersonForm> createState() => _EditPersonFormState();
}

class _EditPersonFormState extends ConsumerState<_EditPersonForm> {
  final _form = GlobalKey<FormState>();
  late final Map<_Field, TextEditingController> _controllers = {
    for (final field in _Field.values)
      field: TextEditingController(text: _initial(field)),
  };
  bool _saving = false;
  PeopleFailure? _failure;

  String? _initial(_Field field) {
    final p = widget.person;
    return switch (field) {
      _Field.name => p.name,
      _Field.phone => p.phone,
      _Field.email => p.email,
      _Field.instagram => p.instagram,
      _Field.needs => p.needs,
      _Field.products => p.products,
      _Field.profession => p.profession,
      _Field.address => p.address,
      _Field.notes => p.notes,
      _Field.why => p.why,
      _Field.ownGoal => p.ownGoal,
      _Field.timeAvailable => p.timeAvailable,
      _Field.wouldLoveTo => p.wouldLoveTo,
      _Field.strengths => p.strengths,
      _Field.stuckOn => p.stuckOn,
    };
  }

  /// Blank is absent.
  String? _text(_Field field) {
    final text = _controllers[field]!.text.trim();
    return text.isEmpty ? null : text;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final p = widget.person;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(peopleProvider(ref.read(accountProvider)?.email).notifier)
          .save(
            Person(
              id: p.id,
              name: _text(_Field.name)!,
              stage: p.stage,
              prospectStatus: p.prospectStatus,
              stageSince: p.stageSince,
              phone: _text(_Field.phone),
              email: _text(_Field.email),
              instagram: _text(_Field.instagram),
              needs: _text(_Field.needs),
              products: _text(_Field.products),
              profession: _text(_Field.profession),
              address: _text(_Field.address),
              notes: _text(_Field.notes),
              why: _text(_Field.why),
              ownGoal: _text(_Field.ownGoal),
              timeAvailable: _text(_Field.timeAvailable),
              wouldLoveTo: _text(_Field.wouldLoveTo),
              strengths: _text(_Field.strengths),
              stuckOn: _text(_Field.stuckOn),
            ),
          );
      if (mounted) Navigator.pop(context);
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
    final labels = {
      _Field.name: l10n.addPersonName,
      _Field.phone: l10n.factPhone,
      _Field.email: l10n.factEmail,
      _Field.instagram: l10n.factInstagram,
      _Field.needs: l10n.factNeeds,
      _Field.products: l10n.factProducts,
      _Field.profession: l10n.factProfession,
      _Field.address: l10n.factAddress,
      _Field.notes: l10n.factNotes,
      _Field.why: l10n.factWhy,
      _Field.ownGoal: l10n.factOwnGoal,
      _Field.timeAvailable: l10n.factTimeAvailable,
      _Field.wouldLoveTo: l10n.factWouldLoveTo,
      _Field.strengths: l10n.factStrengths,
      _Field.stuckOn: l10n.factStuckOn,
    };

    return Form(
      key: _form,
      child: FoloDialog(
        title: l10n.editPersonTitle,
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
            for (final field in _Field.values)
              if (widget.person.stage == Stage.team ||
                  !_teamFields.contains(field))
                LabeledField(
                  label: labels[field]!,
                  child: TextFormField(
                    controller: _controllers[field],
                    textCapitalization: field == _Field.name
                        ? TextCapitalization.words
                        : TextCapitalization.sentences,
                    keyboardType: switch (field) {
                      _Field.phone => TextInputType.phone,
                      _Field.email => TextInputType.emailAddress,
                      _ when _multiline.contains(field) =>
                        TextInputType.multiline,
                      _ => TextInputType.text,
                    },
                    maxLines: _multiline.contains(field) ? null : 1,
                    validator: field == _Field.name
                        ? (value) => (value ?? '').trim().isEmpty
                              ? l10n.addPersonNameRequired
                              : null
                        : null,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
