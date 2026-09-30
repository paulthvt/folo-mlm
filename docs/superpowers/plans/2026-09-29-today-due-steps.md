# Today suggests due steps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Today lists the people whose workflow step is due today or late, from the real book, with a tick that is the same tick as on the contact page.

**Architecture:** The workflow rule moves into Postgres: two computed fields on `person` (`current_step_id`, `due_on`) and a `complete_step` that finds the next position itself. The device reads them, compares `due_on` with its own `today()`, and never recomputes a step. Today becomes a single column of `ActionItem`s built from `peopleProvider` + `workflowsProvider`.

**Tech Stack:** Flutter, Riverpod 3 (no codegen), go_router, Supabase (Postgres, PostgREST computed fields, pgTAP).

**Spec:** `docs/superpowers/specs/2026-09-29-today-due-steps-design.md`

## Global Constraints

- Imports: `package:folo/...` always; Material from `package:material_ui/material_ui.dart`, never `flutter/material.dart`.
- No hard-coded colour, radius, font size or spacing in widgets: `Theme.of(context).colorScheme`, `AppSpacing.*`, `AppRadii.*`.
- Layout branches on `context.screenSize`, never raw widths.
- EN strings only in `lib/l10n/app_en.arb`, each with an `@key` description. Never touch `lib/l10n/app_fr.arb` (extra FR keys are ignored by gen-l10n; `flutter analyze` must stay clean).
- No MLM wording: no "recruit", "lead", "downline", leaderboards, ranks.
- Schema changes only via `supabase migration new today_due_steps`. Never run `supabase db push` (the user does it, VPN off). Never ask for the DB password.
- No new dependencies. No code generation.
- Never commit goldens made locally; they are regenerated through CI after the push.
- Conventional Commits, every commit message ends with `(#58)`.
- Before claiming a task done: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`.

## Review Focus

- **Stale tick from a second device** (the step was already ticked elsewhere): the server refuses (`P0002`), the device shows "Something went wrong. Try again." and the book is unchanged. Test: Task 2, fake + controller.
- **Workflow list older than the book** (`currentStepId` not in the loaded workflow): no progress (null) rather than a crash or a wrong step; the person drops out of Today until the next load. Test: Task 2, `progress_test`.
- **Pull to refresh fails while rows are shown**: the rows stay, the "Couldn't refresh" SnackBar shows, no error screen. Test: Task 4.
- **Account without a first name**: "Good morning" alone, never "Good morning, ". Test: Task 4.
- **Greeting at the hour boundaries** (11:59, 12:00, 17:59, 18:00, 00:00): morning / afternoon / afternoon / evening / morning. Test: Task 4.

## File map

| File | Change |
| --- | --- |
| `supabase/migrations/<ts>_today_due_steps.sql` | new: computed fields, new `complete_step` |
| `supabase/tests/due_test.sql` | new pgTAP |
| `supabase/tests/workflow_test.sql` | 3-argument `complete_step` calls |
| `lib/features/contacts/domain/person.dart` | `currentStepId`, `dueOn` |
| `lib/features/contacts/data/people_repository.dart` | select the computed fields; `completeStep` loses `nextPosition` |
| `lib/features/contacts/presentation/people_controller.dart` | drop the `nextPosition` call |
| `lib/features/workflows/domain/progress.dart` | `progressOf` reads the server fields; `nextPosition` deleted |
| `test/features/workflows/server_rule.dart` | new: the test-only Dart copy of the rule |
| `test/features/contacts/fake_people_repository.dart` | derives the server fields |
| `lib/features/today/domain/due.dart` | new: `Due`, `dueToday` |
| `lib/features/today/domain/today_snapshot.dart` | deleted |
| `lib/features/today/presentation/today_page.dart` | rewritten |
| `lib/features/today/presentation/today_hero.dart` | loses progress and effort |
| `lib/features/today/presentation/today_preview.dart` | fixed due list |
| `lib/l10n/app_en.arb` | new Today strings, two removed |
| `docs/architecture.md`, `docs/design/screens.md` | Today as built, rules in Postgres |

---

### Task 1: The rule in Postgres

**Files:**
- Create: `supabase/migrations/<timestamp>_today_due_steps.sql` (via `supabase migration new today_due_steps`)
- Create: `supabase/tests/due_test.sql`
- Modify: `supabase/tests/workflow_test.sql` (the two `complete_step` calls)

**Interfaces:**
- Produces: `public.current_step_id(public.person) returns uuid`, `public.due_on(public.person) returns date` (PostgREST selects them as `*, current_step_id, due_on`), `public.complete_step(p_person uuid, p_step uuid, p_on date) returns public.person`. The 4-argument version no longer exists.

- [ ] **Step 1: Create the migration file**

Run: `supabase migration new today_due_steps`
Expected: prints `Created new migration at supabase/migrations/<timestamp>_today_due_steps.sql`.

- [ ] **Step 2: Write the failing pgTAP test**

`supabase/tests/due_test.sql`:

```sql
-- The workflow rule, which lives only here: a person's current step, when it
-- is due, and what ticking it does. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.workflow (id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'prospect', 'Samples');
insert into public.workflow_step (id, workflow_id, position, label, days) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000f1', 1, 'Send a first message', 0),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000f1', 2, 'Send the samples', 1),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000f1', 3, 'Samples arrived', 4);

insert into public.person (id, name, stage, workflow_id, at_position, last_tick, paused_at) values
  ('00000000-0000-0000-0000-0000000000a1', 'On a step', 'prospect', '00000000-0000-0000-0000-0000000000f1', 2, '2026-09-28', null),
  ('00000000-0000-0000-0000-0000000000a2', 'Done', 'prospect', '00000000-0000-0000-0000-0000000000f1', 4, '2026-09-28', null),
  ('00000000-0000-0000-0000-0000000000a3', 'No workflow', 'prospect', null, null, null, null),
  ('00000000-0000-0000-0000-0000000000a4', 'Paused', 'prospect', '00000000-0000-0000-0000-0000000000f1', 2, '2026-09-28', now()),
  ('00000000-0000-0000-0000-0000000000a5', 'At the start', 'prospect', '00000000-0000-0000-0000-0000000000f1', 1, '2026-09-28', null);

select results_eq(
  $$ select p.current_step_id, p.due_on from public.person p
     where p.id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values ('00000000-0000-0000-0000-0000000000c2'::uuid, '2026-09-29'::date) $$,
  'on a step: that step, due its days after the last tick'
);
select results_eq(
  $$ select p.current_step_id, p.due_on from public.person p
     where p.id = '00000000-0000-0000-0000-0000000000a2' $$,
  $$ values (null::uuid, null::date) $$,
  'past the last step: no step, nothing due'
);
select is(
  (select p.due_on from public.person p where p.id = '00000000-0000-0000-0000-0000000000a3'),
  null,
  'no workflow: nothing due'
);
select is(
  (select p.due_on from public.person p where p.id = '00000000-0000-0000-0000-0000000000a4'),
  null,
  'paused: nothing due'
);

