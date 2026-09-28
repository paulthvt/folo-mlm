import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/account.dart';
import 'package:folo/features/auth/domain/auth_change.dart';
import 'package:folo/features/contacts/data/people_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_people_repository.dart';

Person _person(
  String id,
  String name, {
  Stage stage = Stage.prospect,
  ProspectStatus? status,
}) => Person(
  id: id,
  name: name,
  stage: stage,
  prospectStatus: status,
  createdAt: DateTime.utc(2026, 3, 4),
);

typedef _World = ({
  ProviderContainer container,
  FakePeopleRepository people,
  FakeAuthRepository auth,
});

_World _world(List<Person> people) {
  final auth = FakeAuthRepository()
    ..session = true
    ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
  addTearDown(auth.dispose);
  final repository = FakePeopleRepository(people);
  final container = ProviderContainer.test(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      peopleRepositoryProvider.overrideWithValue(repository),
    ],
  );
  return (container: container, people: repository, auth: auth);
}

List<String> _names(ProviderContainer container) => [
  for (final person in container.read(peopleProvider).value!) person.name,
];

void main() {
  test('loads the book sorted by name, accents and case ignored', () async {
    final world = _world([
      _person('1', 'élodie'),
      _person('2', 'Bruno'),
      _person('3', 'Anne'),
    ]);

    await world.container.read(peopleProvider.future);

    expect(_names(world.container), ['Anne', 'Bruno', 'élodie']);
  });

  test('add keeps the list sorted and returns the new person', () async {
    final world = _world([_person('1', 'Anne'), _person('2', 'Chloé')]);
    await world.container.read(peopleProvider.future);

    final added = await world.container.read(peopleProvider.notifier).add((
      name: 'Bruno',
      stage: Stage.customer,
      phone: null,
      email: null,
      instagram: null,
    ));

    expect(added.name, 'Bruno');
    expect(_names(world.container), ['Anne', 'Bruno', 'Chloé']);
  });

  test('save replaces the person', () async {
    final world = _world([_person('1', 'Anne')]);
    await world.container.read(peopleProvider.future);

    await world.container
        .read(peopleProvider.notifier)
        .save(_person('1', 'Anne Martin'));

    expect(_names(world.container), ['Anne Martin']);
  });

  test('remove drops the person', () async {
    final world = _world([_person('1', 'Anne'), _person('2', 'Bruno')]);
    await world.container.read(peopleProvider.future);

    await world.container.read(peopleProvider.notifier).remove('1');

    expect(_names(world.container), ['Bruno']);
  });

  test('a failed save rethrows and keeps the list', () async {
    final world = _world([_person('1', 'Anne')]);
    await world.container.read(peopleProvider.future);
    world.people.failWith = PeopleFailure.network;

    await expectLater(
      world.container
          .read(peopleProvider.notifier)
          .save(_person('1', 'Changed')),
      throwsA(PeopleFailure.network),
    );
    await expectLater(
      world.container.read(peopleProvider.notifier).remove('1'),
      throwsA(PeopleFailure.network),
    );

    expect(_names(world.container), ['Anne']);
  });

  test('setStatus shows the change before the save returns', () async {
    final world = _world([_person('1', 'Anne')]);
    await world.container.read(peopleProvider.future);
    world.people.gate = Completer<void>();

    final saving = world.container
        .read(peopleProvider.notifier)
        .setStatus(_person('1', 'Anne'), ProspectStatus.thinking);

    expect(
      world.container.read(peopleProvider).value!.single.prospectStatus,
      ProspectStatus.thinking,
    );
    world.people.gate!.complete();
    await saving;
    expect(world.people.store['1']!.prospectStatus, ProspectStatus.thinking);
  });

  test('setStatus rolls back on failure and rethrows', () async {
    final world = _world([
      _person('1', 'Anne', status: ProspectStatus.interested),
    ]);
    await world.container.read(peopleProvider.future);
    world.people.failWith = PeopleFailure.network;

    await expectLater(
      world.container
          .read(peopleProvider.notifier)
          .setStatus(_person('1', 'Anne'), ProspectStatus.notNow),
      throwsA(PeopleFailure.network),
    );

    expect(
      world.container.read(peopleProvider).value!.single.prospectStatus,
      ProspectStatus.interested,
    );
  });

  test('setStatus rolls back only its own change', () async {
    final world = _world([
      _person('1', 'Anne', status: ProspectStatus.interested),
    ]);
    await world.container.read(peopleProvider.future);
    final controller = world.container.read(peopleProvider.notifier);
    final first = Completer<void>();
    final second = Completer<void>();

    world.people
      ..gate = first
      ..failWith = PeopleFailure.network;
    final failing = controller.setStatus(
      _person('1', 'Anne'),
      ProspectStatus.thinking,
    );
    world.people
      ..gate = second
      ..failWith = null;
    final succeeding = controller.setStatus(
      _person('1', 'Anne'),
      ProspectStatus.notNow,
    );

    first.complete();
    await expectLater(failing, throwsA(PeopleFailure.network));
    second.complete();
    await succeeding;

    expect(
      world.container.read(peopleProvider).value!.single.prospectStatus,
      ProspectStatus.notNow,
    );
  });

  test('switching account reloads and never shows the previous book', () async {
    final world = _world([_person('1', 'Anne')]);
    await world.container.read(peopleProvider.future);

    world.auth
      ..session = false
      ..account = null
      ..emit(AuthChange.signedOut);
    await Future<void>.delayed(Duration.zero);
    await world.container.read(peopleProvider.future);
    expect(world.container.read(peopleProvider).value, isEmpty);

    world.people.store
      ..clear()
      ..['9'] = _person('9', 'Zoé');
    world.people.gate = Completer<void>();
    world.auth
      ..session = true
      ..account = const Account(firstName: 'Zoé', email: 'z@example.com')
      ..emit(AuthChange.signedIn);
    await Future<void>.delayed(Duration.zero);

    // Loading the new book: the old one is not on screen meanwhile.
    expect(world.container.read(peopleProvider).value, isEmpty);
    world.people.gate!.complete();
    await world.container.read(peopleProvider.future);
    expect(_names(world.container), ['Zoé']);
  });

  test('is stale a minute after the last load', () async {
    final world = _world([]);
    await world.container.read(peopleProvider.future);
    final controller = world.container.read(peopleProvider.notifier);
    final now = DateTime.now();

    expect(controller.isStaleAt(now), isFalse);
    expect(
      controller.isStaleAt(
        now.add(PeopleController.staleAfter + const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });
}
