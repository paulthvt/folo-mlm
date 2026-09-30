import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/team/domain/check_in.dart';

final _today = DateTime(2026, 9, 30);

Person _member(String name, DateTime joined, [DateTime? talked]) => Person(
  id: name,
  name: name,
  stage: Stage.team,
  stageSince: joined,
  lastContactOn: talked,
);

void main() {
  test('new: joined under 30 days ago, nothing logged since', () {
    final [row] = checkIns([_member('Ana', DateTime(2026, 9, 9))], _today);

    expect(row.reason, CheckInReason.isNew);
    expect(row.since, DateTime(2026, 9, 9));
    expect(row.days, 21);
  });

  test('new: a contact before joining does not count', () {
    final [row] = checkIns([
      _member('Ana', DateTime(2026, 9, 20), DateTime(2026, 9, 1)),
    ], _today);

    expect(row.reason, CheckInReason.isNew);
  });

  test('not new at 30 days: quiet from the joining day instead', () {
    final [row] = checkIns([_member('Ana', DateTime(2026, 8, 31))], _today);

    expect(row.reason, CheckInReason.quiet);
    expect(row.days, 30);
  });

  test('quiet from 14 days, not 13', () {
    final long = DateTime(2026, 1, 1);

    expect(
      checkIns([_member('A', long, DateTime(2026, 9, 17))], _today),
      isEmpty,
    );
    final [row] = checkIns([_member('A', long, DateTime(2026, 9, 16))], _today);
    expect(
      (row.reason, row.days, row.since),
      (CheckInReason.quiet, 14, DateTime(2026, 9, 16)),
    );
  });

  test('new wins over quiet: one row', () {
    final [row] = checkIns([_member('A', DateTime(2026, 9, 10))], _today);

    expect(row.reason, CheckInReason.isNew);
  });

  test('neither: talked since joining, lately', () {
    expect(
      checkIns([
        _member('A', DateTime(2026, 9, 20), DateTime(2026, 9, 30)),
      ], _today),
      isEmpty,
    );
  });

  test('the joining day is the local calendar day', () {
    final lateEvening = DateTime(2026, 9, 29, 23, 30).toUtc();

    expect(joinedOn(_member('A', lateEvening)), DateTime(2026, 9, 29));
    expect(
      talkedSinceJoining(_member('A', lateEvening, DateTime(2026, 9, 29))),
      isTrue,
    );
  });

  test('oldest first, then by name', () {
    final rows = checkIns([
      _member('Zoé', DateTime(2026, 9, 20)),
      _member('Émile', DateTime(2026, 9, 20)),
      _member('Bruno', DateTime(2026, 1, 1), DateTime(2026, 8, 1)),
    ], _today);

    expect(
      [for (final row in rows) row.person.name],
      ['Bruno', 'Émile', 'Zoé'],
    );
  });
}
