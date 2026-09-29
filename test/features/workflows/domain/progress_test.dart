import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

WorkflowStep _step(num position, String label, int days, {String? note}) =>
    WorkflowStep(
      id: 's$position',
      position: position,
      label: label,
      days: days,
      note: note,
    );

Workflow _samples([List<WorkflowStep>? steps]) => Workflow(
  id: 'w1',
  stage: Stage.prospect,
  name: 'Samples',
  isDefault: true,
  steps:
      steps ??
      [
        _step(1, 'Send a first message', 0),
        _step(2, 'Send the samples', 1),
        _step(3, 'Samples arrived', 4),
      ],
);

Person _on(num atPosition, {DateTime? lastTick, DateTime? pausedAt}) => Person(
  id: 'p1',
  name: 'Sarah',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 9, 1),
  place: (
    workflowId: 'w1',
    atPosition: atPosition,
    lastTick: lastTick ?? DateTime(2026, 9, 28),
  ),
  pausedAt: pausedAt,
);

void main() {
  test('the current step is the first at or after the position', () {
    final progress = progressOf(_on(2), _samples()) as OnStep;

    expect(progress.step.label, 'Send the samples');
    expect(progress.index, 2);
    expect(progress.total, 3);
    expect(progress.due, DateTime(2026, 9, 29));
  });

  test('steps come sorted by position whatever the order given', () {
    final workflow = _samples([_step(3, 'C', 0), _step(1, 'A', 0)]);

    expect([for (final s in workflow.steps) s.label], ['A', 'C']);
  });

  test('days changed: the due date follows at once', () {
    final workflow = _samples([
      _step(1, 'Send a first message', 0),
      _step(2, 'Send the samples', 5),
    ]);

    expect((progressOf(_on(2), workflow) as OnStep).due, DateTime(2026, 10, 3));
  });

  test('current step removed: the next one becomes current', () {
    final workflow = _samples([
      _step(1, 'Send a first message', 0),
      _step(3, 'Samples arrived', 4),
    ]);

    expect(
      (progressOf(_on(2), workflow) as OnStep).step.label,
      'Samples arrived',
    );
  });

  test('a step inserted before the current one is skipped', () {
    final workflow = _samples([
      _step(1, 'Send a first message', 0),
      _step(1.5, 'Inserted', 2),
      _step(2, 'Send the samples', 1),
    ]);

    final progress = progressOf(_on(2), workflow) as OnStep;
    expect(progress.step.label, 'Send the samples');
    expect(progress.index, 3);
  });

  test('a rename shows at once', () {
    final workflow = _samples([_step(1, 'Say hello', 0)]);

    expect((progressOf(_on(1), workflow) as OnStep).step.label, 'Say hello');
  });

  test('past the last step is done; a workflow with no steps too', () {
    expect(progressOf(_on(4), _samples()), isA<Done>());
    expect(progressOf(_on(1), _samples(const [])), isA<Done>());
  });

  test('paused wins over everything, even no workflow', () {
    final since = DateTime.utc(2026, 7, 12);

    expect(progressOf(_on(2, pausedAt: since), _samples()), isA<Paused>());
    final nobody = Person(
      id: 'p2',
      name: 'Claire',
      stage: Stage.customer,
      stageSince: DateTime.utc(2026, 9, 1),
      pausedAt: since,
    );
    expect((progressOf(nobody, null) as Paused).since, since);
  });

  test('no workflow, or one that is not in the list, is no progress', () {
    final nobody = Person(
      id: 'p2',
      name: 'Claire',
      stage: Stage.customer,
      stageSince: DateTime.utc(2026, 9, 1),
    );
    expect(progressOf(nobody, _samples()), isNull);
    // Deleted on another device: the person still points at it.
    expect(progressOf(_on(2), null), isNull);
    expect(progressOf(_on(2), findWorkflow(const [], 'w1')), isNull);
  });

  test('resumed on a finished workflow, it is still done', () {
    expect(
      progressOf(_on(4, lastTick: DateTime(2026, 10, 1)), _samples()),
      isA<Done>(),
    );
  });

  test('nextPosition: the next step, or one past the last', () {
    final workflow = _samples();

    expect(nextPosition(workflow, workflow.steps[0]), 2);
    expect(nextPosition(workflow, workflow.steps[2]), 4);
    expect(
      progressOf(_on(nextPosition(workflow, workflow.steps[2])), workflow),
      isA<Done>(),
    );
  });

  test('start puts the first step on the chosen day', () {
    final workflow = _samples([_step(1, 'Welcome call', 3)]);

    final place = start(workflow, firstDue: DateTime(2026, 10, 2));

    expect(place.workflowId, 'w1');
    expect(place.atPosition, 1);
    expect(place.lastTick, DateTime(2026, 9, 29));
    expect(
      firstDueDefault(workflow, DateTime(2026, 9, 29)),
      DateTime(2026, 10, 2),
    );
  });

  test('days are calendar days, across a clock change', () {
    // Paris moves its clocks back on 25 October 2026.
    expect(daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
    expect(addDays(DateTime(2026, 10, 24), 2), DateTime(2026, 10, 26));
  });

  test('forStage: the default first, then by name', () {
    final workflows = [
      Workflow(
        id: 'b',
        stage: Stage.customer,
        name: 'B',
        isDefault: false,
        steps: const [],
      ),
      Workflow(
        id: 'z',
        stage: Stage.customer,
        name: 'Z',
        isDefault: true,
        steps: const [],
      ),
      _samples(),
    ];

    expect(
      [for (final w in forStage(workflows, Stage.customer)) w.id],
      ['z', 'b'],
    );
    expect(defaultFor(workflows, Stage.customer)?.id, 'z');
    expect(defaultFor(workflows, Stage.team), isNull);
  });
}
