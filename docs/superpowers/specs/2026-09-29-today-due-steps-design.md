# Today suggests due steps — design

Issue [#58](https://github.com/paulthvt/folo-mlm/issues/58), part of #53.
Depends on #57 (workflows, merged).

## Intent

Today answers "What should I do today?" with the people whose next workflow
step is due today or late, instead of sample data. A tick on Today is the same
tick as on the contact page.

Push notifications (later) must say exactly what Today says. So the rule that
decides a person's current step and its due day lives in **one** place,
Postgres, and every reader — Today, the contact page's NEXT STEP, a future push
job — reads its answer. The device only compares that day with its own today
(#48).

## Decisions

| Question | Decision |
| --- | --- |
| What else stays on Today | Only what is real: date, greeting, hero sentence, PRIORITY. Goal, stats, "You talked to", the progress bar and the effort label go until their features exist. |
| Many people due | 5 rows on mobile/tablet, 6 on desktop, oldest first; `And N more waiting` expands the rest in place. |
| Where the rule lives | Postgres. Two computed fields on `person`; `complete_step` computes the next position itself. |

## 1. Database — one migration

`supabase migration new today_due_steps`.

**Computed fields** (PostgREST selects them as `*, current_step_id, due_on`):

```sql
-- The first step at or after the person's position; null with no workflow or
-- once past the last step.
create function public.current_step_id(p public.person) returns uuid
language sql stable security invoker set search_path = '' as $$
  select s.id from public.workflow_step s
  where s.workflow_id = p.workflow_id and s.position >= p.at_position
  order by s.position limit 1
$$;

-- When that step is due: its days after the last tick. Null while paused,
-- with no workflow, or done.
create function public.due_on(p public.person) returns date
language sql stable security invoker set search_path = '' as $$
  select p.last_tick + s.days from public.workflow_step s
  where p.paused_at is null and s.id = public.current_step_id(p)
$$;
```

Grants mirror `complete_step`: revoke from `public, anon`, grant to
`authenticated`. RLS on `workflow_step` still applies (security invoker).

**`complete_step` is replaced** by `complete_step(p_person, p_step, p_on)`:

- refuses `p_step` unless it is the person's current step
  (`public.current_step_id(person)`), errcode `P0002` as today. This also fixes
  the #59 carry-over "a stale tick from a second device adds a duplicate
  history entry";
- computes the next position itself: the next step's position, or the
  current one + 1 past the last step;
- same history entry, same `last_tick = p_on`, returns the row.

The old four-argument function is dropped in the same migration.

**Unchanged on the device:** `start()` (the place a new workflow begins at) and
`resume()` (`last_tick = today`). They write inputs; the server still derives
the step and the day from them, so nothing can disagree.

## 2. Device — the model

- `Person` gains `currentStepId` (`String?`) and `dueOn` (`DateTime?`, local
  midnight via the existing day-column parsing). Read-only: never written by
  `personToRow`.
- `PeopleRepository` selects `*, current_step_id, due_on` on every read and
  every write that returns a row (`list`, `add`, `_write`, `complete_step` via
  `.rpc(...).select(...)`).
- `completeStep(personId, stepId, on)` loses `nextPosition`;
  `PeopleController.completeStep` loses its `nextPosition(...)` call, and
  `nextPosition` is deleted from `progress.dart`.
- `progressOf(person, workflow)` stops finding the step:
  - `pausedAt` set → `Paused`;
  - no place, or `workflow` missing / not the person's → null;
  - `currentStepId == null` → `Done`;
  - otherwise the step with that id in `workflow.steps` → `OnStep` with its
    1-based index, the total, and `due: person.dueOn!`. Id not found (the
    workflow list is older than the book) → null, the "no workflow" card, until
    the next load.
- The test fake (`FakePeopleRepository`) reproduces the rule in Dart so widget
  tests run; it is the only other copy, and the pgTAP cases in §5 pin the real
  one.

## 3. Device — Today

**Domain** — `lib/features/today/domain/due.dart`:

```dart
typedef Due = ({Person person, OnStep step});

/// People whose step is due on or before [today], oldest first, then by name.
List<Due> dueToday(List<Person> people, List<Workflow> workflows, DateTime today);
```

Built on `progressOf` and `findWorkflow`; keeps `OnStep` with
`!step.due.isAfter(today)`. Paused, done, no workflow and not-yet-due fall out.

**Provider** — `todayProvider`, next to `TodayPage`: watches
`peopleProvider(email)` and `workflowsProvider(email)`, returns
`AsyncValue<List<Due>>` — loading if either loads, failed if either failed.
`today()` is read at build: past midnight, Today changes on the next rebuild or
when the stale book reloads on resume (existing one-minute rule). No midnight
timer.

**Removed:** `TodaySnapshot`, `sampleToday`, `todaySnapshotProvider`, the goal /
stats / recent sections and the desktop right column, `TodayHero`'s progress and
effort parameters, and the EN strings only they used. `app_fr.arb` is not
touched.

**Screen**, one column on every size (max width 624; desktop uses the large top
bar and its padding):

- Top bar — eyebrow: the localized date ("MONDAY 29 SEPTEMBER"); title:
  "Good morning, Pauline" / "Good afternoon, …" / "Good evening, …" from the
  device clock and `Account.firstName`; without a first name, "Good morning"
  alone. Mobile keeps the account button.
- Loading (either provider) — a centred spinner.
- Failed — "Couldn't load today." + `Try again`, which invalidates whichever
  failed.
- Nothing due — the existing "You are up to date" empty state.
- Otherwise:
  - `TodayHero` — ICU plural: "One person is worth a message today" /
    "{count} people are worth a message today". Counts everyone due, not only
    the visible rows.
  - `PRIORITY` — one `ActionItem` per row: name as title; reason
    "{step} · {workflow}, step {index} of {total}"; an accent `DateChip`
    only when late ("2 days late", from `dueLabel`); tap opens
    `Routes.contactLocation(id)`; tick runs
    `completeStep(person, step, today())` through `writePeople`, with the
    person's tick hidden while its write is in flight. Failure: the usual
    SnackBar, the row stays. Success: the book updates and the row leaves, or
    shows the next step if that one is due too.
  - First 5 rows (6 on desktop); below them `And {count} more waiting`, which
    shows the rest in place (local state, resets on leaving).
- Pull to refresh on every size reloads the book, as on Contacts.

## 4. Docs

- `docs/architecture.md` — workflow rules live in Postgres; the device compares
  `due_on` with its own today and never recomputes a step.
- `docs/design/screens.md` §1 — Today as built here.
- Figma Today frames — after the code lands, on request.

## 5. Tests

- **pgTAP** (`supabase/tests/`): `current_step_id` and `due_on` on a step,
  done, no workflow, paused; a removed current step hands over to the next; a
  step inserted before is skipped; `complete_step` moves on and returns the new
  fields; refuses a step that is not current; the last step moves past the end.
- **Dart unit**: `progressOf` on the new fields (paused, done, on step, id not
  found); `dueToday` ordering and filtering.
- **Today widget test** (#58's done-when): due today, late, not yet due and
  paused (only the first two show); oldest first; late chip only when late;
  tick sends `completeStep` and the row leaves; failed tick keeps it with the
  SnackBar; cap and `And N more waiting`; loading, failed + Try again, empty;
  tapping opens the person.
- **Contacts**: the #57 tests pass on the new fields.
- `test/app_test.dart` stops expecting `sampleToday.greeting`.
- **Goldens**: the Today preview renders a fixed due list; regenerated through
  CI.

## Out of scope

- Push notifications: will add a user timezone, FCM tokens and a scheduled job
  that runs `due_on <= <user's local date>` — the same fields, no new rule.
- Offline ticks (#46): ticks already wait for the server.
- Goals, stats, recent activity.
- A collapse animation on tick.
