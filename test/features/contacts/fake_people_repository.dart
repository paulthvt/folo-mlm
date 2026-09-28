import 'dart:async';

import 'package:folo/features/contacts/data/people_repository.dart';
import 'package:folo/features/contacts/domain/person.dart';

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
      createdAt: DateTime.utc(2026, 9, 28),
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
}