select lives_ok(
  $$ select public.complete_step(
       '00000000-0000-0000-0000-0000000000a5',
       '00000000-0000-0000-0000-0000000000c1', '2026-09-30') $$,
  'complete_step ticks the current step'
);
select results_eq(
  $$ select p.at_position, p.last_tick, p.current_step_id, p.due_on
     from public.person p where p.id = '00000000-0000-0000-0000-0000000000a5' $$,
  $$ values (2::numeric, '2026-09-30'::date,
             '00000000-0000-0000-0000-0000000000c2'::uuid, '2026-10-01'::date) $$,
  'complete_step moves to the next step, counted from the tick'
);
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a5' and kind = 'step'),
  1,
  'complete_step writes one history entry'
);
select throws_ok(
  $$ select public.complete_step(
       '00000000-0000-0000-0000-0000000000a5',
       '00000000-0000-0000-0000-0000000000c1', '2026-09-30') $$,
  'P0002', null,
  'a step that is no longer current is refused (stale tick)'
);
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a5' and kind = 'step'),
  1,
  'a refused tick adds no history entry'
);
select throws_ok(
  $$ select public.complete_step(
       '00000000-0000-0000-0000-0000000000a3',
       '00000000-0000-0000-0000-0000000000c1', '2026-09-30') $$,
  'P0002', null,
  'a person with no workflow has no step to tick'
);

delete from public.workflow_step where id = '00000000-0000-0000-0000-0000000000c2';
select results_eq(
  $$ select p.current_step_id, p.due_on from public.person p
     where p.id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values ('00000000-0000-0000-0000-0000000000c3'::uuid, '2026-10-02'::date) $$,
  'current step removed: the next one takes over, with its own days'
);

insert into public.workflow_step (workflow_id, position, label, days) values
  ('00000000-0000-0000-0000-0000000000f1', 1.5, 'Inserted before', 2);
select is(
  (select p.current_step_id from public.person p where p.id = '00000000-0000-0000-0000-0000000000a1'),
  '00000000-0000-0000-0000-0000000000c3'::uuid,
  'a step inserted before the current one is skipped'
);

select results_eq(
  $$ select (m).at_position, (m).last_tick from (
       select public.complete_step(
         '00000000-0000-0000-0000-0000000000a1',
         '00000000-0000-0000-0000-0000000000c3', '2026-10-02') as m) t $$,
  $$ values (4::numeric, '2026-10-02'::date) $$,
  'the last step moves one past the end, and returns the row'
);
select results_eq(
  $$ select p.current_step_id, p.due_on from public.person p
     where p.id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values (null::uuid, null::date) $$,
  'after the last step: done'
);
select is(
  has_function_privilege('anon', 'public.due_on(public.person)', 'execute'),
  false,
  'anon cannot call due_on'
);

