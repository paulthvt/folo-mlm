import 'package:flutter_test/flutter_test.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/core/ui/labeled_field.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/edit_person_form.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_people_repository.dart';
import 'form_harness.dart';

final _marie = Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: Stage.prospect,
  prospectStatus: ProspectStatus.thinking,
  phone: '06 12 34 56 78',
  stageSince: DateTime.utc(2026, 3, 4),
);

void main() {
  late FakePeopleRepository people;

  setUp(() => people = FakePeopleRepository([_marie]));

  Future<void> open(WidgetTester tester) => pumpFormHarness(
    tester,
    people: people,
    open: (context) => showEditPerson(context, _marie),
    result: (_) {},
  );

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledField, label),
    matching: find.byType(TextFormField),
  );

  testWidgets('starts from what is saved', (tester) async {
    await open(tester);

    expect(find.text('Marie Dupont'), findsOneWidget);
    expect(find.text('06 12 34 56 78'), findsOneWidget);
  });

  testWidgets('saves every field and keeps stage and status', (tester) async {
    await open(tester);

    await tester.enterText(field('Needs'), 'Sleep, stress');
    await tester.enterText(field('Phone'), '');
    await tester.ensureVisible(field('Notes'));
    await tester.enterText(field('Notes'), 'Met at the market');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = people.store['p1']!;
    expect(saved.needs, 'Sleep, stress');
    expect(saved.phone, isNull);
    expect(saved.notes, 'Met at the market');
    expect(saved.stage, Stage.prospect);
    expect(saved.prospectStatus, ProspectStatus.thinking);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets("a team member's own profile is edited with the rest", (
    tester,
  ) async {
    final member = Person(
      id: 'p2',
      name: 'Léa Martin',
      stage: Stage.team,
      stageSince: DateTime.utc(2026, 3, 4),
      why: 'More time with my kids',
    );
    people = FakePeopleRepository([member]);
    await pumpFormHarness(
      tester,
      people: people,
      open: (context) => showEditPerson(context, member),
      result: (_) {},
    );

    expect(find.text('More time with my kids'), findsOneWidget);
    await tester.ensureVisible(field('Their own goal'));
    await tester.enterText(field('Their own goal'), 'Pay for the holidays');
    await tester.ensureVisible(field('Where they are stuck'));
    await tester.enterText(field('Where they are stuck'), 'Talking about it');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = people.store['p2']!;
    expect(saved.why, 'More time with my kids');
    expect(saved.ownGoal, 'Pay for the holidays');
    expect(saved.stuckOn, 'Talking about it');
    expect(saved.stage, Stage.team);
  });

  testWidgets('not on the team: no profile fields, and a saved one is kept', (
    tester,
  ) async {
    final former = Person(
      id: 'p3',
      name: 'Paul Roux',
      stage: Stage.customer,
      stageSince: DateTime.utc(2026, 3, 4),
      ownGoal: 'Pay for the holidays',
    );
    people = FakePeopleRepository([former]);
    await pumpFormHarness(
      tester,
      people: people,
      open: (context) => showEditPerson(context, former),
      result: (_) {},
    );

    expect(find.text('Their own goal'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(people.store['p3']!.ownGoal, 'Pay for the holidays');
  });

  testWidgets('a name is still required', (tester) async {
    await open(tester);

    await tester.enterText(field('Name'), '  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name.'), findsOneWidget);
    expect(people.calls, ['list()']);
  });

  testWidgets('a failure stays on the form with the input kept', (
    tester,
  ) async {
    await open(tester);
    people.failWith = PeopleFailure.unknown;

    await tester.enterText(field('Needs'), 'Sleep');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(FormError), findsOneWidget);
    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(find.text('Sleep'), findsOneWidget);
  });
}
