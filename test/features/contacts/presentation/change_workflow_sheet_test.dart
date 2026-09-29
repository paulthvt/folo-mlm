import 'package:flutter_test/flutter_test.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/change_workflow_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_people_repository.dart';
import 'form_harness.dart';

Person _sarah({WorkflowPlace? place}) => Person(
  id: 'p1',
  name: 'Sarah Martin',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 3, 4),
  place: place,
);

void main() {
  late FakePeopleRepository people;

  Future<void> open(WidgetTester tester, Person person) {
    people = FakePeopleRepository([person]);
    return pumpFormHarness(
      tester,
      people: people,
      open: (context) => showChangeWorkflow(context, person),
      result: (_) {},
    );
  }

  testWidgets('the current workflow is selected; Save changes it', (
    tester,
  ) async {
    await open(
      tester,
      _sarah(
        place: (
          workflowId: 'health',
          atPosition: 2,
          lastTick: DateTime(2026, 9, 28),
        ),
      ),
    );

    expect(find.text("Change Sarah's workflow"), findsOneWidget);
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'health',
    );
    await tester.tap(find.text('Samples'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('setPlace(p1, samples)'));
    expect(find.text("Change Sarah's workflow"), findsNothing);
  });

  testWidgets('no workflow: the default is selected', (tester) async {
    await open(tester, _sarah());

    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'samples',
    );
  });

  testWidgets('a failure stays open and says why', (tester) async {
    await open(tester, _sarah());
    people.failWith = PeopleFailure.network;

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(FormError), findsOneWidget);
    expect(find.text("Change Sarah's workflow"), findsOneWidget);
  });
}