select * from finish();
rollback;
```

- [ ] **Step 3: Run it to verify it fails**

Run: `supabase status >/dev/null 2>&1 || supabase start` then `supabase test db`
Expected: `due_test.sql` FAILS (`function public.current_step_id does not exist` or similar); `workflow_test.sql` still passes. If Docker or the local stack cannot start, say so in the report and continue: CI runs `supabase test db` on the PR.

- [ ] **Step 4: Write the migration**

The migration file created in Step 1:

```sql
-- Today (#58): the workflow rule lives here and only here. A person's current
-- step and its due day are computed fields every reader selects (Today, the
-- contact's NEXT STEP, later a push job), and complete_step finds the next
-- position itself. The device compares due_on with its own today, nothing
-- more. Supersedes "Rules live in Dart" in 20260929085602_workflows.sql.

-- The first step at or after the person's position; null with no workflow or
-- once past the last step. Found by position, not id, so an edit applies at
-- once: a removed step hands over to the next, an inserted one before is
-- skipped.
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

drop function public.complete_step(uuid, uuid, numeric, date);

-- Ticks the person's current step: the history entry, with the label as it
-- reads today, and the move to the next step (or one past the last), in one
-- transaction. Any other step is refused, so a stale tick from a second
-- device adds nothing.
create function public.complete_step(p_person uuid, p_step uuid, p_on date)
returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person;
  step public.workflow_step;
  next_position numeric;
  moved public.person;
begin
  select * into target from public.person where id = p_person;
  if target.id is null
    or public.current_step_id(target) is distinct from p_step then
    raise exception 'step % is not the current step of person %', p_step, p_person
      using errcode = 'P0002';
  end if;

  select * into step from public.workflow_step where id = p_step;
  select coalesce(min(s.position), step.position + 1) into next_position
    from public.workflow_step s
    where s.workflow_id = step.workflow_id and s.position > step.position;

  insert into public.activity (person_id, kind, text, happened_on)
    values (p_person, 'step', step.label, p_on);
  update public.person
    set at_position = next_position, last_tick = p_on
    where id = p_person
    returning * into moved;
  return moved;
end $$;

revoke execute on function public.current_step_id(public.person) from public, anon;
revoke execute on function public.due_on(public.person) from public, anon;
revoke execute on function public.complete_step(uuid, uuid, date) from public, anon;
grant execute on function public.current_step_id(public.person) to authenticated;
grant execute on function public.due_on(public.person) to authenticated;
grant execute on function public.complete_step(uuid, uuid, date) to authenticated;
```

- [ ] **Step 5: Move `workflow_test.sql` to the 3-argument call**

In both `complete_step` calls (around lines 60 and 80), delete the `2, ` before `'2026-09-30'`:

```sql
       (select s.id from public.workflow_step s
          join public.workflow w on w.id = s.workflow_id
          where w.name = 'Samples' and s.position = 1),
       '2026-09-30') $$,
```

(and the same for the `'Health professionals'` call). Its expectations do not change: position 1 moves to 2; a step of another workflow is not current, so `P0002`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `supabase db reset && supabase test db`
Expected: every file `ok`, `due_test.sql .. ok`, `workflow_test.sql .. ok`.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/*_today_due_steps.sql supabase/tests/due_test.sql supabase/tests/workflow_test.sql
git commit -m "feat(db): current step and due day computed on the server (#58)"
```

### Task 2: The device reads the server's answer

**Files:**
- Modify: `lib/features/contacts/domain/person.dart`
- Modify: `lib/features/contacts/data/people_repository.dart`
- Modify: `lib/features/contacts/presentation/people_controller.dart:95-110`
- Modify: `lib/features/workflows/domain/progress.dart`
- Create: `test/features/workflows/server_rule.dart`
- Modify: `test/features/contacts/fake_people_repository.dart`
- Modify: `test/features/workflows/domain/progress_test.dart`
- Modify: `test/features/contacts/data/people_repository_test.dart`
- Modify: `test/features/contacts/presentation/people_controller_test.dart`

**Interfaces:**
- Consumes: Task 1's computed fields `current_step_id` (uuid) and `due_on` (date), and `complete_step(p_person, p_step, p_on)`.
- Produces:
  - `Person.currentStepId` (`String?`), `Person.dueOn` (`DateTime?`, local midnight), both optional named constructor parameters.
  - `PeopleRepository.completeStep(String personId, String stepId, DateTime on)` → `Future<Person>`.
  - `progressOf(Person, Workflow?)` → `WorkflowProgress?` (same signature, now reads `currentStepId` / `dueOn`).
  - Test helpers `withServerFields(Person, List<Workflow>)` → `Person` and `positionAfter(Workflow, String stepId)` → `num` in `test/features/workflows/server_rule.dart`.
  - `FakePeopleRepository.workflows` (`List<Workflow>`, defaults to `FakeWorkflowRepository.samples()`); every person it returns carries the server fields.
  - `nextPosition` no longer exists.

- [ ] **Step 1: Write the failing tests**

In `test/features/contacts/data/people_repository_test.dart`, next to `'reads the workflow fields, last_tick as a local day'` (same group, same `row(...)` helper):

```dart
    test("reads the server's step and day, due_on as a local day", () {
      final person = personFromRow(
        row({
          'workflow_id': 'w1',
          'at_position': 2,
          'last_tick': '2026-09-28',
          'current_step_id': 's2',
          'due_on': '2026-09-29',
        }),
      );

      expect(person.currentStepId, 's2');
      expect(person.dueOn, DateTime(2026, 9, 29));
    });

    test('nothing due reads as null', () {
      final person = personFromRow(row());

      expect(person.currentStepId, isNull);
      expect(person.dueOn, isNull);
    });
```

In `test/features/workflows/domain/progress_test.dart`, replace the `_on` helper and every test from `'the current step is the first at or after the position'` through `'nextPosition: the next step, or one past the last'` (the position rule now lives in `supabase/tests/due_test.sql`) with the block below. Keep `_step`, `_samples`, and the tests from `'start puts the first step on the chosen day'` onward unchanged; if one of them used `_on`, point it at `_at` with the same values.

```dart
/// A person as the server returns them: on [stepId], due on [due].
Person _at(String? stepId, {DateTime? due, DateTime? pausedAt}) => Person(
  id: 'p1',
  name: 'Sarah',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 9, 1),
  place: (workflowId: 'w1', atPosition: 2, lastTick: DateTime(2026, 9, 28)),
  currentStepId: stepId,
  dueOn: due,
  pausedAt: pausedAt,
);

void main() {
  test("the server's step, its place in the list and its day", () {
    final progress =
        progressOf(_at('s2', due: DateTime(2026, 9, 29)), _samples())
            as OnStep;

    expect(progress.step.label, 'Send the samples');
    expect(progress.index, 2);
    expect(progress.total, 3);
    expect(progress.due, DateTime(2026, 9, 29));
  });

  test('steps come sorted by position whatever the order given', () {
    final workflow = _samples([
      _step(3, 'Samples arrived', 4),
      _step(1, 'Send a first message', 0),
      _step(2, 'Send the samples', 1),
    ]);
    final progress =
        progressOf(_at('s2', due: DateTime(2026, 9, 29)), workflow) as OnStep;

    expect(progress.index, 2);
  });

  test('a rename shows at once', () {
    final workflow = _samples([
      _step(1, 'Send a first message', 0),
      _step(2, 'Post the samples', 1),
      _step(3, 'Samples arrived', 4),
    ]);
    final progress =
        progressOf(_at('s2', due: DateTime(2026, 9, 29)), workflow) as OnStep;

    expect(progress.step.label, 'Post the samples');
  });

  test('no current step is done', () {
    expect(progressOf(_at(null), _samples()), isA<Done>());
  });

  test('a step the list does not have yet is no progress, not a crash', () {
    // The workflows were loaded before an edit the book already reflects.
    expect(
      progressOf(_at('s9', due: DateTime(2026, 9, 29)), _samples()),
      isNull,
    );
  });

  test('paused wins over everything, even no workflow', () {
    final since = DateTime.utc(2026, 7, 12);

    expect(
      (progressOf(_at('s2', pausedAt: since), _samples())! as Paused).since,
      since,
    );
    expect(progressOf(_at('s2', pausedAt: since), null), isA<Paused>());
  });

  test('no workflow, or one that is not in the list, is no progress', () {
    final other = Workflow(
      id: 'w2',
      stage: Stage.prospect,
      name: 'Other',
      isDefault: false,
      steps: const [],
    );

    expect(progressOf(_at('s2', due: DateTime(2026, 9, 29)), null), isNull);
    expect(progressOf(_at('s2', due: DateTime(2026, 9, 29)), other), isNull);
  });
```

(the remaining kept tests follow, then the closing `}` of `main`).

In `test/features/contacts/presentation/people_controller_test.dart`, after `'completeStep moves to the next step and reloads the history'` (add `import 'package:folo/features/contacts/domain/people_failure.dart';` if missing):

```dart
  test('a stale tick is refused and changes nothing', () async {
    final world = _world([onSamples(2)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;
    final progress = progressOf(marie, samples)! as OnStep;
    // Ticked on another device in the meantime.
    world.people.store['p1'] = onSamples(3);

    await expectLater(
      world.container
          .read(book.notifier)
          .completeStep(marie, progress, DateTime(2026, 9, 30)),
      throwsA(PeopleFailure.unknown),
    );
    expect(world.container.read(book).value!.single.place?.atPosition, 2);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/contacts/data/people_repository_test.dart test/features/workflows/domain/progress_test.dart test/features/contacts/presentation/people_controller_test.dart`
Expected: compile errors, `No named parameter with the name 'currentStepId'` / `The getter 'currentStepId' isn't defined`.

- [ ] **Step 3: `Person` gains the two fields**

`lib/features/contacts/domain/person.dart` — constructor, after `this.pausedAt,`:

```dart
    this.currentStepId,
    this.dueOn,
```

Fields, after `pausedAt`:

```dart
  /// The server's answer (`current_step_id`): the step they are on. Null with
  /// no workflow or once done. Read-only: never written back.
  final String? currentStepId;

  /// The server's answer (`due_on`): the day that step is due, local midnight.
  /// Null while paused, with no workflow, or done. Read-only.
  final DateTime? dueOn;
```

`withStatus`, after `pausedAt: pausedAt,`:

```dart
    currentStepId: currentStepId,
    dueOn: dueOn,
```

- [ ] **Step 4: The repository selects them; `completeStep` loses `nextPosition`**

`lib/features/contacts/data/people_repository.dart`:

Under `static const String _table = 'person';`:

```dart
  /// Every column, plus the server's computed step and due day.
  static const String _columns = '*, current_step_id, due_on';
```

`list()`: `.select()` → `.select(_columns)`. `add`: `.select()` → `.select(_columns)`. `_write`: `.select()` → `.select(_columns)`.

Replace `completeStep`:

```dart
  /// Ticks [stepId], which must be the person's current step: the history
  /// entry and the move, in one transaction on the server, which also finds
  /// the next step. Any other step (a stale tick) is refused.
  Future<Person> completeStep(String personId, String stepId, DateTime on) =>
      guardPeople(() async {
        final row = await _client
            .rpc<Object?>(
              'complete_step',
              params: {
                'p_person': personId,
                'p_step': stepId,
                'p_on': dayColumn(on),
              },
            )
            .select(_columns)
            .single();
        return personFromRow(row);
      });
```

`personFromRow`, after `pausedAt: ...,`:

```dart
    currentStepId: row['current_step_id'] as String?,
    dueOn: switch (row['due_on']) {
      // A bare date parses as local midnight, like last_tick.
      final String day => DateTime.parse(day),
      _ => null,
    },
```

`personToRow` is unchanged: the two fields are never written.

- [ ] **Step 5: The controller stops computing the next position**

`lib/features/contacts/presentation/people_controller.dart`, `completeStep`:

```dart
    _replace(
      await _repository.completeStep(person.id, progress.step.id, today),
    );
```

- [ ] **Step 6: `progressOf` reads the server; `nextPosition` goes**

`lib/features/workflows/domain/progress.dart` — replace the doc comment and body of `progressOf`, and delete `nextPosition` with its comment:

```dart
/// The server decides the step and its day (`current_step_id`, `due_on`, in
/// supabase/migrations/*_today_due_steps.sql); this only finds that step in
/// [workflow] for its label, note and "3 of 5".
///
/// Null when the person follows no workflow, one missing from the list
/// (deleted elsewhere), or a step the list does not have yet (loaded before
/// an edit), until the next load. Paused wins over everything.
WorkflowProgress? progressOf(Person person, Workflow? workflow) {
  if (person.pausedAt case final since?) return Paused(since);
  final place = person.place;
  if (place == null || workflow == null || workflow.id != place.workflowId) {
    return null;
  }
  final stepId = person.currentStepId;
  if (stepId == null) return Done(workflow);
  final steps = workflow.steps;
  final index = steps.indexWhere((step) => step.id == stepId);
  final due = person.dueOn;
  if (index == -1 || due == null) return null;
  return OnStep(
    workflow: workflow,
    step: steps[index],
    index: index + 1,
    total: steps.length,
    due: due,
  );
}
```

`start`, `firstDueDefault`, `addDays`, `daysBetween` stay.

- [ ] **Step 7: The test-only copy of the rule**

`test/features/workflows/server_rule.dart`:

```dart
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

/// The one Dart copy of the server's rule (`current_step_id`, `due_on`,
/// `complete_step`), so fakes answer like the database. Test-only: the app
/// never computes a step. supabase/tests/due_test.sql pins the real one.
Person withServerFields(Person person, List<Workflow> workflows) {
  final place = person.place;
  final step = place == null
      ? null
      : findWorkflow(workflows, place.workflowId)?.steps
            .where((step) => step.position >= place.atPosition)
            .firstOrNull;
  return Person(
    id: person.id,
    name: person.name,
    stage: person.stage,
    stageSince: person.stageSince,
    prospectStatus: person.prospectStatus,
    phone: person.phone,
    email: person.email,
    instagram: person.instagram,
    needs: person.needs,
    products: person.products,
    profession: person.profession,
    address: person.address,
    notes: person.notes,
    place: place,
    pausedAt: person.pausedAt,
    currentStepId: step?.id,
    dueOn: step == null || place == null || person.pausedAt != null
        ? null
        : addDays(place.lastTick, step.days),
  );
}

/// Where ticking [stepId] leads: the next step's position, or one past the
/// last.
num positionAfter(Workflow workflow, String stepId) {
  final steps = workflow.steps;
  final index = steps.indexWhere((step) => step.id == stepId);
  return index + 1 < steps.length
      ? steps[index + 1].position
      : steps[index].position + 1;
}
```

- [ ] **Step 8: The fake answers like the database**

`test/features/contacts/fake_people_repository.dart`:

Imports, added:

```dart
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

import '../workflows/fake_workflow_repository.dart';
import '../workflows/server_rule.dart';
```

Field, after `activities`:

```dart
  /// What the server's computed fields read. Tests may store people without
  /// them: every person returned gets them from here, as the database would.
  List<Workflow> workflows = FakeWorkflowRepository.samples();

  Person _served(Person person) => withServerFields(person, workflows);
```

`list()`: `return store.values.map(_served).toList();`
`add`: `return _served(person);` (the store keeps `person`).
`update`: `return _served(saved);`
`_with`: last line `return _served(person);` (the store keeps `person`).

Replace `completeStep`:

```dart
  @override
  Future<Person> completeStep(
    String personId,
    String stepId,
    DateTime on,
  ) async {
    await _record('completeStep($personId, $stepId)');
    final before = _served(store[personId]!);
    // The database refuses anything but the current step (a stale tick).
    if (before.currentStepId != stepId) throw PeopleFailure.unknown;
    final place = before.place!;
    return _with(
      before,
      place: (
        workflowId: place.workflowId,
        atPosition: positionAfter(
          findWorkflow(workflows, place.workflowId)!,
          stepId,
        ),
        lastTick: on,
      ),
      pausedAt: before.pausedAt,
    );
  }
```

- [ ] **Step 9: Run the tests to verify they pass**

Run: `flutter test`
Expected: all pass, including every #57 test in `contacts_page_test.dart` and `next_step_card_test.dart` unchanged (they store people without server fields; the fake derives them). `test/features/today/` and `test/app_test.dart` are untouched by this task and still pass.

Run: `grep -rn "nextPosition\|p_next_position" lib test` — Expected: no output.

- [ ] **Step 10: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/contacts lib/features/workflows test/features/contacts test/features/workflows
git commit -m "refactor: the device reads the server's step and due day (#58)"
```

### Task 3: Who is due today

**Files:**
- Create: `lib/features/today/domain/due.dart`
- Test: `test/features/today/domain/due_test.dart`

**Interfaces:**
- Consumes: Task 2's `progressOf`, `Person.currentStepId` / `dueOn`; `findWorkflow` (`lib/features/workflows/domain/workflow.dart`); `searchKey` (`lib/features/contacts/domain/search_key.dart`).
- Produces: `typedef Due = ({Person person, OnStep step});` and `List<Due> dueToday(List<Person> people, List<Workflow> workflows, DateTime today)`.

- [ ] **Step 1: Write the failing test**

`test/features/today/domain/due_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/today/domain/due.dart';

import '../../workflows/fake_workflow_repository.dart';

final _workflows = FakeWorkflowRepository.samples();
final _today = DateTime(2026, 9, 29);

/// On Samples step 2 as the server returns them, due on [due].
Person _person(
  String id,
  String name, {
  DateTime? due,
  String? step = 'samples-2',
  DateTime? pausedAt,
  bool follows = true,
}) => Person(
  id: id,
  name: name,
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026),
  place: follows
      ? (workflowId: 'samples', atPosition: 2, lastTick: DateTime(2026, 9, 20))
      : null,
  currentStepId: follows ? step : null,
  dueOn: due,
  pausedAt: pausedAt,
);

