import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/workflows/domain/progress.dart';

/// Why someone on the team is worth a check-in. Never a score: a reason.
enum CheckInReason { isNew, quiet }

typedef CheckIn = ({
  Person person,
  CheckInReason reason,

  /// The day the reason counts from.
  DateTime since,

  /// Days from [since] to today.
  int days,
});

/// The day they joined the team, on the device's calendar.
DateTime joinedOn(Person person) {
  final local = person.stageSince.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Something is logged with them on or after the day they joined.
bool talkedSinceJoining(Person person) {
  final last = person.lastContactOn;
  return last != null && !last.isBefore(joinedOn(person));
}

/// Who on [team] could use a check-in on [today] (local midnight): new and
/// not talked to yet, or quiet for two weeks. One row each, oldest first.
List<CheckIn> checkIns(List<Person> team, DateTime today) {
  final rows = <CheckIn>[];
  for (final person in team) {
    final joined = joinedOn(person);
    final sinceJoining = daysBetween(joined, today);
    if (sinceJoining < 30 && !talkedSinceJoining(person)) {
      rows.add((
        person: person,
        reason: CheckInReason.isNew,
        since: joined,
        days: sinceJoining,
      ));
      continue;
    }
    final last = person.lastContactOn ?? joined;
    final quiet = daysBetween(last, today);
    if (quiet >= 14) {
      rows.add((
        person: person,
        reason: CheckInReason.quiet,
        since: last,
        days: quiet,
      ));
    }
  }
  return rows..sort((a, b) {
    final bySince = a.since.compareTo(b.since);
    return bySince != 0
        ? bySince
        : searchKey(a.person.name).compareTo(searchKey(b.person.name));
  });
}
