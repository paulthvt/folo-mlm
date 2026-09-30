import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

/// Someone worth a message today, and the step that says why.
typedef Due = ({Person person, OnStep step});

/// People whose step is due on or before [today], oldest first, then by name.
/// Paused, done, no workflow and not yet due fall out. The server decides the
/// day (`due_on`); this only compares it with the device's today.
List<Due> dueToday(
  List<Person> people,
  List<Workflow> workflows,
  DateTime today,
) {
  final due = [
    for (final person in people)
      if (progressOf(person, findWorkflow(workflows, person.place?.workflowId))
          case final OnStep step when !step.due.isAfter(today))
        (person: person, step: step),
  ];
  due.sort((a, b) {
    final byDay = a.step.due.compareTo(b.step.due);
    return byDay != 0
        ? byDay
        : searchKey(a.person.name).compareTo(searchKey(b.person.name));
  });
  return due;
}