void main() {
  test('due today and late stay; not yet due, paused, done and no workflow '
      'fall out', () {
    final due = dueToday(
      [
        _person('today', 'Today', due: _today),
        _person('late', 'Late', due: DateTime(2026, 9, 27)),
        _person('tomorrow', 'Tomorrow', due: DateTime(2026, 9, 30)),
        _person('paused', 'Paused', pausedAt: DateTime.utc(2026, 9, 1)),
        _person('done', 'Done', step: null),
        _person('none', 'None', follows: false),
      ],
      _workflows,
      _today,
    );

    expect([for (final row in due) row.person.id], ['late', 'today']);
    expect(due.first.step.step.label, 'Send the samples');
  });

  test('oldest first, then by name whatever the case', () {
    final due = dueToday(
      [
        _person('c', 'claire', due: DateTime(2026, 9, 28)),
        _person('b', 'Bruno', due: DateTime(2026, 9, 28)),
        _person('a', 'Anna', due: _today),
      ],
      _workflows,
      _today,
    );

    expect([for (final row in due) row.person.name], [
      'Bruno',
      'claire',
      'Anna',
    ]);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/today/domain/due_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:folo/features/today/domain/due.dart'`.

- [ ] **Step 3: Write `due.dart`**

```dart
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/domain/search_key.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

/// Someone worth a message today, and the step that says why.
typedef Due = ({Person person, OnStep step});

/// People whose step is due on or before [today], oldest first, then by name.
/// Paused, done, no workflow and not yet due fall out. The server decides the
/// day (`due_on`); this only compares it with the device's today.
List<Due> dueToday(
  List<Person> people,
  List<Workflow> workflows,
  DateTime today,
) {
  final due = [
    for (final person in people)
      if (progressOf(person, findWorkflow(workflows, person.place?.workflowId))
          case final OnStep step when !step.due.isAfter(today))
        (person: person, step: step),
  ];
  due.sort((a, b) {
    final byDay = a.step.due.compareTo(b.step.due);
    return byDay != 0
        ? byDay
        : searchKey(a.person.name).compareTo(searchKey(b.person.name));
  });
  return due;
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/today/domain/due_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/today/domain/due.dart test/features/today/domain/due_test.dart
git commit -m "feat(today): who is due today, oldest first (#58)"
```

### Task 4: The Today screen

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Rewrite: `lib/features/today/presentation/today_page.dart`
- Modify: `lib/features/today/presentation/today_hero.dart`
- Rewrite: `lib/features/today/presentation/today_preview.dart`
- Delete: `lib/features/today/domain/today_snapshot.dart`
- Rewrite: `test/features/today/today_page_test.dart`
- Modify: `test/app_test.dart`

**Interfaces:**
- Consumes: Task 3's `Due` / `dueToday`; Task 2's `PeopleController.completeStep(Person, OnStep, DateTime)` and `FakePeopleRepository`; existing `peopleProvider(email)`, `workflowsProvider(email)`, `accountProvider` (`lib/features/auth/data/auth_repository.dart`), `writePeople`, `refreshPeople`, `openContact` (`lib/features/contacts/presentation/contacts_page.dart`), `dueLabel` (`people_copy.dart`), `today()` (`lib/core/ui/pick_day.dart`), `pumpFolo` (`test/app/app_harness.dart`).
- Produces: `TodayPage`; `TodayView({required AsyncValue<List<Due>> due, required DateTime now, required String firstName, required void Function(Due) onTick, required void Function(Person) onOpen, required VoidCallback onRetry, required Future<void> Function() onRefresh, Set<String> busy = const {}, Widget? accountAction})`; `String greeting(AppLocalizations l10n, DateTime now, String firstName)`; `TodayHero({required String eyebrow, required String headline, bool compact = true})`.

Ruling against the spec: the spec names a `todayProvider`. Nothing but `TodayPage` would read it, and Retry needs the two source providers anyway, so the derivation is a `switch` in `TodayPage.build` instead. Same behaviour: data once both lists are there (a failed refresh keeps the last data), else the first error, else loading.

- [ ] **Step 1: The strings**

`lib/l10n/app_en.arb`: delete `todaySectionThisMonth`, `@todaySectionThisMonth`, `todaySectionRecent`, `@todaySectionRecent`. After `@todayEmptyBody`, add:

```json
  "todayDate": "{day}",
  "@todayDate": {
    "description": "Eyebrow above the Today greeting, shown uppercased: the weekday and the date, e.g. 'Monday, September 29'; the format follows the locale.",
    "placeholders": {
      "day": { "type": "DateTime", "format": "MMMMEEEEd" }
    }
  },
  "todayGreeting": "{part, select, morning{Good morning} afternoon{Good afternoon} other{Good evening}}",
  "@todayGreeting": {
    "description": "Today's title when the account has no first name. part is the time of day on the device: morning before noon, afternoon before 6 pm, evening after.",
    "placeholders": {
      "part": { "type": "String" }
    }
  },
  "todayGreetingNamed": "{part, select, morning{Good morning, {name}} afternoon{Good afternoon, {name}} other{Good evening, {name}}}",
  "@todayGreetingNamed": {
    "description": "Today's title, with the account's first name. part is the time of day on the device: morning before noon, afternoon before 6 pm, evening after.",
    "placeholders": {
      "part": { "type": "String" },
      "name": { "type": "String", "example": "Pauline" }
    }
  },
  "todayHeadline": "{count, plural, =1{One person is worth a message today} other{{count} people are worth a message today}}",
  "@todayHeadline": {
    "description": "The sentence in the Today hero: a sentence, not a number, so it never reads as a quota. count is everyone due today or late, including rows not shown yet.",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "todayReason": "{step} · {workflow}, step {index} of {total}",
  "@todayReason": {
    "description": "Line under a person's name on Today: the step to do, then the workflow and where they are in it, e.g. 'Send the samples · Samples, step 2 of 5'.",
    "placeholders": {
      "step": { "type": "String", "example": "Send the samples" },
      "workflow": { "type": "String", "example": "Samples" },
      "index": { "type": "int" },
      "total": { "type": "int" }
    }
  },
  "todayShowMore": "{count, plural, =1{And one more waiting} other{And {count} more waiting}}",
  "@todayShowMore": {
    "description": "Button under the first rows on Today; shows the rest in place. count is how many are not shown yet.",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "todayLoadFailed": "Couldn't load today.",
  "@todayLoadFailed": {
    "description": "Heading in place of Today when the contacts or the workflows could not be loaded. Above contactsLoadErrorBody and a Try again button."
  },
```

Run: `flutter gen-l10n` (or `flutter pub get`, which generates). Expected: no error; `app_fr.arb` untouched (`git diff --stat lib/l10n/app_fr.arb` empty).

- [ ] **Step 2: `TodayHero` loses the progress bar and the effort label**

`lib/features/today/presentation/today_hero.dart`: delete the `progress`, `progressLabel`, `effortLabel` parameters and fields, the `folo_progress_bar.dart` import, and the trailing `SizedBox(height: AppSpacing.md)` + `FoloProgressBar(...)` children. The constructor becomes:

```dart
  const TodayHero({
    required this.eyebrow,
    required this.headline,
    this.compact = true,
    super.key,
  });
```

The `Column` keeps the eyebrow, `SizedBox(height: AppSpacing.sm)` and the headline. If `FoloProgressBar` is now unused anywhere (`grep -rn FoloProgressBar lib test`), leave it: it is a design-system component with its own preview.

- [ ] **Step 3: Rewrite `today_page.dart`**

Replace the whole file:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/shell/app_shell.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/core/ui/action_item.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/core/ui/folo_top_bar.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/core/ui/section_header.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/contacts_page.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/today/domain/due.dart';
import 'package:folo/features/today/presentation/today_hero.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The home. Everything else in the product is support (design principle #1).
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  /// People whose tick is in flight: their button is gone, so a second tap
  /// can't tick the next step too.
  final Set<String> _busy = {};

  Future<void> _tick(Due due) async {
    final id = due.person.id;
    if (!_busy.add(id)) return;
    setState(() {});
    await writePeople(
      context,
      ref,
      (people) => people.completeStep(due.person, due.step, today()),
    );
    if (mounted) setState(() => _busy.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final book = peopleProvider(account?.email);
    final lists = workflowsProvider(account?.email);
    final people = ref.watch(book);
    final workflows = ref.watch(lists);

    return TodayView(
      // `.value` survives a failed refresh, so the rows stay on screen.
      due: switch ((people.value, workflows.value)) {
        (final everyone?, final all?) => AsyncData(
          dueToday(everyone, all, today()),
        ),
        _ when people.hasError => AsyncError(
          people.error!,
          people.stackTrace ?? StackTrace.empty,
        ),
        _ when workflows.hasError => AsyncError(
          workflows.error!,
          workflows.stackTrace ?? StackTrace.empty,
        ),
        _ => const AsyncLoading(),
      },
      now: DateTime.now(),
      firstName: account?.firstName ?? '',
      // With a sidebar, Settings is its account block instead.
      accountAction: context.screenSize.usesSideNavigation
          ? null
          : const AccountButton(),
      busy: _busy,
      onTick: (due) => unawaited(_tick(due)),
      onOpen: (person) => openContact(context, person.id),
      onRetry: () {
        if (people.hasError) ref.invalidate(book);
        if (workflows.hasError) ref.invalidate(lists);
      },
      onRefresh: () => refreshPeople(context, ref),
    );
  }
}

/// "Good morning, Pauline" from the device clock: morning before noon,
/// afternoon before 6 pm, evening after. Without a first name, no comma.
String greeting(AppLocalizations l10n, DateTime now, String firstName) {
  final part = now.hour < 12
      ? 'morning'
      : now.hour < 18
      ? 'afternoon'
      : 'evening';
  final name = firstName.trim();
  return name.isEmpty
      ? l10n.todayGreeting(part)
      : l10n.todayGreetingNamed(part, name);
}

/// The screen as a function of its inputs, so it can be previewed and tested
/// without providers. One column on every size.
class TodayView extends StatefulWidget {
  const TodayView({
    required this.due,
    required this.now,
    required this.firstName,
    required this.onTick,
    required this.onOpen,
    required this.onRetry,
    required this.onRefresh,
    this.busy = const {},
    this.accountAction,
    super.key,
  });

  final AsyncValue<List<Due>> due;

  /// The device clock: the date, the greeting, and which steps are late.
  final DateTime now;

  /// Empty when the account has none: the greeting goes without.
  final String firstName;

  /// Ids of people whose tick is in flight.
  final Set<String> busy;

  final void Function(Due due) onTick;
  final void Function(Person person) onOpen;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  /// Top-bar entry to Settings, where there is no sidebar to hold it.
  final Widget? accountAction;

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  /// Per `docs/design/responsive-design.md`: the priority column's width.
  static const double _column = 624;

  /// "And N more waiting" was tapped. Resets on leaving Today.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = context.screenSize.isDesktop;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _column),
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: ListView(
                // Pull to refresh works on a short list too.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: desktop
                    ? const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                        vertical: AppSpacing.xl,
                      )
                    : const EdgeInsets.all(AppSpacing.md),
                children: [
                  FoloTopBar(
                    eyebrow: l10n.todayDate(widget.now),
                    title: greeting(l10n, widget.now, widget.firstName),
                    large: desktop,
                    action: widget.accountAction,
                  ),
                  ...switch (widget.due) {
                    AsyncData(:final value) when value.isEmpty => const [
                      _UpToDate(),
                    ],
                    AsyncData(:final value) => _due(l10n, value, desktop),
                    AsyncError() => [_Failed(onRetry: widget.onRetry)],
                    _ => const [Center(child: CircularProgressIndicator())],
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _due(AppLocalizations l10n, List<Due> due, bool desktop) {
    final shown = _expanded ? due : due.take(desktop ? 6 : 5).toList();
    final now = widget.now;
    final day = DateTime(now.year, now.month, now.day);
    return [
      TodayHero(
        eyebrow: l10n.todayTitle,
        headline: l10n.todayHeadline(due.length),
        compact: !desktop,
      ),
      SizedBox(height: desktop ? AppSpacing.xl : AppSpacing.lg),
      SectionHeader(title: l10n.todaySectionPriority),
      for (final (index, row) in shown.indexed) ...[
        if (index > 0) const SizedBox(height: AppSpacing.ms),
        _row(l10n, row, day),
      ],
      if (shown.length < due.length) ...[
        const SizedBox(height: AppSpacing.ms),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => setState(() => _expanded = true),
            child: Text(l10n.todayShowMore(due.length - shown.length)),
          ),
        ),
      ],
    ];
  }

  Widget _row(AppLocalizations l10n, Due due, DateTime day) {
    final (:person, :step) = due;
    return ActionItem(
      name: person.name,
      reason: l10n.todayReason(
        step.step.label,
        step.workflow.name,
        step.index,
        step.total,
      ),
      // The accent chip only when a real date drives it: late.
      chip: step.due.isBefore(day)
          ? DateChip(dueLabel(l10n, step.due, day))
          : null,
      onOpen: () => widget.onOpen(person),
      onResolve: widget.busy.contains(person.id)
          ? null
          : () => widget.onTick(due),
      resolveLabel: l10n.nextStepMarkDone(step.step.label),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: l10n.todayLoadFailed,
      body: l10n.contactsLoadErrorBody,
      actionLabel: l10n.contactsRetry,
      onAction: onRetry,
    );
  }
}

class _UpToDate extends StatelessWidget {
  const _UpToDate();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.wb_twilight_rounded,
      title: l10n.todayEmptyTitle,
      body: l10n.todayEmptyBody,
    );
  }
}
```

- [ ] **Step 4: Delete the sample data**

```bash
git rm lib/features/today/domain/today_snapshot.dart
```

Run: `grep -rn "today_snapshot\|sampleToday\|TodaySnapshot\|todaySnapshotProvider" lib test`
Expected: only `today_preview.dart`, `today_page_test.dart` and `test/app_test.dart`, all rewritten below.

- [ ] **Step 5: The preview renders a fixed book on a fixed morning**

Replace `lib/features/today/presentation/today_preview.dart` (the five function names stay: `test/previews_test.dart` maps them to goldens):

```dart
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/today/domain/due.dart';
import 'package:folo/features/today/presentation/today_page.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:folo/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Today in both modes and both layouts, for `flutter widget-preview start`,
/// on a fixed morning so the goldens never follow the clock. Six people are
/// due: a phone shows five and "And one more waiting", a desktop all six.
/// Nothing in the app imports this file.
@Preview(group: 'Today', name: 'Mobile — light', size: Size(390, 844))
Widget todayMobileLight() => _app(AppTheme.light, _book);

@Preview(group: 'Today', name: 'Mobile — dark', size: Size(390, 844))
Widget todayMobileDark() => _app(AppTheme.dark, _book);

@Preview(group: 'Today', name: 'Desktop — light', size: Size(1440, 900))
Widget todayDesktopLight() => _app(AppTheme.light, _book);

@Preview(group: 'Today', name: 'Desktop — dark', size: Size(1440, 900))
Widget todayDesktopDark() => _app(AppTheme.dark, _book);

@Preview(group: 'Today', name: 'Empty — light', size: Size(390, 844))
Widget todayEmptyLight() => _app(AppTheme.light, const []);

final _now = DateTime(2026, 9, 29, 9);

final _samples = Workflow(
  id: 'samples',
  stage: Stage.prospect,
  name: 'Samples',
  isDefault: true,
  steps: const [
    WorkflowStep(id: 's1', position: 1, label: 'Send a first message', days: 0),
    WorkflowStep(id: 's2', position: 2, label: 'Send the samples', days: 1),
    WorkflowStep(id: 's3', position: 3, label: 'Ask how they liked them', days: 4),
  ],
);

Due _due(String name, int step, DateTime due) => (
  person: Person(
    id: name,
    name: name,
    stage: Stage.prospect,
    stageSince: DateTime.utc(2026, 9),
  ),
  step: OnStep(
    workflow: _samples,
    step: _samples.steps[step - 1],
    index: step,
    total: _samples.steps.length,
    due: due,
  ),
);

/// Oldest first, then by name, as `dueToday` sorts.
final _book = [
  _due('Sarah Martin', 2, DateTime(2026, 9, 26)),
  _due('Claire Dubois', 1, DateTime(2026, 9, 28)),
  _due('Julie Bernard', 1, DateTime(2026, 9, 29)),
  _due('Léa Petit', 2, DateTime(2026, 9, 29)),
  _due('Marie Lefèvre', 3, DateTime(2026, 9, 29)),
  _due('Nadia Roux', 1, DateTime(2026, 9, 29)),
];

Widget _app(ThemeData theme, List<Due> due) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // The preview is its own app: without the delegates, any component that
    // reads AppLocalizations throws here.
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: TodayView(
      due: AsyncData(due),
      now: _now,
      firstName: 'Pauline',
      onTick: (_) {},
      onOpen: (_) {},
      onRetry: () {},
      onRefresh: () async {},
    ),
  );
}
```

- [ ] **Step 6: `pumpFolo` can skip settling**

Today spins while the book or the workflows load, so a test that gates them before the app starts can't `pumpAndSettle`. `test/app/app_harness.dart`: add the parameter `bool settle = true,` after `FakeWorkflowRepository? workflows,`, update the doc comment's last sentence to "With [settle] false it pumps one frame, for a load gated on purpose.", and replace the final `await tester.pumpAndSettle();` with:

```dart
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
```

In `test/features/contacts/presentation/contacts_page_test.dart`, replace the body of `'workflows loading: a spinner in the card, the page works'`:

```dart
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples())
      ..gate = Completer<void>();
    people.store['p1'] = _marieOn(1);
    // Today spins too while the workflows load: nothing settles, pump by hand.
    final container = await pumpFolo(
      tester,
      size: _phone,
      people: people,
      activities: activities,
      workflows: workflows,
      settle: false,
    );
    container.read(routerProvider).go(Routes.contactLocation('p1'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.descendant(
        of: find.byType(NextStepSection),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.text('Marie Dupont'), findsWidgets);
    workflows.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Send a first message'), findsOneWidget);
```

- [ ] **Step 7: Rewrite the Today widget test**

Replace `test/features/today/today_page_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:folo/core/ui/action_item.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/contact_page.dart';
import 'package:folo/features/today/presentation/today_page.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_harness.dart';
import '../contacts/fake_people_repository.dart';
import '../workflows/fake_workflow_repository.dart';

const _phone = Size(390, 844);
// Tall enough that every row is built without scrolling; the cap follows the
// width alone.
const _tallPhone = Size(390, 1800);
const _tallDesktop = Size(1440, 1800);

const _markFirst = 'Mark "Send a first message" done';

/// On Samples at [at], last ticked [ago] days before today. Samples' steps
/// are due 0, 1, 4, 3 and 7 days after the last tick.
Person _on(String id, String name, {num at = 1, int ago = 0, DateTime? pausedAt}) =>
    Person(
      id: id,
      name: name,
      stage: Stage.prospect,
      stageSince: DateTime.utc(2026, 3, 4),
      place: (workflowId: 'samples', atPosition: at, lastTick: addDays(today(), -ago)),
      pausedAt: pausedAt,
    );

void main() {
  testWidgets('due today and late show, oldest first; not yet due and '
      'paused do not', (tester) async {
    final people = FakePeopleRepository([
      _on('p1', 'Anna'),
      _on('p2', 'Bruno', ago: 2),
      _on('p3', 'Chloé', at: 2),
      _on('p4', 'Dora', pausedAt: DateTime.utc(2026, 9)),
    ]);
    await pumpFolo(tester, size: _phone, people: people);

    expect(find.text('2 people are worth a message today'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
    expect(find.text('Chloé'), findsNothing);
    expect(find.text('Dora'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Bruno')).dy,
      lessThan(tester.getTopLeft(find.text('Anna')).dy),
    );
    expect(
      find.text('Send a first message · Samples, step 1 of 5'),
      findsNWidgets(2),
    );
    // The accent chip only where the date says something: late.
    expect(find.text('2 days late'), findsOneWidget);
    expect(find.text('Due today'), findsNothing);
  });

  testWidgets('a tick sends completeStep and the row leaves', (tester) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')]);
    await pumpFolo(tester, size: _phone, people: people);

    await tester.tap(find.byTooltip(_markFirst));
    await tester.pumpAndSettle();

    expect(people.calls, contains('completeStep(p1, samples-1)'));
    // The next step is due tomorrow.
    expect(find.text('Anna'), findsNothing);
    expect(find.text('You are up to date'), findsOneWidget);
  });

  testWidgets('a tick in flight hides that button: one step, not two', (
    tester,
  ) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')]);
    await pumpFolo(tester, size: _phone, people: people);
    people.gate = Completer<void>();

    await tester.tap(find.byTooltip(_markFirst));
    await tester.pump();
    expect(find.byTooltip(_markFirst), findsNothing);
    people.gate!.complete();
    people.gate = null;
    await tester.pumpAndSettle();

    expect(
      people.calls.where((call) => call.startsWith('completeStep')),
      hasLength(1),
    );
  });

  testWidgets('a failed tick says so and keeps the row', (tester) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')]);
    await pumpFolo(tester, size: _phone, people: people);
    people.failWith = PeopleFailure.network;

    await tester.tap(find.byTooltip(_markFirst));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('Anna'), findsOneWidget);
    expect(find.byTooltip(_markFirst), findsOneWidget);
  });

  testWidgets('five rows on a phone; And N more waiting shows the rest', (
    tester,
  ) async {
    final people = FakePeopleRepository([
      for (var i = 1; i <= 7; i++) _on('p$i', 'Person $i'),
    ]);
    await pumpFolo(tester, size: _tallPhone, people: people);

    expect(find.byType(ActionItem), findsNWidgets(5));
    expect(find.text('7 people are worth a message today'), findsOneWidget);
    await tester.tap(find.text('And 2 more waiting'));
    await tester.pumpAndSettle();

    expect(find.byType(ActionItem), findsNWidgets(7));
    expect(find.textContaining('more waiting'), findsNothing);
  });

  testWidgets('six rows on a desktop', (tester) async {
    final people = FakePeopleRepository([
      for (var i = 1; i <= 7; i++) _on('p$i', 'Person $i'),
    ]);
    await pumpFolo(tester, size: _tallDesktop, people: people);

    expect(find.byType(ActionItem), findsNWidgets(6));
    expect(find.text('And one more waiting'), findsOneWidget);
  });

  testWidgets('a spinner while loading, then the rows', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples())
      ..gate = Completer<void>();
    await pumpFolo(
      tester,
      size: _phone,
      people: FakePeopleRepository([_on('p1', 'Anna')]),
      workflows: workflows,
      settle: false,
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    workflows.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
  });

  testWidgets('a failed load says so; Try again loads Today', (tester) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')])
      ..failWith = PeopleFailure.network;
    await pumpFolo(tester, size: _phone, people: people);

    expect(find.text("Couldn't load today."), findsOneWidget);
    people.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
  });

  testWidgets('nobody due: up to date', (tester) async {
    await pumpFolo(tester, size: _phone, people: FakePeopleRepository());

    expect(find.text('You are up to date'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the rows', (tester) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')]);
    await pumpFolo(tester, size: _phone, people: people);
    people.failWith = PeopleFailure.network;

    await tester.fling(find.text('Anna'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
    expect(
      find.text("Couldn't refresh. You're seeing the last loaded list."),
      findsOneWidget,
    );
    expect(find.text("Couldn't load today."), findsNothing);
  });

  testWidgets('tapping a row opens the person', (tester) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')]);
    await pumpFolo(tester, size: _phone, people: people);

    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactPage), findsOneWidget);
  });

  test('the greeting follows the clock, with the first name if there is '
      'one', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    String at(int hour, int minute, [String name = 'Pauline']) =>
        greeting(l10n, DateTime(2026, 9, 29, hour, minute), name);

    expect(at(0, 0), 'Good morning, Pauline');
    expect(at(11, 59), 'Good morning, Pauline');
    expect(at(12, 0), 'Good afternoon, Pauline');
    expect(at(17, 59), 'Good afternoon, Pauline');
    expect(at(18, 0), 'Good evening, Pauline');
    expect(at(9, 0, ''), 'Good morning');
    expect(at(9, 0, '  '), 'Good morning');
  });
}
```

If `'2 days late'` is not what `dueLabel` renders for two days, read `nextStepLate` in `app_en.arb` (`{days, plural, =1{1 day late} other{{days} days late}}`) — it is.

- [ ] **Step 8: `app_test` stops expecting the sample greeting**

`test/app_test.dart`: delete the `today_snapshot.dart` import; add `import 'package:folo/features/today/presentation/today_page.dart';`, `import 'package:material_ui/material_ui.dart';` and `import 'app/app_harness.dart';`. Replace the `'a restored session lands on Today'` test:

```dart
  testWidgets('a restored session lands on Today', (tester) async {
    await pumpFolo(tester, size: const Size(390, 844));

    expect(find.byType(TodayPage), findsOneWidget);
    // "Good morning, Pauline", or afternoon, or evening: the clock decides.
    expect(find.textContaining('Pauline'), findsOneWidget);
  });
