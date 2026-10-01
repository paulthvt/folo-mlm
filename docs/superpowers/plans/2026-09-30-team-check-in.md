# Team — worth a check-in Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** #103 — the Team tab says when you last talked to each member, lists who could use a check-in (New / Quiet), and opens the Log sheet from there.

**Architecture:** Postgres computed field `last_contact_on(person)` read like `due_on`; `Person.lastContactOn`; a pure `checkIns()` in `lib/features/team/domain/check_in.dart`; `TeamView` renders it. Logging or deleting an activity invalidates the book so the row drops out everywhere.

**Tech Stack:** Flutter, flutter_riverpod, gen-l10n, Supabase (Postgres + pgTAP).

**Spec:** `docs/superpowers/specs/2026-09-30-team-tab-design.md` (section "Check-in rules (#103)", "Screen" items 2–4).

## Global Constraints

- Schema change only via `supabase migration new team_last_contact`; function `language sql stable security invoker set search_path = ''`, revoke from `public, anon`, grant to `authenticated`.
- `last_contact_on` = latest `happened_on` of an activity whose kind is not `stage`.
- New: on the team < 30 days and nothing logged since joining. Quiet: last contact (or joining day when nothing is logged) ≥ 14 days ago. New wins. Oldest day first, then `searchKey(name)`.
- Copy only in `lib/l10n/app_en.arb`, each key with a description. No ranking, no "recruit", no comparison between members.
- No hard-coded colours/spacing/sizes; `package:loomia/...` imports; `material_ui`.
- Goldens regenerated through CI only.
- Quality gate: `dart format .`, `flutter analyze` (No issues found!), `flutter test`, `supabase test db`.

## Review Focus

