import 'dart:async';

import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/workflows/data/workflow_repository.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

/// In-memory workflows that record calls, and fail or stall on demand.
class FakeWorkflowRepository implements WorkflowRepository {
  FakeWorkflowRepository([Iterable<Workflow> workflows = const []]) {
    store.addAll(workflows);
  }

  final List<Workflow> store = [];

  /// One entry per call, e.g. `seed(en)`.
  final List<String> calls = <String>[];

  /// Thrown by calls started while set. Use a `PeopleFailure`.
  Object? failWith;

  /// Calls started while set wait on it.
  Completer<void>? gate;

  Future<void> _record(String call) async {
    calls.add(call);
    final failure = failWith;
    final wait = gate;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
  }

  @override
  Future<List<Workflow>> list() async {
    await _record('list()');
    return [...store];
  }

  /// Like the RPC: a no-op once there are workflows. It does not start
  /// people; tests that need a place set it on the person.
  @override
  Future<void> seed(String lang, DateTime today) async {
    await _record('seed($lang)');
    if (store.isEmpty) store.addAll(samples());
  }

  /// The English defaults of spec §2.1.
  static List<Workflow> samples() => [
    _workflow('samples', Stage.prospect, 'Samples', isDefault: true, [
      ('Send a first message', 0),
      ('Send the samples', 1),
      ('Samples arrived', 4),
      ('Ask how the samples went', 3),
      ('Follow up', 7),
    ]),
    _workflow('health', Stage.prospect, 'Health professionals', [
      ('Introduce yourself', 0),
      ('Share a product sheet', 2),
      ('Offer a sample kit', 5),
      ('Follow up', 7),
    ]),
    _workflow('new-customer', Stage.customer, 'New customer', isDefault: true, [
      ('Thank them for the order', 0),
      ('Order arrived', 5),
      ('Check in on the products', 14),
      ('Suggest a refill routine', 21),
    ]),
    _workflow('refill', Stage.customer, 'Refill check-in', [
      ('Ask how supplies are going', 25),
      ('Help with the next order', 3),
    ]),
    _workflow(
      'getting-started',
      Stage.team,
      'Getting started',
      isDefault: true,
      [
        ('Welcome call', 0),
        ('Unboxing call', 5),
        ('First training', 3),
        ('First goal together', 7),
        ('Two-week check-in', 14),
      ],
    ),
  ];

  static Workflow _workflow(
    String id,
    Stage stage,
    String name,
    List<(String, int)> steps, {
    bool isDefault = false,
  }) => Workflow(
    id: id,
    stage: stage,
    name: name,
    isDefault: isDefault,
    steps: [
      for (final (index, (label, days)) in steps.indexed)
        WorkflowStep(
          id: '$id-${index + 1}',
          position: index + 1,
          label: label,
          days: days,
        ),
    ],
  );
}
