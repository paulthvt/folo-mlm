import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/app_router.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/core/ui/folo_top_bar.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_workflow_repository.dart';
import 'workflows_harness.dart';

const _failed = "Couldn't save. Check your connection and try again.";

Finder _title(String text) =>
    find.descendant(of: find.byType(FoloTopBar), matching: find.text(text));

String _name(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

Iterable<String> _renames(FakeWorkflowRepository workflows) =>
    workflows.calls.where((call) => call.startsWith('rename'));

Future<void> _typeName(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextField).first, name);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the stage and the name', (tester) async {
    await openWorkflows(tester, Routes.settingsWorkflowLocation('samples'));

    expect(_title('Samples'), findsOneWidget);
    expect(find.text('PROSPECT'), findsOneWidget);
    expect(_name(tester), 'Samples');
  });

  testWidgets('a new name is trimmed, saved and shown', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    await _typeName(tester, '  Tasters  ');

    expect(_renames(workflows), ['rename(samples, Tasters)']);
    expect(_title('Tasters'), findsOneWidget);
    expect(_name(tester), 'Tasters');
  });

  testWidgets('an empty name puts the saved one back without writing', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    await _typeName(tester, '   ');
    expect(_name(tester), 'Samples');

    await _typeName(tester, 'Samples');
    expect(_renames(workflows), isEmpty);
  });

  testWidgets('a failed rename says so and puts the saved name back', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );
    workflows.failWith = PeopleFailure.network;

    await _typeName(tester, 'Tasters');

    expect(find.text(_failed), findsOneWidget);
    expect(_name(tester), 'Samples');
    expect(_title('Samples'), findsOneWidget);
  });

  testWidgets('a bad link says the workflow is not here', (tester) async {
    await openWorkflows(tester, Routes.settingsWorkflowLocation('gone'));

    expect(find.text("This workflow isn't here anymore"), findsOneWidget);

    await tester.tap(find.text('Back to workflows'));
    await tester.pumpAndSettle();
    expect(find.text('Health professionals'), findsOneWidget);
  });

  testWidgets('a workflow deleted elsewhere says so', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final container = await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    // Another device deleted it; this one reloads.
    workflows.store.removeWhere((workflow) => workflow.id == 'samples');
    container.invalidate(workflowsProvider('p@example.com'));
    await tester.pumpAndSettle();

    expect(find.text("This workflow isn't here anymore"), findsOneWidget);
    await tester.tap(find.text('Back to workflows'));
    await tester.pumpAndSettle();
    expect(find.text('Health professionals'), findsOneWidget);
    expect(find.text('Samples'), findsNothing);
  });

  testWidgets('desktop: typed name saved when go() tears down the editor', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final container = await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
      size: const Size(1440, 900),
    );

    await tester.enterText(find.byType(TextField).first, 'Tasters');
    // While focused, navigate away: the field is torn down with the typed name.
    container.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();

    expect(_renames(workflows), ['rename(samples, Tasters)']);
  });

  testWidgets('mobile: typed name saved when go() tears down the editor', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final container = await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    await tester.enterText(find.byType(TextField).first, 'Tasters');
    container.read(routerProvider).go(Routes.today);
    await tester.pumpAndSettle();

    expect(_renames(workflows), ['rename(samples, Tasters)']);
  });

  testWidgets('desktop: list shows the new name after deactivate save', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final container = await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
      size: const Size(1440, 900),
    );

    await tester.enterText(find.byType(TextField).first, 'Tasters');
    container.read(routerProvider).go(Routes.settingsWorkflows);
    await tester.pumpAndSettle();

    expect(find.text('Tasters'), findsOneWidget);
    expect(find.text('Samples'), findsNothing);
    expect(_renames(workflows), ['rename(samples, Tasters)']);
  });

  testWidgets('mobile: list shows the new name after deactivate save', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final container = await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    await tester.enterText(find.byType(TextField).first, 'Tasters');
    container.read(routerProvider).go(Routes.settingsWorkflows);
    await tester.pumpAndSettle();

    expect(find.text('Tasters'), findsOneWidget);
    expect(find.text('Samples'), findsNothing);
    expect(_renames(workflows), ['rename(samples, Tasters)']);
  });
}
