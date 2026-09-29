import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoDatePicker;
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/contacts/domain/activity.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/log_activity_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_activity_repository.dart';
import '../fake_people_repository.dart';
import 'form_harness.dart';

final _claire = Person(
  id: 'p1',
  name: 'Claire Petit',
  stage: Stage.customer,
  stageSince: DateTime.utc(2026, 3, 4),
);

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

void main() {
  late FakeActivityRepository activities;

  setUp(() => activities = FakeActivityRepository());

  Future<void> open(WidgetTester tester) => pumpFormHarness(
    tester,
    people: FakePeopleRepository([_claire]),
    activities: activities,
    open: (context) => showLogActivity(context, _claire),
    result: (_) {},
  );

  testWidgets('titled with the first name, Note and today preset', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Log something with Claire'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Note'))
          .selected,
      isTrue,
    );
    expect(find.textContaining('Today, '), findsOneWidget);
  });

  testWidgets(
    'on a phone with the keyboard up: no overflow, buttons in a row',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844)
        // Roughly a phone keyboard with its suggestion bar.
        ..viewInsets = const FakeViewPadding(bottom: 430);
      addTearDown(tester.view.reset);
      await open(tester);

      expect(tester.takeException(), isNull);
      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
      final save = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
      expect(cancel.center.dy, save.center.dy);
      expect(cancel.right, lessThan(save.left));
      expect(save.bottom, lessThanOrEqualTo(844 - 430));
    },
  );

  testWidgets('nothing written, or only spaces, is refused', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Say what happened.'), findsOneWidget);
    expect(activities.calls, isNot(contains('add(p1)')));
  });

  testWidgets('saves the kind, the day and the text, then closes', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Call'));
    await tester.enterText(find.byType(TextFormField), 'Asked about the cream');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = activities.store.single;
    expect(saved.kind, ActivityKind.call);
    expect(saved.happenedOn, _today());
    expect(saved.text, 'Asked about the cream');
    expect(find.text('Log something with Claire'), findsNothing);
  });

  testWidgets('a failed save says so and keeps what was typed', (tester) async {
    await open(tester);
    activities.failWith = PeopleFailure.network;

    await tester.enterText(find.byType(TextFormField), 'Asked about the cream');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('Asked about the cream'), findsOneWidget);
    expect(find.text('Log something with Claire'), findsOneWidget);
  });

  testWidgets('the calendar ends today; a picked day is saved', (tester) async {
    await open(tester);

    await tester.tap(find.textContaining('Today, '));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).lastDate,
      _today(),
    );
    await tester.tap(find.text('1'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Met at the market');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final today = _today();
    expect(
      activities.store.single.happenedOn,
      DateTime(today.year, today.month, 1),
    );
  });

  testWidgets('iOS: a wheel that cannot go past today', (tester) async {
    await open(tester);

    await tester.tap(find.textContaining('Today, '));
    await tester.pumpAndSettle();
    final wheel = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(wheel.maximumDate, _today());
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsNothing);
    expect(find.textContaining('Today, '), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Step is never offered: the app writes those', (tester) async {
    await open(tester);

    expect(find.widgetWithText(ChoiceChip, 'Step'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Note'), findsOneWidget);
  });
}
