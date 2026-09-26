import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/core/ui/action_item.dart';
import 'package:folo/core/ui/activity_item.dart';
import 'package:folo/core/ui/goal_card.dart';
import 'package:folo/features/today/domain/today_snapshot.dart';
import 'package:folo/features/today/presentation/today_page.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:folo/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

const _mobile = Size(390, 844);
const _desktop = Size(1440, 900);

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  TodaySnapshot? snapshot,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: TodayView(snapshot: snapshot),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile shows the greeting, the hero sentence and the reasons', (
    tester,
  ) async {
    await _pump(tester, size: _mobile, snapshot: sampleToday);

    expect(find.text('Good morning, Pauline'), findsOneWidget);
    expect(find.text('MONDAY 22 SEPTEMBER'), findsOneWidget);
    expect(find.text('Three people are worth a message today'), findsOneWidget);
    // The reason is what makes an item an offer instead of a demand.
    expect(find.text('Turns 42 tomorrow'), findsOneWidget);
    // Accent chips only where a real date drives the item.
    expect(find.text('Birthday tomorrow'), findsOneWidget);
  });

  testWidgets('mobile keeps the goal below the fold', (tester) async {
    await _pump(tester, size: _mobile, snapshot: sampleToday);

    // The right column exists on desktop only.
    expect(find.byType(ActivityItem), findsNothing);
    // Context, not the job: the goal is not in the first viewport.
    expect(find.byType(GoalCard), findsNothing);

    await tester.scrollUntilVisible(find.byType(GoalCard), 200);
    expect(find.byType(GoalCard), findsOneWidget);
    expect(
      tester.getSize(find.byType(GoalCard)).width,
      tester.getSize(find.byType(ActionItem).first).width,
    );
  });

  testWidgets('desktop puts context in a second column', (tester) async {
    await _pump(tester, size: _desktop, snapshot: sampleToday);

    expect(find.byType(ActivityItem), findsNWidgets(sampleToday.recent.length));

    final actions = tester.getTopLeft(find.text('Marie Dupont'));
    final goal = tester.getTopLeft(find.byType(GoalCard));
    expect(goal.dx, greaterThan(actions.dx));
    // 400px context column, right-aligned inside the max content width.
    expect(tester.getSize(find.byType(GoalCard)).width, 400);
  });

  testWidgets('nothing waiting reads as up to date, not as no data', (
    tester,
  ) async {
    await _pump(tester, size: _mobile);

    expect(find.text('You are up to date'), findsOneWidget);
    expect(find.byType(GoalCard), findsNothing);
  });

  test('the provider serves the sample snapshot until a repository exists', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(todaySnapshotProvider), sampleToday);
  });
}
