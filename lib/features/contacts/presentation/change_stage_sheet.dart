import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Moves [person] to [stage] once confirmed: a sheet on mobile, a dialog
/// elsewhere. Closes once the move is saved.
Future<void> showChangeStage(
  BuildContext context,
  Person person,
  Stage stage,
) => FoloDialog.show<void>(
  context,
  (_) => _ChangeStage(person: person, stage: stage),
);

class _ChangeStage extends ConsumerStatefulWidget {
  const _ChangeStage({required this.person, required this.stage});

  final Person person;
  final Stage stage;

  @override
  ConsumerState<_ChangeStage> createState() => _ChangeStageState();
}

class _ChangeStageState extends ConsumerState<_ChangeStage> {
  bool _saving = false;
  PeopleFailure? _failure;

  Future<void> _move() async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(peopleProvider(ref.read(accountProvider)?.email).notifier)
          .moveTo(widget.person, widget.stage);
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
    final failure = _failure;
    // The database clears a prospect's status when they leave prospects.
    final clearsStatus =
        widget.person.prospectStatus != null && widget.stage != Stage.prospect;

    return FoloDialog(
      title: movedTitle(l10n, firstName(widget.person), widget.stage),
      body: clearsStatus ? l10n.changeStageBodyCleared : l10n.changeStageBody,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving ? null : _move,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(moveToLabel(l10n, widget.stage)),
        ),
      ],
      child: failure == null
          ? null
          : FormError(peopleFailureCopy(l10n, failure)),
    );
  }
}