```

- [ ] **Step 9: Run everything**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all tests pass except the five `today_*` goldens in `test/previews_test.dart`, which fail on the new picture (they compare on Linux only; on macOS they are skipped — then everything passes). Do not regenerate goldens locally.

Run: `grep -rn "todaySectionThisMonth\|todaySectionRecent\|sampleToday\|progressLabel\|effortLabel" lib test`
Expected: no output.

If any other test that calls `pumpFolo` now times out in `pumpAndSettle`, it gated the people or workflows before the app started: give it `settle: false` as in Step 6.

- [ ] **Step 10: Commit**

```bash
git add -A lib/features/today lib/l10n/app_en.arb test/features/today test/app test/app_test.dart test/features/contacts/presentation/contacts_page_test.dart
git commit -m "feat(today): suggest the people whose step is due (#58)"
```

### Task 5: Docs — Today as built, workflow rules in Postgres

**Files:**
- Modify: `docs/architecture.md` (Backend — Supabase)
- Modify: `docs/design/screens.md` (§1 Today)

**Interfaces:** none. Prose only.

- [ ] **Step 1: Architecture**

In `docs/architecture.md`, Backend — Supabase, replace the bullet:

```markdown
- A calendar day is `date`, an instant is `timestamptz`. "Today" is computed
  on the device, never on the server.
