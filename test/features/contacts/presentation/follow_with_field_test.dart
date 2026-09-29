import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/follow_with_field.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:folo/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../workflows/fake_workflow_repository.dart';

void main() {
  final prospects = forStage(FakeWorkflowRepository.samples(), Stage.prospect);
  final samples = prospects.first;

  /// The block as a sheet holds it: the value lives above it.
  Future<ValueNotifier<FollowWith?>> pump(
    WidgetTester tester, {
    FollowWith? initial,
  }) async {
    final value = ValueNotifier<FollowWith?>(initial);
    addTearDown(value.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: value,
            builder: (_, current, _) => FollowWithField(
              workflows: prospects,
              value: current,
              today: today(),
              onChanged: (next) => value.value = next,
            ),
          ),
        ),
      ),
    );
    return value;
  }

  testWidgets('lists the stage\'s workflows, the default suggested', (
    tester,
  ) async {
    await pump(tester, initial: (workflow: samples, firstDue: today()));

    expect(find.text('Suggested · 5 steps'), findsOneWidget);
    expect(find.text('4 steps'), findsOneWidget);
    expect(find.text('Nothing for now'), findsOneWidget);
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'samples',
    );
    // The date field is labelled with the first step.
    expect(find.text('Send a first message'), findsOneWidget);
  });

  testWidgets('another workflow starts due its own first step', (tester) async {
    final value = await pump(
      tester,
      initial: (workflow: samples, firstDue: today()),
    );

    await tester.tap(find.text('Health professionals'));
    await tester.pump();

    expect(value.value?.workflow.id, 'health');
    expect(value.value?.firstDue, today());
    expect(find.text('Introduce yourself'), findsOneWidget);
  });

  testWidgets('Nothing for now hides the date', (tester) async {
    final value = await pump(
      tester,
      initial: (workflow: samples, firstDue: today()),
    );

    await tester.tap(find.text('Nothing for now'));
    await tester.pump();

    expect(value.value, isNull);
    expect(find.text('Send a first message'), findsNothing);
  });

  testWidgets('the first step can\'t be put in the past', (tester) async {
    await pump(tester, initial: (workflow: samples, firstDue: today()));

    await tester.tap(find.text('Send a first message'));
    await tester.pumpAndSettle();

    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.firstDate, today());
  });

  testWidgets('a picked day becomes the first due day', (tester) async {
    final value = await pump(
      tester,
      initial: (workflow: samples, firstDue: today()),
    );
    final later = addDays(today(), 1);

    await tester.tap(find.text('Send a first message'));
    await tester.pumpAndSettle();
    // Past the end of the month the day is on the next page: go there first.
    if (later.month != today().month) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('${later.day}'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(value.value?.firstDue, later);
    expect(value.value?.workflow.id, 'samples');
  });
}
