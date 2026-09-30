import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/workflows/data/workflow_repository.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';

import '../../auth/fake_auth_repository.dart';
import '../../contacts/fake_activity_repository.dart';
import '../../contacts/fake_people_repository.dart';
import '../fake_workflow_repository.dart';

typedef _World = ({
  ProviderContainer container,
  FakeWorkflowRepository workflows,
  FakePeopleRepository people,
});

_World _world(FakeWorkflowRepository workflows, {String? locale}) {
  final auth = FakeAuthRepository()
    ..session = true
    ..account = Account(
      firstName: 'Pauline',
      email: 'p@example.com',
      locale: locale,
    );
  addTearDown(auth.dispose);
  final people = FakePeopleRepository();
  final container = ProviderContainer.test(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      peopleRepositoryProvider.overrideWithValue(people),
      activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
      workflowRepositoryProvider.overrideWithValue(workflows),
    ],
  );
  return (container: container, workflows: workflows, people: people);
}

void main() {
  test('a seeded account seeds (the server no-ops), then lists', () async {
    final world = _world(
      FakeWorkflowRepository(FakeWorkflowRepository.samples()),
    );

    final list = await world.container.read(
      workflowsProvider('p@example.com').future,
    );

    expect(list, hasLength(5));
    expect(world.workflows.calls, ['seed(en)', 'list()']);
  });

  test('an empty account seeds once, lists again, reloads the book', () async {
    final world = _world(FakeWorkflowRepository(), locale: 'fr');
    final book = peopleProvider('p@example.com');
    world.container.listen(book, (_, _) {});
    await world.container.read(book.future);

    final list = await world.container.read(
      workflowsProvider('p@example.com').future,
    );
    await world.container.read(book.future);

    expect(list, hasLength(5));
    expect(world.workflows.calls, ['seed(fr)', 'list()']);
    // The seed started people on a workflow: the book is fetched again.
    expect(world.people.calls, ['list()', 'list()']);
  });

  test('signed out is no workflows and no call', () async {
    final world = _world(FakeWorkflowRepository());

    expect(await world.container.read(workflowsProvider(null).future), isEmpty);
    expect(world.workflows.calls, isEmpty);
  });

  test('a failed seed is an error, and a retry seeds again', () async {
    final workflows = FakeWorkflowRepository()
      ..seedFailWith = PeopleFailure.network;
    final world = _world(workflows);
    final provider = workflowsProvider('p@example.com');
    world.container.listen(provider, (_, _) {});

    await expectLater(
      world.container.read(provider.future),
      throwsA(PeopleFailure.network),
    );
    expect(world.workflows.calls, ['seed(en)']);

    workflows.seedFailWith = null;
    world.container.invalidate(provider);

    expect(await world.container.read(provider.future), hasLength(5));
  });

  test('the seed language: French only for French', () {
    expect(seedLanguage('fr'), 'fr');
    expect(seedLanguage('en'), 'en');
    expect(seedLanguage('de'), 'en');
  });

  test('disposed while seeding: no throw', () async {
    final workflows = FakeWorkflowRepository()..seedGate = Completer<void>();
    final world = _world(workflows);
    final book = peopleProvider('p@example.com');
    world.container.listen(book, (_, _) {});
    await world.container.read(book.future);
    expect(world.people.calls, ['list()']);

    final sub = world.container.listen(
      workflowsProvider('p@example.com'),
      (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);

    sub.close();
    world.container.dispose();
    workflows.seedGate!.complete();
    await Future<void>.delayed(Duration.zero);

    // The seed's invalidate never ran: people was not fetched again.
    expect(world.people.calls, ['list()']);
  });

  test('an account that deleted everything is not seeded again', () async {
    final workflows = FakeWorkflowRepository();
    final world = _world(workflows);
    final provider = workflowsProvider('p@example.com');
    world.container.listen(provider, (_, _) {});
    await world.container.read(provider.future);

    for (final workflow in [...workflows.store]) {
      await workflows.delete(workflow.id);
    }
    world.container.invalidate(provider);

    expect(await world.container.read(provider.future), isEmpty);
  });

  test('edit writes, then reloads the workflows and the people', () async {
    final world = _world(
      FakeWorkflowRepository(FakeWorkflowRepository.samples()),
    );
    final provider = workflowsProvider('p@example.com');
    final book = peopleProvider('p@example.com');
    world.container.listen(provider, (_, _) {});
    world.container.listen(book, (_, _) {});
    await world.container.read(provider.future);
    await world.container.read(book.future);
    world.workflows.calls.clear();
    world.people.calls.clear();

    await world.container
        .read(provider.notifier)
        .edit((repository) => repository.rename('samples', 'Tasters'));
    final list = await world.container.read(provider.future);
    await world.container.read(book.future);

    expect(world.workflows.calls, [
      'rename(samples, Tasters)',
      'seed(en)',
      'list()',
    ]);
    expect(findWorkflow(list, 'samples')!.name, 'Tasters');
    expect(world.people.calls, ['list()']);
  });

  test('a failed edit rethrows and reloads nothing', () async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final world = _world(workflows);
    final provider = workflowsProvider('p@example.com');
    world.container.listen(provider, (_, _) {});
    await world.container.read(provider.future);
    workflows
      ..calls.clear()
      ..failWith = PeopleFailure.network;

    await expectLater(
      world.container
          .read(provider.notifier)
          .edit((repository) => repository.rename('samples', 'X')),
      throwsA(PeopleFailure.network),
    );
    expect(workflows.calls, ['rename(samples, X)']);
  });
}
