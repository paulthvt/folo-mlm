import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/app_router.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/contact_details.dart';
import 'package:folo/features/contacts/presentation/contact_list.dart';
import 'package:folo/features/contacts/presentation/contact_page.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_people_repository.dart';

final _marie = Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: Stage.prospect,
  prospectStatus: ProspectStatus.thinking,
  phone: '06 12 34 56 78',
  createdAt: DateTime.utc(2026, 3, 4),
);

final _lucas = Person(
  id: 'p2',
  name: 'Lucas Martin',
  stage: Stage.customer,
  createdAt: DateTime.utc(2026, 5, 1),
);

const _phone = Size(390, 844);
const _desktop = Size(1440, 900);

void main() {
  late FakePeopleRepository people;

  setUp(() => people = FakePeopleRepository([_marie, _lucas]));

  Future<void> openContacts(WidgetTester tester, {Size size = _phone}) async {
    final container = await pumpFolo(tester, size: size, people: people);
    container.read(routerProvider).go(Routes.contacts);
    await tester.pumpAndSettle();
  }

  Future<void> openMarie(WidgetTester tester) async {
    await openContacts(tester);
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();
  }

  testWidgets('a failed load shows Retry, which loads the list', (
    tester,
  ) async {
    people.failWith = PeopleFailure.network;
    await openContacts(tester);

    expect(find.text("Couldn't load your contacts."), findsOneWidget);
    people.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Marie Dupont'), findsOneWidget);
  });

  testWidgets('refresh failure keeps the list', (tester) async {
    await openContacts(tester);
    people.failWith = PeopleFailure.network;

    await tester.fling(find.byType(ContactList), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Marie Dupont'), findsOneWidget);
    expect(
      find.text("Couldn't refresh. You're seeing the last loaded list."),
      findsOneWidget,
    );
    expect(find.text("Couldn't load your contacts."), findsNothing);
  });

  testWidgets('Add someone opens the new person', (tester) async {
    await openContacts(tester);

    await tester.tap(find.byTooltip('Add someone'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Chloé');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactPage), findsOneWidget);
    expect(find.text('Chloé'), findsOneWidget);
  });

  testWidgets('missing person', (tester) async {
    final container = await pumpFolo(tester, size: _phone, people: people);
    container.read(routerProvider).go(Routes.contactLocation('gone'));
    await tester.pumpAndSettle();

    expect(find.text("This person isn't here anymore"), findsOneWidget);
    await tester.tap(find.text('Back to contacts'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactList), findsOneWidget);
  });

  testWidgets('delete returns to the list without the person', (tester) async {
    await openMarie(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactList), findsOneWidget);
    expect(find.text('Marie Dupont'), findsNothing);
    expect(people.store.containsKey('p1'), isFalse);
  });

  testWidgets('a failed delete says so and keeps the person', (tester) async {
    await openMarie(tester);
    people.failWith = PeopleFailure.unknown;

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(find.text('Marie Dupont'), findsOneWidget);
  });

  testWidgets('a failed status change reverts with a SnackBar', (tester) async {
    await openMarie(tester);
    people.failWith = PeopleFailure.network;

    await tester.tap(find.widgetWithText(ChoiceChip, 'Interested'));
    await tester.pumpAndSettle();

    ChoiceChip chip(String label) =>
        tester.widget(find.widgetWithText(ChoiceChip, label));
    expect(chip('Thinking about it').selected, isTrue);
    expect(chip('Interested').selected, isFalse);
    expect(
      find.text('Couldn\'t save. Check your connection and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('desktop: the split keeps the list and its filter', (
    tester,
  ) async {
    await openContacts(tester, size: _desktop);

    expect(find.text('Pick someone'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Customers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lucas Martin'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactDetails), findsOneWidget);
    expect(find.byType(ContactPage), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    final filter = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Customers'),
    );
    expect(filter.selected, isTrue);
    expect(find.text('Marie Dupont'), findsNothing);
  });
}
