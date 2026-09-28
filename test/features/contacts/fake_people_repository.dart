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
  Future<Person> add(PersonDraft draft) async {
    await _record('add(${draft.name})');
    final person = Person(
      id: 'new-${_next++}',
      name: draft.name.trim(),
      stage: draft.stage,
      stageSince: DateTime.utc(2026, 9, 28),
      phone: draft.phone,
      email: draft.email,
      instagram: draft.instagram,
    );
    store[person.id] = person;
    return person;
  }

  @override
  Future<Person> update(Person person) async {
    await _record('update(${person.id})');
    store[person.id] = person;
    return person;
  }

  @override
  Future<void> delete(String id) async {
    await _record('delete($id)');
    store.remove(id);
  }

  /// What the database does on a stage change: a new [Person.stageSince], no
  /// status outside prospects, and an entry in the history.
  @override
  Future<Person> setStage(String id, Stage stage) async {
    await _record('setStage($id, ${stage.name})');
    final before = store[id]!;
    final moved = Person(
      id: id,
      name: before.name,
      stage: stage,
      stageSince: DateTime.utc(2026, 9, 28),
      prospectStatus: stage == Stage.prospect ? before.prospectStatus : null,
      phone: before.phone,
      email: before.email,
      instagram: before.instagram,
      needs: before.needs,
      products: before.products,
      profession: before.profession,
      address: before.address,
      notes: before.notes,
    );
    store[id] = moved;
    activities?.recordStage(id, stage);
    return moved;
  }
}
