import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/core/ui/contact_row.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/contact_list.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:folo/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

Person _person(String id, String name, Stage stage, {String? profession}) =>
    Person(
      id: id,
      name: name,
      stage: stage,
      profession: profession,
      stageSince: DateTime.utc(2026, 3, 4),
    );

final _book = [
  _person('1', 'Anne Martin', Stage.prospect, profession: 'Nurse'),
  _person('2', 'Bruno Leroy', Stage.customer),
  _person('3', 'Hélène Petit', Stage.team),
];

Future<void> _pump(
  WidgetTester tester, {
  List<Person>? people,
  ValueChanged<Person>? onOpen,
  VoidCallback? onAdd,
  Future<void> Function()? onRefresh,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: ContactList(
          people: people ?? _book,
          onOpen: onOpen ?? (_) {},
          onAdd: onAdd ?? () {},
          onRefresh: onRefresh ?? () async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists everyone with their stage and a subtitle', (tester) async {
    await _pump(tester);

    expect(find.byType(ContactRow), findsNWidgets(3));
    expect(find.text('Nurse'), findsOneWidget);
    // The filter chip "Team" and Hélène's stage chip.
    expect(find.text('Team'), findsNWidgets(2));
  });

  testWidgets('a stage chip filters the list', (tester) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Customers'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactRow), findsOneWidget);
    expect(find.text('Bruno Leroy'), findsOneWidget);
  });

  testWidgets('search ignores accents and case', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'HELENE');
    await tester.pumpAndSettle();

    expect(find.byType(ContactRow), findsOneWidget);
    expect(find.text('Hélène Petit'), findsOneWidget);
  });

  testWidgets('nothing matching says so in one line', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.byType(ContactRow), findsNothing);
    expect(find.text('Nobody matches.'), findsOneWidget);
  });

  testWidgets('an empty book offers to add someone', (tester) async {
    var adds = 0;
    await _pump(tester, people: const [], onAdd: () => adds++);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add someone'));
    expect(adds, 1);
  });

  testWidgets('tapping a row opens that person', (tester) async {
    Person? opened;
    await _pump(tester, onOpen: (person) => opened = person);

    await tester.tap(find.text('Bruno Leroy'));

    expect(opened?.id, '2');
  });

  testWidgets('pulling down refreshes', (tester) async {
    var refreshes = 0;
    await _pump(tester, onRefresh: () async => refreshes++);

    await tester.fling(find.text('Anne Martin'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(refreshes, 1);
  });
}