```

with:

```markdown
- A calendar day is `date`, an instant is `timestamptz`. "Today" is computed
  on the device, never on the server.
- A rule every reader must agree on lives in Postgres, once (#58). Where a
  person is in their workflow and when that step is due are the computed
  fields `current_step_id(person)` and `due_on(person)`, which PostgREST
  selects as `*, current_step_id, due_on`; `complete_step` moves on by the
  same rule and refuses a step that is no longer current. The device compares
  `due_on` with its own today and never recomputes a step, so Today, the
  contact page and a future push job cannot disagree. The test fake in
  `test/features/workflows/server_rule.dart` is the only other copy; the
  pgTAP tests pin the real one.
```

- [ ] **Step 2: Screens**

In `docs/design/screens.md`, replace §1 from `**Mobile**` up to (not including) `## 2. Contacts` with:

```markdown
**Every size** — one column, 624px at most. Desktop keeps the sidebar and
uses the large top bar; mobile keeps the account button and the bottom nav.

Top bar (`TUESDAY, SEPTEMBER 29` / "Good morning, Pauline") → TodayHero →
`PRIORITY` + the people whose workflow step is due today or late.

The greeting follows the device clock: morning until noon, afternoon until
6 pm, evening after. Without a first name it is "Good morning" alone.

The hero says *"Three people are worth a message today"* — a sentence, not a
number, so it cannot read as a quota. It counts everyone due, not only the
rows shown.

Each ActionItem is a person: their name, then the reason it exists —
"Send the samples · Samples, step 2 of 5". The accent chip appears only when
the step is late ("2 days late"). The round button ticks the step, exactly as
on the contact page; the row then leaves, or shows the next step if that one
is due too. Tapping the row opens the person.

Oldest first. Five rows on a phone or tablet, six on desktop, then
`And 2 more waiting`, which shows the rest in place. Pull to refresh on every
size.

Loading is a spinner; a failed load says "Couldn't load today." with Try
again; nobody due is "You are up to date".

Goal, stats, "You talked to" and the desktop right column are gone until
their features exist (goals, activity summaries). Nothing on Today is sample
data.
```

- [ ] **Step 3: Commit**

```bash
git add docs/architecture.md docs/design/screens.md
git commit -m "docs: Today as built, workflow rules in Postgres (#58)"
```

---

## Afterwards (the user, not the implementer)

1. The user pushes the branch: `! git push -u origin feature/58-today-due-steps`.
2. Goldens through CI, never locally: `gh workflow run CI --ref feature/58-today-due-steps -f update-goldens=true`, then `gh run download <id> -n goldens -D test/goldens`, review the five `today_*` pictures, commit `test: Today goldens (#58)`.
3. The user runs `supabase db push` with the VPN off. Until then the hosted app's reads fail: the columns `current_step_id` / `due_on` don't exist yet. Push the migration before shipping a build.
4. PR from the template, `Closes #58`.
5. Memory `workflows-59-carryovers.md`: drop the stale-tick item, fixed here.
