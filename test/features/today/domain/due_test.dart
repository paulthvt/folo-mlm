import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/today/domain/due.dart';

import '../../workflows/fake_workflow_repository.dart';

final _workflows = FakeWorkflowRepository.samples();
final _today = DateTime(2026, 9, 29);

/// On Samples step 2 as the server returns them, due on [due].
Person _person(
  String id,
  String name, {
  DateTime? due,
  String? step = 'samples-2',
  DateTime? pausedAt,
  bool follows = true,
}) => Person(
  id: id,
  name: name,
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026),
  place: follows
      ? (workflowId: 'samples', atPosition: 2, lastTick: DateTime(2026, 9, 20))
      : null,
  currentStepId: follows ? step : null,
  dueOn: due,
  pausedAt: pausedAt,
);

void main() {
  test('due today and late stay; not yet due, paused, done and no workflow '
      'fall out', () {
    final due = dueToday(
      [
        _person('today', 'Today', due: _today),
        _person('late', 'Late', due: DateTime(2026, 9, 27)),
        _person('tomorrow', 'Tomorrow', due: DateTime(2026, 9, 30)),
        _person('paused', 'Paused', pausedAt: DateTime.utc(2026, 9, 1)),
        _person('done', 'Done', step: null),
        _person('none', 'None', follows: false),
      ],
      _workflows,
      _today,
    );

    expect([for (final row in due) row.person.id], ['late', 'today']);
    expect(due.first.step.step.label, 'Send the samples');
  });

  test('oldest first, then by name whatever the case', () {
    final due = dueToday(
      [
        _person('c', 'claire', due: DateTime(2026, 9, 28)),
        _person('b', 'Bruno', due: DateTime(2026, 9, 28)),
        _person('a', 'Anna', due: _today),
      ],
      _workflows,
      _today,
    );

    expect(
      [for (final row in due) row.person.name],
      ['Bruno', 'claire', 'Anna'],
    );
  });
}
