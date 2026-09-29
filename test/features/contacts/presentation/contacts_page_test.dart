import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/app_router.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/features/contacts/domain/activity.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/contact_details.dart';
import 'package:folo/features/contacts/presentation/contact_list.dart';
import 'package:folo/features/contacts/presentation/contact_page.dart';
import 'package:folo/features/contacts/presentation/history_section.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_activity_repository.dart';
import '../fake_people_repository.dart';

final _marie = Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: Stage.prospect,
  prospectStatus: ProspectStatus.thinking,
  phone: '06 12 34 56 78',
  stageSince: DateTime.utc(2026, 3, 4),
);

final _lucas = Person(
  id: 'p2',
  name: 'Lucas Martin',
  stage: Stage.customer,
  stageSince: DateTime.utc(2026, 5, 1),
);

const _phone = Size(390, 844);
const _desktop = Size(1440, 900);

Activity _note(String id, String text, int day) => Activity(
  id: id,
  personId: 'p1',
  kind: ActivityKind.note,
  happenedOn: DateTime(2026, 9, day),
  text: text,
  createdAt: DateTime.utc(2026, 9, day, 12),
);

void main() {
  late FakePeopleRepository people;
  late FakeActivityRepository activities;

  setUp(() {
    activities = FakeActivityRepository();
    people = FakePeopleRepository([_marie, _lucas])..activities = activities;
  });

  Future<void> openContacts(WidgetTester tester, {Size size = _phone}) async {
    final container = await pumpFolo(
      tester,
      size: size,
      people: people,
      activities: activities,
    );
    container.read(routerProvider).go(Routes.contacts);
    await tester.pumpAndSettle();
  }

  Future<void> openMarie(WidgetTester tester) async {
    await openContacts(tester);
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();
  }

  /// HISTORY sits below the fold on a phone, and the list builds lazily.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.descendant(
        of: find.byType(ContactDetails),
        matching: find.byType(Scrollable),
      ),
    );
    // The last jump lays out on the next frame.
    await tester.pump();
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
    await tester.tap(find.text('Delete Marie'));
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
    await tester.tap(find.text('Delete Marie'));
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

  testWidgets('moving someone updates the header and the history', (
    tester,
  ) async {
    await openMarie(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to customers'));
    await tester.pumpAndSettle();
    expect(find.text('Marie is now a customer'), findsOneWidget);
    expect(
      find.text(
        'Everything you noted stays with them. Where it stands is cleared.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Move to customers'));
    await tester.pumpAndSettle();

    expect(find.text('Customer since September 2026'), findsOneWidget);
    await reveal(tester, find.text('Became a customer'));
    expect(find.text('Became a customer'), findsOneWidget);
  });

  testWidgets('a failed move keeps the sheet open and the stage', (
    tester,
  ) async {
    await openMarie(tester);
    people.failWith = PeopleFailure.network;

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to team'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move to team'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('Marie is now on your team'), findsOneWidget);
    expect(find.text('Prospect since March 2026'), findsOneWidget);
  });

  testWidgets('the latest 3 entries; See all shows the rest in place', (
    tester,
  ) async {
    activities.store.addAll([
      _note('a1', 'First call', 1),
      _note('a2', 'Sent the price list', 5),
      _note('a3', 'Ordered the cream', 10),
      _note('a4', 'Asked about delivery', 15),
    ]);
    await openMarie(tester);

    await reveal(tester, find.text('See all 4'));
    expect(find.text('Asked about delivery'), findsOneWidget);
    expect(find.text('First call'), findsNothing);
    await tester.tap(find.text('See all 4'));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('First call'));
    expect(find.text('See all 4'), findsNothing);
  });

  testWidgets('nothing logged yet', (tester) async {
    await openMarie(tester);

    await reveal(tester, find.text('Nothing logged yet.'));
    expect(find.text('Nothing logged yet.'), findsOneWidget);
  });

  testWidgets('a failed history load has its own Retry', (tester) async {
    activities.failWith = PeopleFailure.network;
    await openMarie(tester);

    await reveal(tester, find.text("Couldn't load the history."));
    expect(find.text('Marie Dupont'), findsOneWidget);
    activities.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load the history."), findsNothing);
    expect(find.text('Nothing logged yet.'), findsOneWidget);
  });

  testWidgets('Retry on the history shows the spinner, not the error', (
    tester,
  ) async {
    activities.failWith = PeopleFailure.network;
    await openMarie(tester);
    await reveal(tester, find.text("Couldn't load the history."));

    activities
      ..failWith = null
      ..gate = Completer<void>();
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(find.text("Couldn't load the history."), findsNothing);
    expect(
      find.descendant(
        of: find.byType(HistorySection),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    activities.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Nothing logged yet.'), findsOneWidget);
  });

  testWidgets('long-press deletes an entry once confirmed', (tester) async {
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    await openMarie(tester);

    await reveal(tester, find.text('Ordered the cream'));
    await tester.longPress(find.text('Ordered the cream'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this entry?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(activities.calls, contains('delete(a1)'));
    expect(find.text('Ordered the cream'), findsNothing);
  });

  testWidgets('a failed delete brings the entry back with a SnackBar', (
    tester,
  ) async {
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    await openMarie(tester);
    activities.failWith = PeopleFailure.network;

    await reveal(tester, find.text('Ordered the cream'));
    await tester.longPress(find.text('Ordered the cream'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Ordered the cream'), findsOneWidget);
    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('a stage entry cannot be deleted', (tester) async {
    activities.recordStage('p1', Stage.customer);
    await openMarie(tester);

    await reveal(tester, find.text('Became a customer'));
    await tester.longPress(find.text('Became a customer'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this entry?'), findsNothing);
  });

  testWidgets('screen readers get a Delete action on an entry', (tester) async {
    final semantics = tester.ensureSemantics();
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    await openMarie(tester);
    await reveal(tester, find.text('Ordered the cream'));

    expect(
      tester.getSemantics(find.text('Ordered the cream')),
      isSemantics(
        customActions: [const CustomSemanticsAction(label: 'Delete')],
      ),
    );
    semantics.dispose();
  });

  testWidgets('Log something from ⋯ adds to the history', (tester) async {
    await openMarie(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log something'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What happened'),
      'Met at the market',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Met at the market'));
    expect(find.text('Met at the market'), findsOneWidget);
  });

  testWidgets('Add in HISTORY opens Log something', (tester) async {
    await openMarie(tester);

    await reveal(tester, find.text('HISTORY'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Log something with Marie'), findsOneWidget);
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

  testWidgets('desktop: right-click deletes an entry in the split', (
    tester,
  ) async {
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    await openContacts(tester, size: _desktop);
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Ordered the cream'));
    await tester.tap(find.text('Ordered the cream'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Delete this entry?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(activities.calls, contains('delete(a1)'));
    expect(find.text('Ordered the cream'), findsNothing);
  });
}
