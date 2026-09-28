import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/contact_details.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:folo/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

Person _person({
  Stage stage = Stage.prospect,
  ProspectStatus? status,
  String? phone,
  String? email,
  String? instagram,
  String? needs,
}) => Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: stage,
  stageSince: DateTime.utc(2026, 3, 4),
  prospectStatus: status,
  phone: phone,
  email: email,
  instagram: instagram,
  needs: needs,
);

class _Calls {
  final statuses = <ProspectStatus?>[];
  final launched = <Uri>[];
  var edits = 0;
  var deletes = 0;
}

Future<_Calls> _pump(WidgetTester tester, Person person) async {
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: ContactDetails(
          person: person,
          onStatus: calls.statuses.add,
          onEdit: () => calls.edits++,
          onDelete: () => calls.deletes++,
          onLaunch: calls.launched.add,
          onRefresh: () async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('the header says the stage and since when', (tester) async {
    await _pump(tester, _person());

    expect(find.text('Marie Dupont'), findsOneWidget);
    expect(find.text('Prospect since March 2026'), findsOneWidget);
  });

  testWidgets('a status chip saves it; tapping it again clears it', (
    tester,
  ) async {
    final calls = await _pump(
      tester,
      _person(status: ProspectStatus.interested),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Thinking about it'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Interested'));

    expect(calls.statuses, [ProspectStatus.thinking, null]);
  });

  testWidgets('customers have no status chips', (tester) async {
    await _pump(tester, _person(stage: Stage.customer));

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('WHERE IT STANDS'), findsNothing);
  });

  testWidgets('no channel, no Message or Call', (tester) async {
    await _pump(tester, _person());

    expect(find.text('Message'), findsNothing);
    expect(find.text('Call'), findsNothing);
  });

  testWidgets('a phone gives Call and Message by text', (tester) async {
    final calls = await _pump(tester, _person(phone: '06 12 34 56 78'));

    await tester.tap(find.text('Call'));
    await tester.tap(find.text('Message'));

    expect(calls.launched, [
      Uri(scheme: 'tel', path: '0612345678'),
      Uri(scheme: 'sms', path: '0612345678'),
    ]);
  });

  testWidgets('Instagram only gives Message on Instagram', (tester) async {
    final calls = await _pump(tester, _person(instagram: 'marie.d'));

    expect(find.text('Call'), findsNothing);
    await tester.tap(find.text('Message'));

    expect(calls.launched, [Uri.https('instagram.com', '/marie.d')]);
  });

  testWidgets('a typed @ is stripped from the Instagram link', (tester) async {
    final calls = await _pump(tester, _person(instagram: '@marie.d'));

    await tester.tap(find.text('Message'));

    expect(calls.launched, [Uri.https('instagram.com', '/marie.d')]);
  });

  testWidgets('an email opens the mail app', (tester) async {
    final calls = await _pump(tester, _person(email: 'marie@example.com'));

    await tester.tap(find.text('marie@example.com'));

    expect(calls.launched, [Uri(scheme: 'mailto', path: 'marie@example.com')]);
  });

  testWidgets('filled facts only, or "Nothing yet"', (tester) async {
    await _pump(tester, _person());
    expect(find.text('Nothing yet.'), findsOneWidget);

    await _pump(tester, _person(needs: 'Sleep, stress'));
    expect(find.text('Nothing yet.'), findsNothing);
    expect(find.text('Needs'), findsOneWidget);
    expect(find.text('Sleep, stress'), findsOneWidget);
    expect(find.text('Phone'), findsNothing);
  });

  testWidgets('Edit in the section header and in ⋯ both edit', (tester) async {
    final calls = await _pump(tester, _person());

    await tester.tap(find.text('Edit'));
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();

    expect(calls.edits, 2);
  });

  testWidgets('Delete asks first; Cancel keeps the person', (tester) async {
    final calls = await _pump(tester, _person());

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Marie Dupont?'), findsOneWidget);
    expect(find.text('Their details are removed for good.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls.deletes, 0);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(calls.deletes, 1);
  });
}
