import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/features/contacts/domain/activity.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/history_controller.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Log something with [person]: a sheet on mobile, a dialog elsewhere. Closes
/// once the entry is saved.
Future<void> showLogActivity(BuildContext context, Person person) =>
    FoloDialog.show<void>(context, (_) => _LogActivityForm(person));

class _LogActivityForm extends ConsumerStatefulWidget {
  const _LogActivityForm(this.person);

  final Person person;

  @override
  ConsumerState<_LogActivityForm> createState() => _LogActivityFormState();
}

class _LogActivityFormState extends ConsumerState<_LogActivityForm> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
  ActivityKind _kind = ActivityKind.note;
  DateTime _day = today();
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final day = await pickDay(context, initial: _day, last: today());
    if (day != null && mounted) setState(() => _day = day);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(historyProvider(widget.person.id).notifier).add((
        kind: _kind,
        happenedOn: _day,
        text: _text.text.trim(),
      ));
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
    // Keeps the history alive while the sheet is open, whatever is under it.
    ref.watch(historyProvider(widget.person.id));
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;
    final currentDay = today();

    return Form(
      key: _form,
      child: FoloDialog(
        title: l10n.logTitle(firstName(widget.person)),
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
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final kind in ActivityKind.values)
                  if (kind.byUser)
                    ChoiceChip(
                      label: Text(kindLabel(l10n, kind)!),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
              ],
            ),
            InkWell(
              onTap: _pickDay,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.logWhen,
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _day == currentDay
                      ? l10n.logWhenToday(_day)
                      : dayLabel(l10n, _day, currentDay),
                ),
              ),
            ),
            TextFormField(
              controller: _text,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? l10n.logWhatRequired : null,
              decoration: InputDecoration(labelText: l10n.logWhat),
            ),
          ],
        ),
      ),
    );
  }
}
