import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/account.dart';
import 'package:folo/features/auth/domain/auth_change.dart';
import 'package:folo/features/contacts/data/activity_repository.dart';
import 'package:folo/features/contacts/data/people_repository.dart';
import 'package:folo/features/contacts/domain/activity.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/history_controller.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_activity_repository.dart';
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
  stageSince: DateTime.utc(2026, 3, 4),
);

typedef _World = ({
  ProviderContainer container,
  FakePeopleRepository people,
  FakeActivityRepository activities,
  FakeAuthRepository auth,
});

_World _world(List<Person> people) {
  final auth = FakeAuthRepository()
    ..session = true
    ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
  addTearDown(auth.dispose);
  final activities = FakeActivityRepository();
  final repository = FakePeopleRepository(people)..activities = activities;
  final container = ProviderContainer.test(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      peopleRepositoryProvider.overrideWithValue(repository),
      activityRepositoryProvider.overrideWithValue(activities),
    ],
  );
  return (
    container: container,
    people: repository,
    activities: activities,
    auth: auth,
  );
}

/// The signed-in account's book, as the screens read it.
AsyncNotifierProvider<PeopleController, List<Person>> _book(
  ProviderContainer container,
) => peopleProvider(container.read(accountProvider)?.email);

List<String> _names(ProviderContainer container) => [
  for (final person in container.read(_book(container)).value!) person.name,
];

void main() {
  test('loads the book sorted by name, accents and case ignored', () async {
    final world = _world([
      _person('1', 'élodie'),
      _person('2', 'Bruno'),
      _person('3', 'Anne'),
    ]);

    await world.container.read(_book(world.container).future);

    expect(_names(world.container), ['Anne', 'Bruno', 'élodie']);
  });

  test('add keeps the list sorted and returns the new person', () async {
    final world = _world([_person('1', 'Anne'), _person('2', 'Chloé')]);
    await world.container.read(_book(world.container).future);

    final added = await world.container
        .read(_book(world.container).notifier)
        .add((
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
    await world.container.read(_book(world.container).future);

    await world.container
        .read(_book(world.container).notifier)
        .save(_person('1', 'Anne Martin'));

    expect(_names(world.container), ['Anne Martin']);
  });

  test('remove drops the person', () async {
    final world = _world([_person('1', 'Anne'), _person('2', 'Bruno')]);
    await world.container.read(_book(world.container).future);

    await world.container.read(_book(world.container).notifier).remove('1');

    expect(_names(world.container), ['Bruno']);
  });

  test('a failed save rethrows and keeps the list', () async {
    final world = _world([_person('1', 'Anne')]);
    await world.container.read(_book(world.container).future);
    world.people.failWith = PeopleFailure.network;

    await expectLater(
      world.container
          .read(_book(world.container).notifier)
          .save(_person('1', 'Changed')),
      throwsA(PeopleFailure.network),
    );
    await expectLater(
      world.container.read(_book(world.container).notifier).remove('1'),
      throwsA(PeopleFailure.network),
    );

    expect(_names(world.container), ['Anne']);
  });

  test('setStatus shows the change before the save returns', () async {
    final world = _world([_person('1', 'Anne')]);
    await world.container.read(_book(world.container).future);
    world.people.gate = Completer<void>();

    final saving = world.container
        .read(_book(world.container).notifier)
        .setStatus(_person('1', 'Anne'), ProspectStatus.thinking);

    expect(
      world.container.read(_book(world.container)).value!.single.prospectStatus,
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
    await world.container.read(_book(world.container).future);
    world.people.failWith = PeopleFailure.network;

    await expectLater(
      world.container
          .read(_book(world.container).notifier)
          .setStatus(_person('1', 'Anne'), ProspectStatus.notNow),
      throwsA(PeopleFailure.network),
    );

    expect(
      world.container.read(_book(world.container)).value!.single.prospectStatus,
      ProspectStatus.interested,
    );
  });

  test('setStatus rolls back only its own change', () async {
    final world = _world([
      _person('1', 'Anne', status: ProspectStatus.interested),
    ]);
    await world.container.read(_book(world.container).future);
    final controller = world.container.read(_book(world.container).notifier);
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
      world.container.read(_book(world.container)).value!.single.prospectStatus,
      ProspectStatus.notNow,
    );
  });

  test('switching account reloads and never shows the previous book', () async {
    final world = _world([_person('1', 'Anne')]);
    await world.container.read(_book(world.container).future);

    world.auth
      ..session = false
      ..account = null
      ..emit(AuthChange.signedOut);
    await Future<void>.delayed(Duration.zero);
    await world.container.read(_book(world.container).future);
    expect(world.container.read(_book(world.container)).value, isEmpty);

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
    expect(world.container.read(_book(world.container)).hasValue, isFalse);
    world.people.gate!.complete();
    await world.container.read(_book(world.container).future);
    expect(_names(world.container), ['Zoé']);
  });

  test('the next account never inherits the book, even unwatched', () async {
    final world = _world([_person('1', 'Anne')]);
    // Read, not listened: nothing is watching the book when the user signs out,
    // as when they leave Contacts for Settings first.
    await world.container.read(_book(world.container).future);

    world.auth
      ..session = false
      ..account = null
      ..emit(AuthChange.signedOut);
    await Future<void>.delayed(Duration.zero);

    world.people.store.clear();
    world.people.failWith = PeopleFailure.network;
    world.auth
      ..session = true
      ..account = const Account(firstName: 'Zoé', email: 'z@example.com')
      ..emit(AuthChange.signedIn);
    await Future<void>.delayed(Duration.zero);

    final loading = world.container.read(_book(world.container));
    expect(loading.hasValue, isFalse);
    await expectLater(
      world.container.read(_book(world.container).future),
      throwsA(PeopleFailure.network),
    );
    final failed = world.container.read(_book(world.container));
    expect(failed.hasError, isTrue);
    expect(failed.hasValue, isFalse);
  });

  test('is stale a minute after the last load', () async {
    final world = _world([]);
    await world.container.read(_book(world.container).future);
    final controller = world.container.read(_book(world.container).notifier);
    final now = DateTime.now();

    expect(controller.isStaleAt(now), isFalse);
    expect(
      controller.isStaleAt(
        now.add(PeopleController.staleAfter + const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });

  test(
    'moveTo takes what the server returns and reloads the history',
    () async {
      final world = _world([
        _person('p1', 'Marie', status: ProspectStatus.interested),
      ]);
      final book = _book(world.container);
      await world.container.read(book.future);
      world.container.listen(historyProvider('p1'), (_, _) {});
      await world.container.read(historyProvider('p1').future);
      final marie = world.container.read(book).value!.single;

      await world.container.read(book.notifier).moveTo(marie, Stage.customer);

      final moved = world.container.read(book).value!.single;
      expect(moved.stage, Stage.customer);
      expect(moved.prospectStatus, isNull);
      expect(moved.stageSince, DateTime.utc(2026, 9, 28));
      final history = await world.container.read(historyProvider('p1').future);
      expect(history.single.kind, ActivityKind.stage);
      expect(world.activities.calls, ['list(p1)', 'list(p1)']);
    },
  );

  test('a failed moveTo rethrows and changes nothing', () async {
    final world = _world([_person('p1', 'Marie')]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;
    world.people.failWith = PeopleFailure.network;

    await expectLater(
      world.container.read(book.notifier).moveTo(marie, Stage.team),
      throwsA(PeopleFailure.network),
    );
    expect(world.container.read(book).value!.single.stage, Stage.prospect);
  });
}