1. Someone talked to while a prospect, then moved to Team: the roster must say "joined …", and they are New (the old contact is before joining). Pinned in Task 3 and Task 4.
2. `stageSince` is a UTC timestamp; joining at 23:30 local the day before must count on the local calendar. Pinned in Task 3 (`toLocal`).
3. A logged activity dated in the future cannot happen (the sheet's `last` is today), but a `last_contact_on` equal to today must give "talked today" and no Quiet. Pinned in Task 3/4.
4. Deleting the only entry since joining brings the person back into WORTH A CHECK-IN. Pinned in Task 2 (remove invalidates).
5. Only `stage` rows ignored: a `step` row (ticked workflow step) counts as contact. Pinned in Task 1.

---

### Task 1: `last_contact_on` in Postgres

**Files:**
- Create: `supabase/migrations/<timestamp>_team_last_contact.sql` (via `supabase migration new team_last_contact`)
- Create: `supabase/tests/last_contact_test.sql`

**Interfaces:**
- Produces: `public.last_contact_on(p public.person) returns date`, selectable as column `last_contact_on`.

- [ ] **Step 1: Write the failing pgTAP test** `supabase/tests/last_contact_test.sql`:

```sql
-- When the user last talked with someone: every activity but a stage
-- change, which the database writes itself. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Talked', 'team'),
  ('00000000-0000-0000-0000-0000000000a2', 'Only moved', 'team'),
  ('00000000-0000-0000-0000-0000000000a3', 'Ticked', 'prospect');

insert into public.activity (person_id, kind, text, happened_on) values
  ('00000000-0000-0000-0000-0000000000a1', 'call', 'Catch-up', '2026-09-12'),
  ('00000000-0000-0000-0000-0000000000a1', 'note', 'Older', '2026-09-01'),
  ('00000000-0000-0000-0000-0000000000a3', 'step', 'Send a first message', '2026-09-20');
insert into public.activity (person_id, kind, stage, happened_on) values
  ('00000000-0000-0000-0000-0000000000a1', 'stage', 'team', '2026-09-28'),
  ('00000000-0000-0000-0000-0000000000a2', 'stage', 'team', '2026-09-28');

select is(
  (select last_contact_on(p) from public.person p
   where p.id = '00000000-0000-0000-0000-0000000000a1'),
  '2026-09-12'::date, 'the latest entry, not the stage change');
select is(
  (select last_contact_on(p) from public.person p
   where p.id = '00000000-0000-0000-0000-0000000000a2'),
  null::date, 'a stage change alone is no contact');
select is(
  (select last_contact_on(p) from public.person p
   where p.id = '00000000-0000-0000-0000-0000000000a3'),
  '2026-09-20'::date, 'a ticked step counts');
select is(
  (select last_contact_on(p) from public.person p
   where p.id = '00000000-0000-0000-0000-0000000000a1'),
  (select max(happened_on) from public.activity
   where person_id = '00000000-0000-0000-0000-0000000000a1' and kind <> 'stage'),
  'read through RLS as the owner');

select * from finish();
rollback;
```

Check the `activity` column list against `supabase/migrations/*activity*.sql` before running (stage rows may need `text` null / `stage` set; adapt the insert to the table's check constraint, nothing else).

- [ ] **Step 2: Run it, expect failure**

Run: `supabase db reset && supabase test db`
Expected: `last_contact_test.sql` fails with `function last_contact_on(person) does not exist`.

- [ ] **Step 3: Write the migration**

`supabase migration new team_last_contact`, then:

```sql
-- Team check-ins (#103): when the user last talked with someone. A computed
-- field every reader selects, like due_on; never written. A stage change is
-- the database talking, not the user, so it does not count.
create function public.last_contact_on(p public.person) returns date
language sql stable security invoker set search_path = '' as $$
  select max(a.happened_on) from public.activity a
  where a.person_id = p.id and a.kind <> 'stage'
$$;

revoke execute on function public.last_contact_on(public.person) from public, anon;
grant execute on function public.last_contact_on(public.person) to authenticated;
```

- [ ] **Step 4: Run tests and lint**

Run: `supabase db reset && supabase db lint --fail-on error && supabase test db`
Expected: all files pass, lint clean.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_team_last_contact.sql supabase/tests/last_contact_test.sql
git commit -m "feat(team): last_contact_on computed field"
```

### Task 2: `Person.lastContactOn`, read and kept fresh

**Files:**
- Modify: `lib/features/contacts/domain/person.dart` (field, constructor, `withStatus`)
- Modify: `lib/features/contacts/data/people_repository.dart` (`_columns`, `personFromRow`)
- Modify: `lib/features/contacts/presentation/history_controller.dart` (`add`, `remove` invalidate the book)
- Modify: `test/features/workflows/server_rule.dart` (pass `lastContactOn` through)
- Modify: `test/features/contacts/fake_people_repository.dart` (`_served` computes it from `activities` when set)
- Test: `test/features/contacts/data/people_repository_test.dart` (or wherever `personFromRow` is tested — `grep -rn personFromRow test`), `test/features/contacts/presentation/history_controller_test.dart`

**Interfaces:**
- Produces: `DateTime? Person.lastContactOn` — local midnight of the day, null when nothing is logged.

- [ ] **Step 1: Failing tests**

personFromRow test (add to the existing group, reusing its row fixture):

```dart
test('reads last_contact_on as a local day', () {
  final person = personFromRow({...row, 'last_contact_on': '2026-09-12'});
  expect(person.lastContactOn, DateTime(2026, 9, 12));
  expect(personFromRow(row).lastContactOn, isNull);
});
```

History controller test: after `add`, the book is re-read.

```dart
test('logging reloads the book, so last contact follows', () async {
  // container with FakePeopleRepository people + FakeActivityRepository
  // activities wired as `people.activities = activities`, signed-in account
  // like the other tests in this file.
  await container.read(peopleProvider(owner).future);
  people.calls.clear();
  await container.read(historyProvider('p1').notifier).add((
    kind: ActivityKind.call, happenedOn: DateTime(2026, 9, 29), text: 'Hi',
  ));
  final book = await container.read(peopleProvider(owner).future);
  expect(people.calls, ['list()']);
  expect(book.single.lastContactOn, DateTime(2026, 9, 29));
});
```

Plus the same for `remove` (reload, `lastContactOn` back to null).

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/features/contacts`
Expected: compile error `lastContactOn` not defined.

- [ ] **Step 3: Implement**

`person.dart`: constructor `this.lastContactOn,`; field

```dart
  /// The server's answer (`last_contact_on`): the latest day anything was
  /// logged with them, stage changes aside. Local midnight. Read-only.
  final DateTime? lastContactOn;
```

and `lastContactOn: lastContactOn,` in `withStatus`.

`people_repository.dart`: `_columns = '*, current_step_id, due_on, last_contact_on'`; in `personFromRow`:

```dart
    lastContactOn: switch (row['last_contact_on']) {
      // A bare date parses as local midnight, like due_on.
      final String day => DateTime.parse(day),
      _ => null,
    },
```

`server_rule.dart`: `lastContactOn: person.lastContactOn,`.

`fake_people_repository.dart` `_served`:

```dart
  Person _served(Person person) {
    final served = withServerFields(person, workflows);
    final history = activities;
    if (history == null) return served;
    // As last_contact_on: the latest entry that is not a stage change.
    final days = [
      for (final a in history.store)
        if (a.personId == person.id && a.kind != ActivityKind.stage) a.day,
    ]..sort();
    return withLastContact(served, days.lastOrNull);
  }
```

— add `withLastContact(Person, DateTime?)` to `server_rule.dart` as a copy with that one field replaced (the full field list, like `withServerFields`). Use whatever getter `Activity` exposes for the day (`day` is what `HistoryController._sorted` uses).

`history_controller.dart`: after the repository call succeeds in `add`, and after `delete` succeeds in `remove`:

```dart
    // Last contact is the server's answer: the book re-reads it.
    ref.invalidate(peopleProvider(ref.read(accountProvider)?.email));
```

(imports `people_controller.dart` and `auth_repository.dart`; the import cycle with `people_controller.dart` is fine in Dart).

- [ ] **Step 4: Run**

Run: `flutter test test/features/contacts && flutter analyze`
Expected: all pass, No issues found!

- [ ] **Step 5: Commit**

```bash
git add lib/features/contacts test/features/contacts test/features/workflows/server_rule.dart
git commit -m "feat(team): read last contact and reload it after logging"
```

### Task 3: `checkIns` domain rule

**Files:**
- Create: `lib/features/team/domain/check_in.dart`
- Test: `test/features/team/domain/check_in_test.dart`

**Interfaces:**
- Consumes: `Person.lastContactOn`, `Person.stageSince`, `daysBetween` (`workflows/domain/progress.dart`), `searchKey` (`contacts/domain/search_key.dart`).
- Produces:

```dart
enum CheckInReason { isNew, quiet }
typedef CheckIn = ({Person person, CheckInReason reason, DateTime since, int days});
DateTime joinedOn(Person person);           // local day of stageSince
bool talkedSinceJoining(Person person);     // lastContactOn on/after joinedOn
List<CheckIn> checkIns(List<Person> team, DateTime today);
```

`since` is the day the reason counts from (New: joining day; Quiet: last contact, or joining day when nothing is logged); `days = daysBetween(since, today)`.

- [ ] **Step 1: Failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/team/domain/check_in.dart';

final today = DateTime(2026, 9, 30);

Person member(String name, DateTime joined, [DateTime? talked]) => Person(
  id: name, name: name, stage: Stage.team, stageSince: joined,
  lastContactOn: talked,
);

void main() {
  test('new: joined under 30 days ago, nothing logged since', () {
    final [c] = checkIns([member('Ana', DateTime(2026, 9, 9))], today);
    expect(c.reason, CheckInReason.isNew);
    expect(c.days, 21);
  });

  test('new: a contact before joining does not count', () {
    final [c] = checkIns(
      [member('Ana', DateTime(2026, 9, 20), DateTime(2026, 9, 1))], today);
    expect(c.reason, CheckInReason.isNew);
  });

  test('not new at 30 days: quiet from the joining day instead', () {
    final [c] = checkIns([member('Ana', DateTime(2026, 8, 31))], today);
    expect(c.reason, CheckInReason.quiet);
    expect(c.days, 30);
  });

  test('quiet from 14 days, not 13', () {
    final old = DateTime(2026, 1, 1);
    expect(checkIns([member('A', old, DateTime(2026, 9, 17))], today), isEmpty);
    final [c] = checkIns([member('A', old, DateTime(2026, 9, 16))], today);
    expect((c.reason, c.days, c.since),
        (CheckInReason.quiet, 14, DateTime(2026, 9, 16)));
  });

  test('new wins over quiet: one row', () {
    final [c] = checkIns([member('A', DateTime(2026, 9, 10))], today);
    expect(c.reason, CheckInReason.isNew);
  });

  test('neither: talked since joining, lately', () {
    expect(checkIns(
      [member('A', DateTime(2026, 9, 20), DateTime(2026, 9, 30))], today),
      isEmpty);
  });

  test('joining day is the local calendar day', () {
    final lateEvening = DateTime(2026, 9, 29, 23, 30).toUtc();
    expect(joinedOn(member('A', lateEvening)), DateTime(2026, 9, 29));
  });

  test('oldest first, then by name', () {
    final rows = checkIns([
      member('Zoé', DateTime(2026, 9, 20)),
      member('Émile', DateTime(2026, 9, 20)),
      member('Bruno', DateTime(2026, 1, 1), DateTime(2026, 8, 1)),
    ], today);
    expect([for (final c in rows) c.person.name], ['Bruno', 'Émile', 'Zoé']);
  });
}
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/features/team/domain/check_in_test.dart`
Expected: compile error, `check_in.dart` missing.

- [ ] **Step 3: Implement** `lib/features/team/domain/check_in.dart`:

```dart
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
/// not yet talked to, or quiet for two weeks. One row each, oldest first.
List<CheckIn> checkIns(List<Person> team, DateTime today) {
  final rows = <CheckIn>[];
  for (final person in team) {
    final joined = joinedOn(person);
    final sinceJoining = daysBetween(joined, today);
    if (sinceJoining < 30 && !talkedSinceJoining(person)) {
      rows.add((person: person, reason: CheckInReason.isNew,
          since: joined, days: sinceJoining));
      continue;
    }
    final last = person.lastContactOn ?? joined;
    final quiet = daysBetween(last, today);
    if (quiet >= 14) {
      rows.add((person: person, reason: CheckInReason.quiet,
          since: last, days: quiet));
    }
  }
  return rows..sort((a, b) {
    final bySince = a.since.compareTo(b.since);
    return bySince != 0
        ? bySince
        : searchKey(a.person.name).compareTo(searchKey(b.person.name));
  });
}
```

- [ ] **Step 4: Run**

Run: `flutter test test/features/team/domain/check_in_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/team/domain test/features/team/domain
git commit -m "feat(team): who is worth a check-in"
```

### Task 4: The screen — talked, summary sentence, WORTH A CHECK-IN

**Files:**
- Modify: `lib/l10n/app_en.arb` (after `teamLoadFailed`)
- Modify: `lib/features/team/presentation/team_page.dart`
- Test: `test/features/team/team_page_test.dart`

**Interfaces:**
- Consumes: Task 3's `checkIns`, `joinedOn`, `talkedSinceJoining`; `showLogActivity(context, person)`; `ActionItem`, `DateChip`; `firstName`.
- Produces: `TeamView.onCheckIn` (`void Function(Person person)`, required); `rosterLabel(AppLocalizations l10n, Person person, DateTime today)` replacing `joinedLabel` at the call site (keep `joinedLabel`, it is the fallback).

- [ ] **Step 1: ARB keys** (each with `@key` description, placeholders typed like the `teamJoined*` ones; dates `DateTime` with `format` `MMMMd` for the reason, `yMMMM` for "in"):

```
"teamTalkedToday": "Team · talked today"
"teamTalkedYesterday": "Team · talked yesterday"
"teamTalkedDaysAgo": "{count, plural, other{Team · talked {count} days ago}}"
"teamTalkedWeeksAgo": "{count, plural, =1{Team · talked a week ago} other{Team · talked {count} weeks ago}}"
"teamTalkedIn": "Team · talked in {date}"
"teamCheckInSummary": "{count, plural, =0{Everyone has heard from you lately.} =1{One of them could use a message this week.} other{{count} of them could use a message this week.}}"
"teamSectionCheckIn": "Worth a check-in"
"teamChipNew": "New"
"teamChipQuiet": "{count, plural, =1{Quiet a week} other{Quiet {count} weeks}}"
"teamReasonNewToday": "Joined today and nothing is logged yet"
"teamReasonNewDays": "{count, plural, =1{Joined yesterday and nothing is logged since} other{Joined {count} days ago and nothing is logged since}}"
"teamReasonNewWeeks": "{count, plural, =1{Joined a week ago and nothing is logged since} other{Joined {count} weeks ago and nothing is logged since}}"
"teamReasonQuiet": "You last talked on {date}"
"teamReasonQuietNothing": "Nothing is logged since they joined on {date}"
```

Run `flutter gen-l10n`. Descriptions say where each shows and that nothing is a score.

- [ ] **Step 2: Failing widget tests** (in `team_page_test.dart`, with the file's `_pump` helper, today `DateTime(2026, 9, 30)`; `_pump` gains `onCheckIn`):

```dart
testWidgets('says when you last talked, once since joining', (tester) async {
  await _pump(tester, [
    member('Ana', DateTime(2026, 9, 1), talked: DateTime(2026, 9, 29)),
    member('Bea', DateTime(2026, 9, 20), talked: DateTime(2026, 9, 1)),
  ]);
  expect(find.text('Team · talked yesterday'), findsOneWidget);
  expect(find.text('Team · joined 10 days ago'), findsOneWidget);
});

testWidgets('lists who is worth a check-in, and why', (tester) async {
  await _pump(tester, [
    member('Ana', DateTime(2026, 1, 1), talked: DateTime(2026, 9, 12)),
    member('Bea', DateTime(2026, 9, 9)),
    member('Cy', DateTime(2026, 1, 1), talked: DateTime(2026, 9, 29)),
  ]);
  expect(find.text('Worth a check-in'), findsOneWidget);
  expect(find.textContaining('2 of them could use a message'), findsOneWidget);
  expect(find.text('You last talked on September 12'), findsOneWidget);
  expect(find.text('Quiet 2 weeks'), findsOneWidget);
  expect(find.text('Joined 3 weeks ago and nothing is logged since'),
      findsOneWidget);
  expect(find.text('New'), findsOneWidget);
});

testWidgets('no section when everyone heard from you', (tester) async {
  await _pump(tester, [
    member('Cy', DateTime(2026, 1, 1), talked: DateTime(2026, 9, 29)),
  ]);
  expect(find.text('Worth a check-in'), findsNothing);
  expect(find.textContaining('Everyone has heard from you lately.'),
      findsOneWidget);
});

testWidgets('the circle offers to log something', (tester) async {
  Person? logged;
  await _pump(tester, [member('Bea Martin', DateTime(2026, 9, 9))],
      onCheckIn: (p) => logged = p);
  await tester.tap(find.byTooltip('Log something with Bea'));
  expect(logged?.name, 'Bea Martin');
});
```

Adjust the finder in the last test to however `ActionItem` exposes `resolveLabel` (tooltip or semantics label — read `action_item.dart`). Also a full-app test via `pumpLoomia(tester, size: const Size(390, 844), people: repo..activities = activities, activities: activities)`: go to Team, tap the circle, fill "What happened", Save, `pumpAndSettle` — the row leaves WORTH A CHECK-IN and the roster says "Team · talked today". Use `FakeActivityRepository` and pick the day the sheet defaults to (today()), so use a member who joined relative to `today()` (e.g. `addDays(today(), -9)`).

- [ ] **Step 3: Run, expect failure**

Run: `flutter test test/features/team`
Expected: FAIL (missing `onCheckIn`, texts not found).

- [ ] **Step 4: Implement** in `team_page.dart`:

```dart
/// "Team · talked yesterday" once something is logged since they joined;
/// until then, when they joined.
String rosterLabel(AppLocalizations l10n, Person person, DateTime today) {
  final last = person.lastContactOn;
  if (last == null || !talkedSinceJoining(person)) {
    return joinedLabel(l10n, person.stageSince, today);
  }
  return switch (daysBetween(last, today)) {
    <= 0 => l10n.teamTalkedToday,
    1 => l10n.teamTalkedYesterday,
    < 7 && final days => l10n.teamTalkedDaysAgo(days),
    <= 56 && final days => l10n.teamTalkedWeeksAgo(days ~/ 7),
    _ => l10n.teamTalkedIn(last),
  };
}
```

`TeamPage`: `onCheckIn: (person) => unawaited(showLogActivity(context, person)),` (the book reloads from Task 2; import `dart:async`).

`TeamView._team`: compute `final due = checkIns(team, today);` pass `due.length` to `_Summary(team:, checkIns:)`; the paragraph becomes `'${l10n.teamCheckInSummary(checkIns)} ${l10n.teamNotMeasured}'` (two whole sentences, so no grammar is split). Between the summary and EVERYONE, when `due` is not empty:

```dart
      const SizedBox(height: AppSpacing.lg),
      SectionHeader(title: l10n.teamSectionCheckIn),
      for (final c in due) ...[
        ActionItem(
          name: c.person.name,
          reason: _reason(l10n, c),
          chip: DateChip(switch (c.reason) {
            CheckInReason.isNew => l10n.teamChipNew,
            CheckInReason.quiet => l10n.teamChipQuiet(c.days ~/ 7),
          }),
          onOpen: () => onOpen(c.person),
          onResolve: () => onCheckIn(c.person),
          resolveLabel: l10n.logTitle(firstName(c.person)),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
```

with

```dart
  String _reason(AppLocalizations l10n, CheckIn c) => switch (c.reason) {
    CheckInReason.isNew when c.days <= 0 => l10n.teamReasonNewToday,
    CheckInReason.isNew when c.days < 7 => l10n.teamReasonNewDays(c.days),
    CheckInReason.isNew => l10n.teamReasonNewWeeks(c.days ~/ 7),
    CheckInReason.quiet when c.person.lastContactOn == null =>
      l10n.teamReasonQuietNothing(c.since),
    CheckInReason.quiet => l10n.teamReasonQuiet(c.since),
  };
```

Match the spacing Today uses between `ActionItem`s (read `today_page.dart`; use the same constant). Roster rows use `rosterLabel(l10n, person, today)`.

- [ ] **Step 5: Run**

Run: `dart format . && flutter analyze && flutter test`
Expected: No issues found!, all tests pass (goldens for Team may fail on macOS only if compared — they are Linux-only, so skipped).

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_en.arb lib/features/team test/features/team
git commit -m "feat(team): worth a check-in and when you last talked"
```

### Task 5: Preview, goldens, docs

**Files:**
- Modify: `lib/features/team/presentation/team_preview.dart` (members get `lastContactOn` so the preview shows one New, one Quiet, the rest talked; pass `onCheckIn: (_) {}`)
- Modify: `docs/design/screens.md` §4 ("Built" / "Not built")
- Regenerate: `test/goldens/team_*.png` through CI

- [ ] **Step 1:** Preview book, `_member(name, since, [talked])`:
  Bruno 2026-06-02 talked 2026-09-10 (Quiet 2 weeks), Inès 2026-09-29 (New, joined yesterday), John 2026-09-09 talked 2026-09-28, Léa 2026-08-19 talked 2026-09-24, Marc 2026-09-25 talked 2026-09-29, Sophie 2026-03-04 talked 2026-09-26.
- [ ] **Step 2:** `docs/design/screens.md` §4: move WORTH A CHECK-IN, the summary sentence and "talked" to Built; "has not added a contact yet" stays Not built (#67).
- [ ] **Step 3:** `dart format . && flutter analyze && flutter test`; commit `feat(team): preview the check-ins` + docs.
- [ ] **Step 4:** Push the branch (after confirming with the user), `gh workflow run CI --ref feature/103-check-in -f update-goldens=true`, then `rm test/goldens/team_*.png` is not enough — follow README → *Golden tests*: `rm test/goldens/*.png; gh run download <run-id> -n goldens -D test/goldens`, look at the three Team images, `git status` shows only team goldens changed, commit `test(team): goldens for check-ins`.
