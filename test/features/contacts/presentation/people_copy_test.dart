import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/contacts/domain/activity.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late AppLocalizations l10n;
  final today = DateTime(2026, 9, 28);

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('fr');
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  Activity entry({ActivityKind kind = ActivityKind.call, Stage? stage}) =>
      Activity(
        id: 'a1',
        personId: 'p1',
        kind: kind,
        happenedOn: DateTime(2026, 10, 13),
        text: stage == null ? 'Asked about the cream' : null,
        stage: stage,
        createdAt: DateTime(2026, 10, 13, 12),
      );

  test('the first name, whatever the spacing', () {
    Person named(String name) => Person(
      id: 'p1',
      name: name,
      stage: Stage.prospect,
      stageSince: DateTime.utc(2026),
    );
    expect(firstName(named('Sarah Martin')), 'Sarah');
    expect(firstName(named('  Claire ')), 'Claire');
  });

  test('a day drops the year only in the current year', () {
    expect(dayLabel(l10n, DateTime(2026, 10, 13), today), 'October 13');
    expect(dayLabel(l10n, DateTime(2024, 10, 13), today), 'October 13, 2024');
  });

  test('a day is written the way the locale writes it', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(dayLabel(fr, DateTime(2026, 10, 13), today), '13 octobre');
    expect(dayLabel(fr, DateTime(2024, 10, 13), today), '13 octobre 2024');
  });

  test('an entry reads its text, then day · kind', () {
    expect(activityTitle(l10n, entry()), 'Asked about the cream');
    expect(activityMeta(l10n, entry(), today), 'October 13 · Call');
  });

  test('a stage entry says what changed, with the day alone', () {
    final moved = entry(kind: ActivityKind.stage, stage: Stage.customer);
    expect(activityTitle(l10n, moved), 'Became a customer');
    expect(activityMeta(l10n, moved, today), 'October 13');
    expect(
      activityTitle(l10n, entry(kind: ActivityKind.stage, stage: Stage.team)),
      'Joined your team',
    );
    expect(
      activityTitle(
        l10n,
        entry(kind: ActivityKind.stage, stage: Stage.prospect),
      ),
      'Back to prospects',
    );
  });

  test('stage moves and their titles', () {
    expect(moveToLabel(l10n, Stage.customer), 'Move to customers');
    expect(
      movedTitle(l10n, 'Sarah', Stage.customer),
      'Sarah is now a customer',
    );
    expect(movedTitle(l10n, 'Sarah', Stage.team), 'Sarah is now on your team');
    expect(
      movedTitle(l10n, 'Sarah', Stage.prospect),
      'Sarah is a prospect again',
    );
  });

  test('every kind but stage has a label', () {
    for (final kind in ActivityKind.values) {
      expect(kindLabel(l10n, kind) == null, kind == ActivityKind.stage);
    }
  });

  test('the due line counts days from today', () {
    String due(int days) =>
        dueLabel(l10n, today.add(Duration(days: days)), today);
    expect(due(0), 'Due today');
    expect(due(1), 'Due tomorrow');
    expect(due(3), 'Due in 3 days');
    expect(due(6), 'Due in 6 days');
    expect(due(7), 'Due October 5');
    expect(due(-1), '1 day late');
    expect(due(-3), '3 days late');
  });

  test('the due line ignores the hour change', () {
    // Paris leaves summer time on October 25, 2026.
    expect(
      dueLabel(l10n, DateTime(2026, 10, 26), DateTime(2026, 10, 24)),
      'Due in 2 days',
    );
  });

  test('a paused person says since when, Not now first if it is', () {
    Person paused({ProspectStatus? status, Stage stage = Stage.prospect}) =>
        Person(
          id: 'p1',
          name: 'Sarah',
          stage: stage,
          prospectStatus: status,
          stageSince: DateTime.utc(2026),
          profession: 'Nurse',
          pausedAt: DateTime(2026, 7, 12, 9),
        );
    expect(
      contactSubtitle(l10n, paused(status: ProspectStatus.notNow)),
      'Not now · paused in July',
    );
    expect(contactSubtitle(l10n, paused()), 'Paused in July');
    expect(
      contactSubtitle(l10n, paused(stage: Stage.customer)),
      'Paused in July',
    );
  });

  test('not paused: what they do, else what they need', () {
    final nurse = Person(
      id: 'p1',
      name: 'Sarah',
      stage: Stage.prospect,
      stageSince: DateTime.utc(2026),
      profession: 'Nurse',
      needs: 'Sleep',
    );
    expect(contactSubtitle(l10n, nurse), 'Nurse');
  });

  test('a step entry reads its label, then day · Step', () {
    final step = Activity(
      id: 'a1',
      personId: 'p1',
      kind: ActivityKind.step,
      happenedOn: DateTime(2026, 10, 13),
      text: 'Send the samples',
      createdAt: DateTime(2026, 10, 13, 12),
    );
    expect(activityTitle(l10n, step), 'Send the samples');
    expect(activityMeta(l10n, step, today), 'October 13 · Step');
  });
}
