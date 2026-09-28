import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/form_error.dart';
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
}

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
          .read(peopleProvider.notifier)
          .save(
            Person(
              id: p.id,
              name: _text(_Field.name)!,
              stage: p.stage,
              prospectStatus: p.prospectStatus,
              createdAt: p.createdAt,
              phone: _text(_Field.phone),
              email: _text(_Field.email),
              instagram: _text(_Field.instagram),
              needs: _text(_Field.needs),
              products: _text(_Field.products),
              profession: _text(_Field.profession),
              address: _text(_Field.address),
              notes: _text(_Field.notes),
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
        // Nine fields outgrow a short screen: the fields scroll, the title and
        // the buttons stay.
        child: Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.ms,
              children: [
                if (failure != null)
                  FormError(peopleFailureCopy(l10n, failure)),
                for (final field in _Field.values)
                  TextFormField(
                    controller: _controllers[field],
                    decoration: InputDecoration(labelText: labels[field]),
                    textCapitalization: field == _Field.name
                        ? TextCapitalization.words
                        : TextCapitalization.sentences,
                    keyboardType: switch (field) {
                      _Field.phone => TextInputType.phone,
                      _Field.email => TextInputType.emailAddress,
                      _Field.address || _Field.notes => TextInputType.multiline,
                      _ => TextInputType.text,
                    },
                    maxLines: field == _Field.notes || field == _Field.address
                        ? null
                        : 1,
                    validator: field == _Field.name
                        ? (value) => (value ?? '').trim().isEmpty
                              ? l10n.addPersonNameRequired
                              : null
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
