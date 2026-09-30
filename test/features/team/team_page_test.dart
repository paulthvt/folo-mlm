import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contact_page.dart';
import 'package:loomia/features/team/presentation/team_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_harness.dart';
import '../contacts/fake_people_repository.dart';

final _today = DateTime(2026, 9, 30);

Person _person(String id, String name, Stage stage, DateTime since) =>
    Person(id: id, name: name, stage: stage, stageSince: since);

Future<void> _pump(
  WidgetTester tester,
  AsyncValue<List<Person>> people, {
  void Function(Person)? onOpen,
  VoidCallback? onRetry,
}) async {
  tester.view
    ..physicalSize = const Size(390, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: localizationsDelegates,
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TeamView(
        people: people,
        today: _today,
        onOpen: onOpen ?? (_) {},
        onRetry: onRetry ?? () {},
        onRefresh: () async {},
      ),
    ),
  );
}

void main() {
  group('joinedLabel', () {
    late AppLocalizations l10n;
    setUpAll(() async {
      await initializeDateFormatting('en');
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    test('counts local calendar days, then weeks, then the month', () {
      expect(
        joinedLabel(l10n, DateTime(2026, 9, 30, 8), _today),
        'Team · joined today',
      );
      expect(
        joinedLabel(l10n, DateTime(2026, 9, 29, 23), _today),
        'Team · joined yesterday',
      );
      expect(
        joinedLabel(l10n, DateTime(2026, 9, 24), _today),
        'Team · joined 6 days ago',
      );
      expect(
        joinedLabel(l10n, DateTime(2026, 9, 23), _today),
        'Team · joined a week ago',
      );
      expect(
        joinedLabel(l10n, DateTime(2026, 9, 9), _today),
        'Team · joined 3 weeks ago',
      );
      expect(
        joinedLabel(l10n, DateTime(2026, 8, 5), _today),
        'Team · joined 8 weeks ago',
      );
      expect(
        joinedLabel(l10n, DateTime(2026, 3, 4), _today),
        'Team · joined in March 2026',
      );
    });

    test('a UTC timestamp is read on the local calendar', () {
      final lateYesterday = DateTime(2026, 9, 29, 23, 30).toUtc();
      expect(
        joinedLabel(l10n, lateYesterday, _today),
        'Team · joined yesterday',
      );
    });
  });

  testWidgets('only team members, with the summary and the rule', (
    tester,
  ) async {
    await _pump(
      tester,
      AsyncData([
        _person('p1', 'Bruno Keller', Stage.team, DateTime(2026, 9, 9)),
        _person('p2', 'Claire Dubois', Stage.customer, DateTime(2026, 9, 9)),
        _person('p3', 'Léa Fontaine', Stage.team, DateTime(2026, 3, 4)),
      ]),
    );

    expect(find.text('2 people on your team'), findsOneWidget);
    expect(
      find.text(
        'Nobody is being measured here — this is just who might need you.',
      ),
      findsOneWidget,
    );
    expect(find.text('EVERYONE'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Bruno Keller'), findsOneWidget);
    expect(find.text('Team · joined 3 weeks ago'), findsOneWidget);
    expect(find.text('Léa Fontaine'), findsOneWidget);
    expect(find.text('Claire Dubois'), findsNothing);
  });

  testWidgets('one member reads as a sentence', (tester) async {
    await _pump(
      tester,
      AsyncData([
        _person('p1', 'Bruno Keller', Stage.team, DateTime(2026, 9, 9)),
      ]),
    );

    expect(find.text('One person on your team'), findsOneWidget);
  });

  testWidgets('the avatars add no second count for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      AsyncData([
        _person('p1', 'Bruno Keller', Stage.team, DateTime(2026, 9, 9)),
      ]),
    );

    expect(find.bySemanticsLabel(RegExp('1 people')), findsNothing);
    semantics.dispose();
  });

  testWidgets('tapping a row opens the person', (tester) async {
    Person? opened;
    await _pump(
      tester,
      AsyncData([
        _person('p1', 'Bruno Keller', Stage.team, DateTime(2026, 9, 9)),
      ]),
      onOpen: (person) => opened = person,
    );

    await tester.tap(find.text('Bruno Keller'));
    expect(opened?.id, 'p1');
  });

  testWidgets('no team member: the empty state, no summary', (tester) async {
    await _pump(
      tester,
      AsyncData([
        _person('p2', 'Claire Dubois', Stage.customer, DateTime(2026, 9, 9)),
      ]),
    );

    expect(find.text('No one on your team yet'), findsOneWidget);
    expect(find.text('Move someone to Team from their page.'), findsOneWidget);
    expect(find.text('EVERYONE'), findsNothing);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    var retried = false;
    await _pump(
      tester,
      AsyncError(Exception('offline'), StackTrace.empty),
      onRetry: () => retried = true,
    );

    expect(find.text("Couldn't load your team."), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('loading shows a spinner', (tester) async {
    await _pump(tester, const AsyncLoading());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('in the app: a team member opens their contact page', (
    tester,
  ) async {
    await pumpLoomia(
      tester,
      size: const Size(390, 844),
      people: FakePeopleRepository([
        _person('p1', 'Bruno Keller', Stage.team, DateTime.utc(2026, 9, 9)),
      ]),
    );
    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bruno Keller'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactPage), findsOneWidget);
  });
}
