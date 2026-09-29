import 'dart:async';

import 'package:folo/features/contacts/data/people_repository.dart';
import 'package:folo/features/contacts/domain/person.dart';

import 'fake_activity_repository.dart';

/// An in-memory book that records calls, and fails or stalls on demand.
class FakePeopleRepository implements PeopleRepository {
  FakePeopleRepository([Iterable<Person> people = const []]) {
    for (final person in people) {
      store[person.id] = person;
    }
  }

  final Map<String, Person> store = {};

  /// One entry per call, e.g. `update(p1)`.
  final List<String> calls = <String>[];

  /// Thrown by calls started while set. Use a `PeopleFailure`.
  Object? failWith;

  /// Calls started while set wait on it.
  Completer<void>? gate;

  /// Where [setStage] writes its history entry, as the database does. Unset,
  /// stage changes leave no entry.
  FakeActivityRepository? activities;

  var _next = 0;

  Future<void> _record(String call) async {
    calls.add(call);
    // Captured now: a later change applies to later calls only.
    final failure = failWith;
    final wait = gate;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
  }

  @override
  Future<List<Person>> list() async {
    await _record('list()');
    return store.values.toList();
  }

  @override
  Future<Person> add(PersonDraft draft, {WorkflowPlace? place}) async {
    await _record('add(${draft.name})');
    final person = Person(
      id: 'new-${_next++}',
      name: draft.name.trim(),
      stage: draft.stage,
      stageSince: DateTime.utc(2026, 9, 28),
      phone: draft.phone,
      email: draft.email,
      instagram: draft.instagram,
      place: place,
    );
    store[person.id] = person;
    return person;
  }

  @override
  Future<Person> update(Person person) async {
    await _record('update(${person.id})');
    // The real update writes neither the stage nor the workflow fields.
    final stored = store[person.id]!;
    final saved = Person(
      id: person.id,
      name: person.name,
      stage: stored.stage,
      stageSince: stored.stageSince,
      prospectStatus: stored.stage == Stage.prospect
          ? person.prospectStatus
          : null,
      phone: person.phone,
      email: person.email,
      instagram: person.instagram,
      needs: person.needs,
      products: person.products,
      profession: person.profession,
      address: person.address,
      notes: person.notes,
      place: stored.place,
      pausedAt: stored.pausedAt,
    );
    store[person.id] = saved;
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    await _record('delete($id)');
    store.remove(id);
  }

  /// What the database does on a stage change: a new [Person.stageSince], no
  /// status outside prospects, no pause, and an entry in the history.
  @override
  Future<Person> setStage(
    String id,
    Stage stage, {
    WorkflowPlace? place,
  }) async {
    await _record('setStage($id, ${stage.name})');
    final before = store[id]!;
    final moved = _with(
      before,
      stage: stage,
      stageSince: DateTime.utc(2026, 9, 28),
      status: before.prospectStatus,
      place: place,
      pausedAt: null,
    );
    activities?.recordStage(id, stage);
    return moved;
  }

  @override
  Future<Person> setPlace(String id, WorkflowPlace? place) async {
    await _record('setPlace($id, ${place?.workflowId ?? 'none'})');
    final before = store[id]!;
    return _with(before, place: place, pausedAt: null);
  }

  @override
  Future<Person> pause(String id, DateTime at, {required bool notNow}) async {
    await _record('pause($id)');
    final before = store[id]!;
    return _with(
      before,
      status: notNow ? ProspectStatus.notNow : before.prospectStatus,
      place: before.place,
      pausedAt: at,
    );
  }

  @override
  Future<Person> resume(String id, DateTime today) async {
    await _record('resume($id)');
    final before = store[id]!;
    final place = before.place;
    return _with(
      before,
      place: place == null
          ? null
          : (
              workflowId: place.workflowId,
              atPosition: place.atPosition,
              lastTick: today,
            ),
      pausedAt: null,
    );
  }

  @override
  Future<Person> completeStep(
    String personId,
    String stepId,
    num nextPosition,
    DateTime on,
  ) async {
    await _record('completeStep($personId, $stepId)');
    final before = store[personId]!;
    return _with(
      before,
      place: (
        workflowId: before.place!.workflowId,
        atPosition: nextPosition,
        lastTick: on,
      ),
      pausedAt: before.pausedAt,
    );
  }

  /// [before] with the given fields replaced, stored and returned. Stage and
  /// status default to [before]'s; a status never survives outside prospects.
  Person _with(
    Person before, {
    Stage? stage,
    DateTime? stageSince,
    ProspectStatus? status,
    required WorkflowPlace? place,
    required DateTime? pausedAt,
  }) {
    final newStage = stage ?? before.stage;
    final person = Person(
      id: before.id,
      name: before.name,
      stage: newStage,
      stageSince: stageSince ?? before.stageSince,
      prospectStatus: newStage == Stage.prospect
          ? status ?? before.prospectStatus
          : null,
      phone: before.phone,
      email: before.email,
      instagram: before.instagram,
      needs: before.needs,
      products: before.products,
      profession: before.profession,
      address: before.address,
      notes: before.notes,
      place: place,
      pausedAt: pausedAt,
    );
    store[person.id] = person;
    return person;
  }
}
