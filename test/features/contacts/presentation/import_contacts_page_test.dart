import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/app_router.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/contact_list.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_people_repository.dart';
import '../fake_phone_contacts_repository.dart';

const _phone = Size(390, 844);

final _marie = Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: Stage.prospect,
  phone: '06 12 34 56 78',
  stageSince: DateTime.utc(2026, 3, 4),
);

Future<FakePeopleRepository> _openImport(
  WidgetTester tester,
  FakePhoneContactsRepository phone,
) async {
  final people = FakePeopleRepository([_marie]);
  final container = await pumpFolo(
    tester,
    size: _phone,
    people: people,
    phoneContacts: phone,
  );
  container.read(routerProvider).go(Routes.importContacts);
  await tester.pumpAndSettle();
  return people;
}

void main() {
  testWidgets('imports the ticked contacts at the chosen stage', (
    tester,
  ) async {
    final people = await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Maman', phone: '+33 6 12 34 56 78', email: null),
        (name: 'Chloé Bernard', phone: '07 11 22 33 44', email: null),
        (name: 'Denis', phone: null, email: 'denis@example.com'),
      ]),
    );

    // Marie's number, saved under another name: flagged, not ticked.
    expect(find.text('Already in Folo'), findsOneWidget);
    expect(find.text('0 selected'.toUpperCase()), findsOneWidget);
    final import = find.widgetWithText(FilledButton, 'Import');
    expect(tester.widget<FilledButton>(import).onPressed, isNull);

    await tester.tap(find.text('Chloé Bernard'));
    await tester.tap(find.text('Denis'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Customer'));
    await tester.pump();
    expect(find.text('2 selected'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('Import 2 people'));
    await tester.pumpAndSettle();

    expect(people.calls.last, 'addAll(Chloé Bernard, Denis)');
    final added = people.store.values.where((person) => person.id != 'p1');
    expect(added.map((person) => person.stage), everyElement(Stage.customer));
    expect(added.map((person) => person.email), contains('denis@example.com'));
    expect(find.byType(ContactList), findsOneWidget);
    expect(find.text('2 people imported'), findsOneWidget);
  });

  testWidgets('search narrows the list and keeps what is ticked', (
    tester,
  ) async {
    await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Chloé Bernard', phone: null, email: null),
        (name: 'Denis', phone: null, email: null),
      ]),
    );

    await tester.tap(find.text('Denis'));
    await tester.enterText(find.byType(TextField), 'chloe');
    await tester.pump();

    expect(find.text('Denis'), findsNothing);
    expect(find.text('Chloé Bernard'), findsOneWidget);
    expect(find.text('Import one person'), findsOneWidget);
  });

  testWidgets('refused access points to the settings', (tester) async {
    final phone = FakePhoneContactsRepository()..contacts = null;
    await _openImport(tester, phone);

    await tester.tap(find.text('Open settings'));

    expect(phone.settingsOpened, 1);
  });

  testWidgets('an empty address book says so', (tester) async {
    await _openImport(tester, FakePhoneContactsRepository());

    expect(find.text('No contacts on this phone'), findsOneWidget);
  });

  testWidgets('a failed read offers Try again', (tester) async {
    final phone = FakePhoneContactsRepository([
      (name: 'Denis', phone: null, email: null),
    ])..failWith = Exception('boom');
    await _openImport(tester, phone);
    expect(find.text("Couldn't read your contacts"), findsOneWidget);

    phone.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Denis'), findsOneWidget);
  });
}
