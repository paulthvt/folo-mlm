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
}
