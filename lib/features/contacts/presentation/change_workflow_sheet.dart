import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/follow_with_field.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Picks what [person] follows next: a sheet on mobile, a dialog elsewhere.
/// Saving starts the picked workflow from its first step, even the current
/// one. Closes once saved.
Future<void> showChangeWorkflow(BuildContext context, Person person) =>
    FoloDialog.show<void>(context, (_) => _ChangeWorkflow(person));

class _ChangeWorkflow extends ConsumerStatefulWidget {
  const _ChangeWorkflow(this.person);

  final Person person;

  @override
  ConsumerState<_ChangeWorkflow> createState() => _ChangeWorkflowState();
}

class _ChangeWorkflowState extends ConsumerState<_ChangeWorkflow> {
  /// Null until the user picks; see Change stage.
  ({FollowWith? follow})? _picked;
  bool _saving = false;
  PeopleFailure? _failure;

  FollowWith? _follow(List<Workflow> workflows, DateTime today) {
    if (_picked case (:final follow)) return follow;
    final suggested =
        findWorkflow(workflows, widget.person.place?.workflowId) ??
        defaultFor(workflows, widget.person.stage);
    return suggested == null
        ? null
        : (workflow: suggested, firstDue: firstDueDefault(suggested, today));
  }

  Future<void> _save(FollowWith? follow) async {
    // Close without writing if the user hasn't picked anything.
    if (_picked == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(peopleProvider(ref.read(accountProvider)?.email).notifier)
          .setWorkflow(widget.person, follow);
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
    final owner = ref.watch(accountProvider)?.email;
    final workflows = ref.watch(workflowsProvider(owner)).value ?? const [];
    final now = today();
    final follow = _follow(workflows, now);

    return FoloDialog(
      title: l10n.changeWorkflowTitle(firstName(widget.person)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(follow),
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
          FollowWithField(
            workflows: forStage(workflows, widget.person.stage),
            value: follow,
            today: now,
            onChanged: (next) => setState(() => _picked = (follow: next)),
          ),
        ],
      ),
    );
  }
}
