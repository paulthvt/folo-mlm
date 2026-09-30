import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/follow_with_field.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Moves [person] to [stage] once confirmed: a sheet on mobile, a dialog
/// elsewhere. Closes once the move is saved.
Future<void> showChangeStage(
  BuildContext context,
  Person person,
  Stage stage,
) => LoomiaDialog.show<void>(
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
  /// What the user picked; null until they pick, so the default can arrive
  /// with the workflows. The record tells "picked nothing" from "not yet".
  ({FollowWith? follow})? _picked;
  bool _saving = false;
  PeopleFailure? _failure;

  FollowWith? _follow(List<Workflow> workflows, DateTime today) {
    if (_picked case (:final follow)) return follow;
    final suggested = defaultFor(workflows, widget.stage);
    return suggested == null
        ? null
        : (workflow: suggested, firstDue: firstDueDefault(suggested, today));
  }

  Future<void> _move(FollowWith? follow) async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(peopleProvider(ref.read(accountProvider)?.email).notifier)
          .moveTo(widget.person, widget.stage, follow: follow);
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
    final owner = ref.watch(accountProvider)?.email;
    final workflowsAsync = ref.watch(workflowsProvider(owner));
    final workflows = workflowsAsync.value ?? const [];
    final now = today();
    final follow = _follow(workflows, now);
    final ending = findWorkflow(workflows, widget.person.place?.workflowId);
    final onStep = progressOf(widget.person, ending) is OnStep;
    // The database clears a prospect's status when they leave prospects.
    final clearsStatus =
        widget.person.prospectStatus != null && widget.stage != Stage.prospect;
    final body = clearsStatus
        ? l10n.changeStageBodyCleared
        : l10n.changeStageBody;

    return LoomiaDialog(
      title: movedTitle(l10n, firstName(widget.person), widget.stage),
      body: ending != null && onStep
          ? '$body ${l10n.changeStageWorkflowEnds(ending.name)}'
          : body,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving || !workflowsAsync.hasValue
              ? null
              : () => _move(follow),
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(moveToLabel(l10n, widget.stage)),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.ms,
        children: [
          if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
          FollowWithField(
            workflows: forStage(workflows, widget.stage),
            value: follow,
            today: now,
            onChanged: (next) => setState(() => _picked = (follow: next)),
          ),
        ],
      ),
    );
  }
}
