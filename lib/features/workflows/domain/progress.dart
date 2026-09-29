import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

/// Where a person stands in their workflow, as the NEXT STEP card shows it.
sealed class WorkflowProgress {
  const WorkflowProgress();
}

final class Paused extends WorkflowProgress {
  const Paused(this.since);

  final DateTime since;
}

final class Done extends WorkflowProgress {
  const Done(this.workflow);

  final Workflow workflow;
}

final class OnStep extends WorkflowProgress {
  const OnStep({
    required this.workflow,
    required this.step,
    required this.index,
    required this.total,
    required this.due,
  });

  final Workflow workflow;
  final WorkflowStep step;

  /// 1-based, for "3 of 5".
  final int index;
  final int total;
  final DateTime due;
}

/// Found by position, not by step id, so edits apply at once: changed days
/// move the due date, a removed current step hands over to the next, a step
/// inserted before the current one is skipped.
///
/// Null when the person follows no workflow, or one missing from the list
/// (deleted elsewhere). Paused wins over everything.
WorkflowProgress? progressOf(Person person, Workflow? workflow) {
  if (person.pausedAt case final since?) return Paused(since);
  final place = person.place;
  if (place == null || workflow == null || workflow.id != place.workflowId) {
    return null;
  }
  final steps = workflow.steps;
  final index = steps.indexWhere((step) => step.position >= place.atPosition);
  if (index == -1) return Done(workflow);
  final step = steps[index];
  return OnStep(
    workflow: workflow,
    step: step,
    index: index + 1,
    total: steps.length,
    due: addDays(place.lastTick, step.days),
  );
}

/// Where ticking [current] leads: the next step, or one past the last (done).
num nextPosition(Workflow workflow, WorkflowStep current) {
  final steps = workflow.steps;
  final index = steps.indexWhere((step) => step.id == current.id);
  return index + 1 < steps.length
      ? steps[index + 1].position
      : current.position + 1;
}

/// Starts [workflow] with its first step due on [firstDue].
WorkflowPlace start(Workflow workflow, {required DateTime firstDue}) {
  final first = workflow.steps.firstOrNull;
  return (
    workflowId: workflow.id,
    atPosition: first?.position ?? 0,
    lastTick: addDays(firstDue, -(first?.days ?? 0)),
  );
}

/// The first step's day when nobody picks one.
DateTime firstDueDefault(Workflow workflow, DateTime today) =>
    addDays(today, workflow.steps.firstOrNull?.days ?? 0);

/// Calendar days, so a clock change never shifts a day.
DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
