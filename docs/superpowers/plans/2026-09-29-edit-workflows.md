# Edit workflows in Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Users rename, reorder, add and remove steps, create and delete workflows and pick each stage's default from Settings → Workflows. The defaults are seeded once per account, ever.

**Architecture:** One migration adds a `workflow_seeded` marker, replaces `seed_workflows` so that it checks the marker, and adds a `set_default` RPC. Plain writes go through the existing RLS. `WorkflowRepository` gains eight writes. `WorkflowsController` seeds on every build and gains a generic `edit`, which writes and then reloads. Nothing is optimistic. The screens are pure views: `WorkflowsView`, `WorkflowEditorView` and `StepForm`, fed data and callbacks. Thin `ConsumerWidget`s connect them to `editWorkflows`, and the Settings list and its right pane host them.

**Tech Stack:** Flutter 3.47, material_ui 1.4.0, flutter_riverpod 3.4 (no codegen), go_router, supabase_flutter, Postgres and pgTAP.

**Spec:** `docs/superpowers/specs/2026-09-29-edit-workflows-design.md` (binding). Read it with this plan.

## Global Constraints

- Imports are `package:folo/...` only. Material comes from `package:material_ui/material_ui.dart`, never `package:flutter/material.dart`. `package:flutter/services.dart` is allowed where a class lives only there (e.g. `FilteringTextInputFormatter`).
- Use theme values only: `Theme.of(context).colorScheme`, `FoloColors.of(context)`, `AppSpacing.*`, `AppRadii.*` and `AppTypography.*`. Never hard-code a colour, radius, font size or spacing. Branch on `context.screenSize` (`isMobile` / `isDesktop`), never on pixel widths.
- EN strings go only in `lib/l10n/app_en.arb`, each with an `@key` description. Never touch `app_fr.arb`.
- No MLM, "recruit" or "lead" wording in copy or names.
- Add routes to `lib/app/router/routes.dart` first. No path literals in widgets.
- Schema changes go only through `supabase migration new edit_workflows`. **Do not run `supabase db push`. The user runs it.**
- No new dependencies. `pubspec.yaml` is untouched.
- Commits follow Conventional Commits and end with `(#59)`, e.g. `feat(workflows): edit steps in Settings (#59)`.
- Quality gate before every commit, run from the repo root: `dart format .`, then `flutter analyze` (must print "No issues found!"), then `flutter test`, which must pass.
- Goldens come only from CI, never from a local run. `test/previews_test.dart` compares pixels on Linux only, so locally (macOS) a new `@Preview` passes as long as it renders without an exception. On CI Linux, the `verify` job fails for each new preview until its PNG exists. The PNGs are generated after the branch is pushed, through the README procedure *Golden tests*. Never commit a locally made PNG.
- `supabase test db` needs a local stack (`supabase db start`, which needs Docker). A task runs it when one is available. Otherwise it says so in its report, and CI's `migrations` job is the check.
- Every repository method throws `PeopleFailure` and nothing else, through `guardPeople`.

## Review Focus

1. **Double submit.** Two taps on Create (New workflow) or Save (step sheet) before a frame rebuilds must produce exactly one write. Tests: Task 3, "a second tap on Create while creating writes nothing more"; Task 4, "a second tap on Save while saving writes nothing more".
2. **Out-of-range or empty days.** "400" or an empty days field must be refused with "Enter a number from 0 to 365." and nothing written. Non-digits cannot be typed. Test: Task 4, "days must be 0 to 365".
3. **Whitespace names.** "   " is refused in New workflow. "  Weekend  " is created as "Weekend". In the editor, a whitespace-only name restores the saved name. Tests: Task 3, "a blank name is refused, and a name is trimmed" and "an empty name puts the saved one back without writing".
4. **Deleted elsewhere while open.** A reload that no longer has the workflow shows "This workflow isn't here anymore" with a working "Back to workflows", and never throws. Test: Task 3, "a workflow deleted elsewhere says so".
5. **A move while one is in flight.** A second reorder before the first answer must be ignored, not sent with stale positions. Test: Task 5, "a move while one is saving is ignored".

---

### Task 1: Migration — seed once, `set_default` — and pgTAP

**Files:**
- Create: `supabase/migrations/<timestamp>_edit_workflows.sql` (by `supabase migration new edit_workflows`)
- Create: `supabase/tests/edit_workflows_test.sql`

**Interfaces:**
- Consumes: `public.workflow`, `public.workflow_step`, `public.person`, `public.current_step_id(public.person)` (migrations `20260929085602_workflows.sql` and `20260929132701_today_due_steps.sql`).
- Produces:
  - table `public.workflow_seeded(owner_id uuid pk, seeded_at timestamptz)`;
  - `public.seed_workflows(p_lang text, p_today date) returns void`, with the same signature and privileges but seeding once per account;
  - `public.set_default(p_workflow uuid, p_on boolean) returns void`. It raises `P0002` for an unknown or foreign id. Task 2 calls it as `rpc('set_default', params: {'p_workflow': id, 'p_on': on})`.

- [ ] **Step 1: Write the failing pgTAP test**

Create `supabase/tests/edit_workflows_test.sql`:

```sql
-- Editing workflows (#59): seeded once per account, ever; set_default moves a
-- stage's default; edits reach people through current_step_id.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

-- As A.
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Sarah', 'prospect');

-- 1-3: the marker.
select lives_ok(
  $$ select public.seed_workflows('en', '2026-09-29') $$,
  'the first seed runs'
);
select is(
  (select count(*)::int from public.workflow_seeded), 1,
  'the seed writes the marker'
);
select public.seed_workflows('en', '2026-09-29');
select is(
  (select count(*)::int from public.workflow), 5,
  'a second seed no-ops'
);

-- 4-8: set_default.
select lives_ok(
  $$ select public.set_default(
       (select id from public.workflow where name = 'Health professionals'),
       true) $$,
  'set_default on runs'
);
select results_eq(
  $$ select name from public.workflow
     where stage = 'prospect' and is_default $$,
  $$ values ('Health professionals'::text) $$,
  'on moves the stage''s default'
);
select is(
  (select count(*)::int from public.workflow where is_default), 3,
  'the other stages keep their default'
);
select lives_ok(
  $$ select public.set_default(
       (select id from public.workflow where name = 'Health professionals'),
       false) $$,
  'set_default off runs'
);
select is(
  (select count(*)::int from public.workflow
    where stage = 'prospect' and is_default), 0,
  'off leaves the stage without a default'
);

-- 9: the seed started Sarah on Samples at position 1. Moving that step
-- after the next one leaves her on what now sits at her place.
update public.workflow_step set position = 2.5
  where label = 'Send a first message';
select is(
  (select s.label from public.person p
     join public.workflow_step s on s.id = public.current_step_id(p)
    where p.id = '00000000-0000-0000-0000-0000000000a1'),
  'Send the samples',
  'moving the current step moves the person on'
);

-- 10: unknown id.
select throws_ok(
  $$ select public.set_default('00000000-0000-0000-0000-0000000000ff', true) $$,
  'P0002', null,
  'an unknown workflow raises P0002'
);

-- A workflow with a known id, for B.
insert into public.workflow (id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'team', 'Own');

-- As B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';

-- 11-13.
select throws_ok(
  $$ select public.set_default('00000000-0000-0000-0000-0000000000f1', true) $$,
  'P0002', null,
  'another user''s workflow raises P0002'
);
select is(
  (select count(*)::int from public.workflow_seeded), 0,
  'another user''s marker is hidden'
);
select throws_ok(
  $$ insert into public.workflow_seeded (owner_id)
     values ('00000000-0000-0000-0000-00000000000a') $$,
  '42501', null,
  'a marker cannot be written for another user'
);

-- Back as A.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- 14.
select is(
  (select is_default from public.workflow
    where id = '00000000-0000-0000-0000-0000000000f1'), false,
  'the refused call changed nothing'
);

-- 15: deleting a workflow.
delete from public.workflow where name = 'Samples';
select is(
  (select count(*)::int from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'
      and workflow_id is null), 1,
  'deleting a workflow clears its people''s workflow_id'
);

-- 16: the #57 carry-over.
delete from public.workflow;
select public.seed_workflows('en', '2026-09-29');
select is(
  (select count(*)::int from public.workflow), 0,
  'after deleting every workflow, seed still no-ops'
);

-- 17.
select throws_ok(
  'delete from public.workflow_seeded', '42501', null,
  'the marker cannot be deleted'
);

-- 18: the backfill. Tests run on a fresh database, where the migration had
-- no workflow to backfill; this pins the invariant it establishes.
reset role;
select is(
  (select count(*)::int from (select distinct owner_id from public.workflow) w
    where not exists (
      select 1 from public.workflow_seeded s where s.owner_id = w.owner_id)),
  0,
  'every owner with workflows has a marker'
);

-- 19-20: as anon.
set local role anon;
set local request.jwt.claims = '{"role": "anon"}';

select throws_ok(
  $$ select public.set_default('00000000-0000-0000-0000-0000000000f1', true) $$,
  '42501', null,
  'anon cannot call set_default'
);
select throws_ok(
  'select * from public.workflow_seeded', '42501', null,
  'anon cannot read the marker'
);

reset role;

-- 21.
select table_privs_are(
  'public', 'workflow_seeded', 'authenticated',
  ARRAY['SELECT', 'INSERT'],
  'authenticated has only SELECT, INSERT on workflow_seeded'
);

select * from finish();
rollback;
```

- [ ] **Step 2: Run it to verify it fails**

If Docker is running: `supabase db start` (or `supabase db reset` if the stack is already up), then `supabase test db`.
Expected: `edit_workflows_test.sql` fails with `relation "public.workflow_seeded" does not exist`. If no local stack is available, write that down for the report and continue.

- [ ] **Step 3: Create the migration**

Run: `supabase migration new edit_workflows`. It prints the path of the new empty file. Write the following into it. `seed_workflows` is replaced in full: it is the body from `20260929085602_workflows.sql` with the check changed and the marker insert added. `create or replace` keeps its grants.

```sql
-- Editing workflows (#59): the defaults are seeded once per account, ever,
-- and a stage's default is switched in one call. Plain edits go through the
-- RLS of #57; current_step_id and due_on (#58) carry them to people.

create table public.workflow_seeded (
  owner_id uuid primary key default auth.uid()
    references auth.users on delete cascade,
  seeded_at timestamptz not null default now()
);

alter table public.workflow_seeded enable row level security;

create policy workflow_seeded_select_own on public.workflow_seeded
  for select to authenticated using (owner_id = (select auth.uid()));
create policy workflow_seeded_insert_own on public.workflow_seeded
  for insert to authenticated with check (owner_id = (select auth.uid()));

-- Written once, never changed or removed while the account exists.
revoke all on public.workflow_seeded from anon, authenticated;
grant select, insert on public.workflow_seeded to authenticated;

-- Everyone seeded before this migration.
insert into public.workflow_seeded (owner_id)
  select distinct owner_id from public.workflow;

-- Same as #57, except that it asks the marker rather than "any workflow", so
-- an account that deleted everything is not given the defaults back.
create or replace function public.seed_workflows(p_lang text, p_today date)
returns void
language plpgsql security invoker set search_path = '' as $$
declare
  fr constant boolean := p_lang = 'fr';
  w record;
  new_id uuid;
begin
  -- Two devices seeding at once: the second waits, then finds the marker.
  perform pg_advisory_xact_lock(hashtext((select auth.uid())::text));
  if exists (
    select 1 from public.workflow_seeded
    where owner_id = (select auth.uid())
  ) then
    return;
  end if;

  for w in
    select * from (values
      ('prospect'::public.person_stage, true,
       case when fr then 'Échantillons' else 'Samples' end,
       case when fr then
         '[["Envoyer un premier message",0],["Envoyer les échantillons",1],["Échantillons reçus",4],["Demander comment ça s''est passé",3],["Relancer",7]]'
       else
         '[["Send a first message",0],["Send the samples",1],["Samples arrived",4],["Ask how the samples went",3],["Follow up",7]]'
       end::jsonb),
      ('prospect', false,
       case when fr then 'Professionnels de santé' else 'Health professionals' end,
       case when fr then
         '[["Se présenter",0],["Partager une fiche produit",2],["Proposer un kit d''échantillons",5],["Relancer",7]]'
       else
         '[["Introduce yourself",0],["Share a product sheet",2],["Offer a sample kit",5],["Follow up",7]]'
       end::jsonb),
      ('customer', true,
       case when fr then 'Nouveau client' else 'New customer' end,
       case when fr then
         '[["Remercier pour la commande",0],["Commande reçue",5],["Prendre des nouvelles des produits",14],["Proposer un réassort régulier",21]]'
       else
         '[["Thank them for the order",0],["Order arrived",5],["Check in on the products",14],["Suggest a refill routine",21]]'
       end::jsonb),
      ('customer', false,
       case when fr then 'Point réassort' else 'Refill check-in' end,
       case when fr then
         '[["Demander où en sont les réserves",25],["Aider pour la prochaine commande",3]]'
       else
         '[["Ask how supplies are going",25],["Help with the next order",3]]'
       end::jsonb),
      ('team', true,
       case when fr then 'Premiers pas' else 'Getting started' end,
       case when fr then
         '[["Appel de bienvenue",0],["Appel de déballage",5],["Première formation",3],["Premier objectif ensemble",7],["Point à deux semaines",14]]'
       else
         '[["Welcome call",0],["Unboxing call",5],["First training",3],["First goal together",7],["Two-week check-in",14]]'
       end::jsonb)
    ) as t(stage, is_default, name, steps)
  loop
    insert into public.workflow (stage, name, is_default)
      values (w.stage, w.name, w.is_default)
      returning id into new_id;
    insert into public.workflow_step (workflow_id, position, label, days)
      select new_id, s.ord, s.value ->> 0, (s.value ->> 1)::int
      from jsonb_array_elements(w.steps) with ordinality as s(value, ord);
  end loop;

  update public.person p
    set workflow_id = wf.id, at_position = 1, last_tick = p_today
    from public.workflow wf
    where wf.stage = p.stage and wf.is_default and p.workflow_id is null;

  insert into public.workflow_seeded default values;
end $$;

-- On: the stage's default, instead of any other (the other is cleared first,
-- so workflow_default_idx never sees two). Off: the stage has none.
create function public.set_default(p_workflow uuid, p_on boolean) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person_stage;
begin
  select stage into target from public.workflow where id = p_workflow;
  if target is null then
    raise exception 'workflow % not found', p_workflow using errcode = 'P0002';
  end if;
  if p_on then
    update public.workflow set is_default = false
      where stage = target and is_default and id <> p_workflow;
  end if;
  update public.workflow set is_default = p_on where id = p_workflow;
end $$;

revoke execute on function public.set_default(uuid, boolean) from public, anon;
grant execute on function public.set_default(uuid, boolean) to authenticated;
```

- [ ] **Step 4: Run the tests to verify they pass**

If a local stack is available: `supabase db reset && supabase db lint --fail-on error && supabase test db`.
Expected: every file passes, including `workflow_test.sql`: its "seeding twice" and French-seed tests still hold, because B has no marker when it seeds. If no stack is available, say so in the report. CI's `migrations` job runs the same three commands.

- [ ] **Step 5: Commit**

Run the quality gate (`dart format .`, `flutter analyze`, `flutter test`). Dart is unchanged, so it must already be green.

```bash
git add supabase/migrations/*_edit_workflows.sql supabase/tests/edit_workflows_test.sql
git commit -m "feat(db): seed workflows once per account, set a stage's default (#59)"
```

Report to the user (do not run it): after the migration is pushed with `supabase db push`, this query, run in the SQL editor, must return 0. It checks the backfill that pgTAP cannot reach:

```sql
select count(*) from (select distinct owner_id from public.workflow) w
where not exists (select 1 from public.workflow_seeded s where s.owner_id = w.owner_id);
```

---
### Task 2: Repository writes, `positionAt`, controller `edit` and seed-always, fake

**Files:**
- Modify: `lib/features/workflows/domain/workflow.dart` (append `positionAt`)
- Modify: `lib/features/workflows/data/workflow_repository.dart` (eight writes)
- Modify: `lib/features/workflows/presentation/workflows_controller.dart` (`build`, `edit`, `editWorkflows`)
- Modify: `test/features/workflows/fake_workflow_repository.dart` (writes, seed once)
- Create: `test/features/workflows/domain/workflow_test.dart`
- Modify: `test/features/workflows/presentation/workflows_controller_test.dart`
- Modify: `test/features/contacts/presentation/add_person_sheet_test.dart:38`

**Interfaces:**
- Consumes: `set_default` RPC (Task 1); `guardPeople`, `dayColumn` (`lib/features/contacts/data/people_repository.dart`); `workflowFromRow`; `peopleProvider`; `accountProvider`.
- Produces (later tasks rely on these exact names):
  - `num positionAt(List<WorkflowStep> steps, int index)` in `workflow.dart`
  - `WorkflowRepository`:
    - `Future<Workflow> create(Stage stage, String name)`
    - `Future<void> rename(String id, String name)`
    - `Future<void> delete(String id)`
    - `Future<void> setDefault(String id, bool on)`
    - `Future<void> addStep(String workflowId, {required String label, required int days, String? note, required num position})`
    - `Future<void> updateStep(String stepId, {required String label, required int days, String? note})`
    - `Future<void> moveStep(String stepId, num position)`
    - `Future<void> removeStep(String stepId)`
  - `Future<T> WorkflowsController.edit<T>(Future<T> Function(WorkflowRepository repository) write)`
  - `Future<T> editWorkflows<T>(WidgetRef ref, Future<T> Function(WorkflowRepository repository) write)`, top level in `workflows_controller.dart`
  - Fake call strings, which tests assert:
    - `create(prospect, Weekend)`, `rename(samples, Tasters)`, `delete(samples)`, `setDefault(health, true)`;
    - `addStep(samples, Say thanks, 2, 6)`, `updateStep(samples-2, Send the kit, 3)`, `moveStep(samples-1, 2.5)`, `removeStep(samples-2)`;
    - `seed(en)`, `list()`.
  - Fake ids: `create` gives `new-1`, `new-2`, …; `addStep` gives `step-1`, ….

- [ ] **Step 1: Write the failing `positionAt` test**

Create `test/features/workflows/domain/workflow_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

List<WorkflowStep> _at(List<num> positions) => [
  for (final position in positions)
    WorkflowStep(id: '$position', position: position, label: 'x', days: 0),
];

void main() {
  test('dropped first: one before the first', () {
    expect(positionAt(_at([2, 3]), 0), 1);
  });

  test('dropped in the middle: the midpoint of its neighbours', () {
    expect(positionAt(_at([1, 3, 4]), 1), 2);
  });

  test('dropped last: one past the last', () {
    expect(positionAt(_at([1, 2.5]), 2), 3.5);
  });

  test('nothing else: 1', () {
    expect(positionAt(const [], 0), 1);
  });

  test('between adjacent integers: the half', () {
    expect(positionAt(_at([1, 2]), 1), 1.5);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/workflows/domain/workflow_test.dart`
Expected: FAIL with a compile error, `Method not found: 'positionAt'`.

- [ ] **Step 3: Implement `positionAt`**

Append to `lib/features/workflows/domain/workflow.dart`:

```dart
/// The position for a step dropped at [index] among [steps] (sorted, the
/// moved step already taken out): the midpoint of its new neighbours, or one
/// past either end. An empty list gives 1.
// ponytail: halving runs out of double precision after ~50 drops into the
// same gap; the unique (workflow_id, position) then refuses the move. Renumber
// the workflow's steps if that ever happens for real.
num positionAt(List<WorkflowStep> steps, int index) {
  if (steps.isEmpty) return 1;
  if (index <= 0) return steps.first.position - 1;
  if (index >= steps.length) return steps.last.position + 1;
  return (steps[index - 1].position + steps[index].position) / 2;
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/workflows/domain/workflow_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Add the repository writes**

In `lib/features/workflows/data/workflow_repository.dart`, update the doc of `seed` and add the writes after it, inside the class:

```dart
  /// The default workflows in [lang], once per account, ever: the server
  /// no-ops after the first time. Also starts everyone without a workflow on
  /// their stage's default.
  Future<void> seed(String lang, DateTime today) => guardPeople(() async {
    await _client.rpc<void>(
      'seed_workflows',
      params: {'p_lang': lang, 'p_today': dayColumn(today)},
    );
  });

  /// A new workflow with no steps, not the default.
  Future<Workflow> create(Stage stage, String name) => guardPeople(() async {
    final row = await _client
        .from('workflow')
        .insert({'stage': stage.name, 'name': name})
        .select('*, workflow_step(*)')
        .single();
    return workflowFromRow(row);
  });

  Future<void> rename(String id, String name) => guardPeople(() async {
    await _client.from('workflow').update({'name': name}).eq('id', id);
  });

  /// Its steps go with it; its people are left with no workflow.
  Future<void> delete(String id) => guardPeople(() async {
    await _client.from('workflow').delete().eq('id', id);
  });

  /// On: the default of its stage, instead of any other. Off: the stage has
  /// none.
  Future<void> setDefault(String id, bool on) => guardPeople(() async {
    await _client.rpc<void>(
      'set_default',
      params: {'p_workflow': id, 'p_on': on},
    );
  });

  /// [position] from `positionAt`.
  Future<void> addStep(
    String workflowId, {
    required String label,
    required int days,
    String? note,
    required num position,
  }) => guardPeople(() async {
    await _client.from('workflow_step').insert({
      'workflow_id': workflowId,
      'position': position,
      'label': label,
      'days': days,
      'note': note,
    });
  });

  Future<void> updateStep(
    String stepId, {
    required String label,
    required int days,
    String? note,
  }) => guardPeople(() async {
    await _client
        .from('workflow_step')
        .update({'label': label, 'days': days, 'note': note})
        .eq('id', stepId);
  });

  /// People follow the position, not the step: see `current_step_id`.
  Future<void> moveStep(String stepId, num position) => guardPeople(() async {
    await _client
        .from('workflow_step')
        .update({'position': position})
        .eq('id', stepId);
  });

  Future<void> removeStep(String stepId) => guardPeople(() async {
    await _client.from('workflow_step').delete().eq('id', stepId);
  });
```

The screens trim names, labels and notes before calling (Tasks 3–5). The repository sends what it is given. Its writes need a live client, so like `list` and `seed` they have no unit test. The fake and the widget tests pin the callers, and pgTAP pins the server.

- [ ] **Step 6: Make the fake implement the writes and seed once**

In `test/features/workflows/fake_workflow_repository.dart`:

1. Change the constructor and add a flag:

```dart
  FakeWorkflowRepository([Iterable<Workflow> workflows = const []]) {
    store.addAll(workflows);
    // Started with workflows: already seeded, as the server would say.
    _seeded = store.isNotEmpty;
  }

  bool _seeded = false;
  var _next = 0;
```

2. Replace `seed`:

```dart
  /// Like the RPC: seeds once, ever; a no-op afterwards, even with no
  /// workflow left. It does not start people; tests that need a place set it
  /// on the person.
  @override
  Future<void> seed(String lang, DateTime today) async {
    calls.add('seed($lang)');
    final failure = seedFailWith ?? failWith;
    final wait = seedGate ?? gate;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
    if (_seeded) return;
    _seeded = true;
    store.addAll(samples());
  }
```

3. Add the writes and two helpers before `samples()`. Add `import 'package:folo/features/contacts/domain/people_failure.dart';` to the imports.

```dart
  @override
  Future<Workflow> create(Stage stage, String name) async {
    await _record('create(${stage.name}, $name)');
    final workflow = Workflow(
      id: 'new-${++_next}',
      stage: stage,
      name: name,
      isDefault: false,
      steps: const [],
    );
    store.add(workflow);
    return workflow;
  }

  @override
  Future<void> rename(String id, String name) async {
    await _record('rename($id, $name)');
    _change(id, (workflow) => _copy(workflow, name: name));
  }

  @override
  Future<void> delete(String id) async {
    await _record('delete($id)');
    store.removeWhere((workflow) => workflow.id == id);
  }

  /// Like the RPC: on clears the stage's other default; unknown fails.
  @override
  Future<void> setDefault(String id, bool on) async {
    await _record('setDefault($id, $on)');
    final target = findWorkflow(store, id);
    if (target == null) throw PeopleFailure.unknown;
    for (final (index, workflow) in store.indexed.toList()) {
      if (workflow.id == id) {
        store[index] = _copy(workflow, isDefault: on);
      } else if (on && workflow.stage == target.stage && workflow.isDefault) {
        store[index] = _copy(workflow, isDefault: false);
      }
    }
  }

  @override
  Future<void> addStep(
    String workflowId, {
    required String label,
    required int days,
    String? note,
    required num position,
  }) async {
    await _record('addStep($workflowId, $label, $days, $position)');
    _change(
      workflowId,
      (workflow) => _copy(
        workflow,
        steps: [
          ...workflow.steps,
          WorkflowStep(
            id: 'step-${++_next}',
            position: position,
            label: label,
            days: days,
            note: note,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> updateStep(
    String stepId, {
    required String label,
    required int days,
    String? note,
  }) async {
    await _record('updateStep($stepId, $label, $days)');
    _changeStep(
      stepId,
      (step) => WorkflowStep(
        id: step.id,
        position: step.position,
        label: label,
        days: days,
        note: note,
      ),
    );
  }

  @override
  Future<void> moveStep(String stepId, num position) async {
    await _record('moveStep($stepId, $position)');
    _changeStep(
      stepId,
      (step) => WorkflowStep(
        id: step.id,
        position: position,
        label: step.label,
        days: step.days,
        note: step.note,
      ),
    );
  }

  @override
  Future<void> removeStep(String stepId) async {
    await _record('removeStep($stepId)');
    _changeStep(stepId, (_) => null);
  }

  void _change(String id, Workflow Function(Workflow workflow) change) {
    final index = store.indexWhere((workflow) => workflow.id == id);
    if (index >= 0) store[index] = change(store[index]);
  }

  /// A null from [change] removes the step.
  void _changeStep(
    String stepId,
    WorkflowStep? Function(WorkflowStep step) change,
  ) {
    final index = store.indexWhere(
      (workflow) => workflow.steps.any((step) => step.id == stepId),
    );
    if (index < 0) return;
    final workflow = store[index];
    store[index] = _copy(
      workflow,
      steps: [
        for (final step in workflow.steps)
          if (step.id != stepId) step else ?change(step),
      ],
    );
  }

  static Workflow _copy(
    Workflow workflow, {
    String? name,
    bool? isDefault,
    List<WorkflowStep>? steps,
  }) => Workflow(
    id: workflow.id,
    stage: workflow.stage,
    name: name ?? workflow.name,
    isDefault: isDefault ?? workflow.isDefault,
    steps: steps ?? workflow.steps,
  );
```

(`?change(step)` is a null-aware element. The SDK floor is ^3.13, so it is available.)

- [ ] **Step 7: Update the controller tests and write the failing ones**

In `test/features/workflows/presentation/workflows_controller_test.dart`, add `import 'package:folo/features/workflows/domain/workflow.dart';`. Then change the three existing expectations and add three tests:

```dart
  test('a seeded account seeds (the server no-ops), then lists', () async {
    final world = _world(
      FakeWorkflowRepository(FakeWorkflowRepository.samples()),
    );

    final list = await world.container.read(
      workflowsProvider('p@example.com').future,
    );

    expect(list, hasLength(5));
    expect(world.workflows.calls, ['seed(en)', 'list()']);
  });
```

That test replaces "a seeded account lists and does not seed". In "an empty account seeds once, lists again, reloads the book", the expectation becomes:

```dart
    expect(world.workflows.calls, ['seed(fr)', 'list()']);
```

In "a failed seed is an error, and a retry seeds again", it becomes:

```dart
    expect(world.workflows.calls, ['seed(en)']);
```

New tests, added inside `main()`:

```dart
  test('an account that deleted everything is not seeded again', () async {
    final workflows = FakeWorkflowRepository();
    final world = _world(workflows);
    final provider = workflowsProvider('p@example.com');
    world.container.listen(provider, (_, _) {});
    await world.container.read(provider.future);

    for (final workflow in [...workflows.store]) {
      await workflows.delete(workflow.id);
    }
    world.container.invalidate(provider);

    expect(await world.container.read(provider.future), isEmpty);
  });

  test('edit writes, then reloads the workflows and the people', () async {
    final world = _world(
      FakeWorkflowRepository(FakeWorkflowRepository.samples()),
    );
    final provider = workflowsProvider('p@example.com');
    final book = peopleProvider('p@example.com');
    world.container.listen(provider, (_, _) {});
    world.container.listen(book, (_, _) {});
    await world.container.read(provider.future);
    await world.container.read(book.future);
    world.workflows.calls.clear();
    world.people.calls.clear();

    await world.container
        .read(provider.notifier)
        .edit((repository) => repository.rename('samples', 'Tasters'));
    final list = await world.container.read(provider.future);
    await world.container.read(book.future);

    expect(world.workflows.calls, [
      'rename(samples, Tasters)',
      'seed(en)',
      'list()',
    ]);
    expect(findWorkflow(list, 'samples')!.name, 'Tasters');
    expect(world.people.calls, ['list()']);
  });

  test('a failed edit rethrows and reloads nothing', () async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final world = _world(workflows);
    final provider = workflowsProvider('p@example.com');
    world.container.listen(provider, (_, _) {});
    await world.container.read(provider.future);
    workflows
      ..calls.clear()
      ..failWith = PeopleFailure.network;

    await expectLater(
      world.container
          .read(provider.notifier)
          .edit((repository) => repository.rename('samples', 'X')),
      throwsA(PeopleFailure.network),
    );
    expect(workflows.calls, ['rename(samples, X)']);
  });
```

- [ ] **Step 8: Run them to verify they fail**

Run: `flutter test test/features/workflows/presentation/workflows_controller_test.dart`
Expected: FAIL. The call lists still show the old `list()`-first order, and `edit` does not exist (compile error).

- [ ] **Step 9: Implement seed-always, `edit` and `editWorkflows`**

In `lib/features/workflows/presentation/workflows_controller.dart`, update the provider doc's last sentence to "Every load asks the server to seed; it does so once per account, ever.", then replace `build` and add `edit`:

```dart
  @override
  Future<List<Workflow>> build() async {
    final repository = ref.watch(workflowRepositoryProvider);
    if (owner == null) return const [];
    // The server seeds an account once, ever, and no-ops after, even when
    // every workflow has since been deleted. A notifier does not outlive a
    // rebuild, so the device cannot remember having asked.
    await repository.seed(
      seedLanguage(ref.read(accountProvider)?.locale),
      today(),
    );
    final workflows = await repository.list();
    // A first seed started people on a workflow, and an edit (see [edit]) may
    // have moved their current step or due day.
    // ponytail: people reload on every workflows load; have seed_workflows
    // return whether it seeded if that extra request ever matters.
    if (ref.mounted) ref.invalidate(peopleProvider(owner));
    return workflows;
  }

  /// Runs [write], then reloads: the workflows, and through [build] the
  /// people, whose current step and due day the server may now compute
  /// differently. Rethrows the write's `PeopleFailure`. Nothing is
  /// optimistic: screens show the saved state until the reload lands.
  Future<T> edit<T>(
    Future<T> Function(WorkflowRepository repository) write,
  ) async {
    final result = await write(ref.read(workflowRepositoryProvider));
    if (ref.mounted) ref.invalidateSelf();
    return result;
  }
```

Add at the bottom of the file:

```dart
/// [WorkflowsController.edit] on the signed-in account's workflows, read at
/// call time: a notifier does not outlive a rebuild.
Future<T> editWorkflows<T>(
  WidgetRef ref,
  Future<T> Function(WorkflowRepository repository) write,
) => ref
    .read(workflowsProvider(ref.read(accountProvider)?.email).notifier)
    .edit(write);
```

- [ ] **Step 10: Run the controller and domain tests**

Run: `flutter test test/features/workflows/`
Expected: PASS.

- [ ] **Step 11: Fix the one known casualty, then run everything**

`add_person_sheet.dart` watches `workflowsProvider`, whose build now always reloads the book once. In `test/features/contacts/presentation/add_person_sheet_test.dart`, test "a name is required", replace `expect(people.calls, ['list()']);` with:

```dart
    // Nothing was written; the book may have been reloaded.
    expect(people.calls, everyElement('list()'));
```

Run: `flutter test`
Expected: PASS. Any other failure must be an exact `people.calls` or `workflows.calls` list that now has an extra `list()` or a leading `seed(en)`, because a workflows load now always seeds and reloads people. Update each one to assert the write it is about, not the reload count, as above. Fix anything else at its root, not in the test.

- [ ] **Step 12: Commit**

Run the quality gate, then:

```bash
git add lib/features/workflows test/features/workflows test/features/contacts/presentation/add_person_sheet_test.dart
git commit -m "feat(workflows): writes, positionAt, edit and seed on every load (#59)"
```

---

### Task 3: Routes, the Settings row, the Workflows list, New workflow, and the editor with its name

**Files:**
- Modify: `lib/app/router/routes.dart`
- Modify: `lib/app/router/app_router.dart` (two nested routes; `_settingsPage` gains `workflowId`)
- Create: `lib/features/settings/presentation/widgets/settings_scroll.dart` (the private `_Scroll`, made public)
- Modify: `lib/features/settings/presentation/settings_page.dart`
- Create: `lib/features/workflows/presentation/workflows_settings.dart`
- Create: `lib/features/workflows/presentation/workflow_editor.dart`
- Modify: `lib/l10n/app_en.arb`
- Create: `test/features/workflows/presentation/workflows_harness.dart`
- Create: `test/features/workflows/presentation/workflows_settings_test.dart`
- Create: `test/features/workflows/presentation/workflow_editor_test.dart`

**Interfaces:**
- Consumes: `editWorkflows`, `workflowsProvider`, `WorkflowRepository.create` and `.rename`, fake call strings (Task 2); `forStage`, `findWorkflow`; `stageLabel`, `peopleFailureCopy` (`people_copy.dart`); `FoloDialog`, `FormError`, `EmptyState`, `SectionHeader`, `SettingsGroup`, `FoloTopBar`; `pumpFolo` (`test/app/app_harness.dart`); `routerProvider` (`lib/app/router/app_router.dart`).
- Produces:
  - `Routes.settingsWorkflows`, `Routes.settingsWorkflowLocation(String id)`
  - `SettingsSection.workflows`; `SettingsPage({section, workflowId})`
  - `SettingsScroll({required String title, String? eyebrow, required Widget child})`
  - `WorkflowsSettings()`, `WorkflowsView({required workflows, required onOpen, required onNew})`, `WorkflowsLoadError({required onRetry})`, `void openWorkflow(BuildContext context, String id)`, `Future<void> showNewWorkflow(BuildContext context)`
  - `WorkflowEditor({required String id})`; `WorkflowEditorView({required workflow, required onRename})` (Task 5 adds the other callbacks)
  - Test helper `openWorkflows(tester, location, {size, workflows, people, settle})`

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`, add a comma after the last entry and insert these before the file's closing `}`:

```json
  "settingsSectionWorkflows": "Workflows",
  "@settingsSectionWorkflows": {
    "description": "Settings row, and the title of the screen listing the user's workflows: what they do with someone, step by step."
  },
  "workflowsIntro": "What you usually do with someone, step by step. Folo puts the next step on Today when it comes due.",
  "@workflowsIntro": {
    "description": "Intro at the top of Settings → Workflows."
  },
  "workflowsDefaultSteps": "Default · {steps}",
  "@workflowsDefaultSteps": {
    "description": "Trailing text on the row of a stage's default workflow: 'Default · 5 steps'. {steps} is the step count text (followWithSteps).",
    "placeholders": {
      "steps": { "type": "String" }
    }
  },
  "workflowsNew": "New workflow",
  "@workflowsNew": {
    "description": "Button under the workflows, and the title of the dialog it opens."
  },
  "workflowName": "Name",
  "@workflowName": {
    "description": "Label of a workflow's name field, in New workflow and in the editor."
  },
  "workflowNameRequired": "Enter a name.",
  "@workflowNameRequired": {
    "description": "Error under the name field of New workflow when it is empty."
  },
  "workflowsNewStage": "Stage",
  "@workflowsNewStage": {
    "description": "Header above the stage choice in New workflow; shown in capitals."
  },
  "workflowsCreate": "Create",
  "@workflowsCreate": {
    "description": "Confirms New workflow."
  },
  "workflowMissingTitle": "This workflow isn't here anymore",
  "@workflowMissingTitle": {
    "description": "Shown when an open workflow no longer exists (deleted elsewhere, or a bad link)."
  },
  "workflowMissingBody": "It may have been deleted on another device.",
  "@workflowMissingBody": {
    "description": "Body under workflowMissingTitle."
  },
  "workflowBackToList": "Back to workflows",
  "@workflowBackToList": {
    "description": "Button under workflowMissingTitle that returns to the list."
  }
```

Run: `flutter gen-l10n` (or any `flutter test`, which generates).
Expected: no error.

- [ ] **Step 2: Add the routes**

In `lib/app/router/routes.dart`, after the `settingsAppearance…` constants, add:

```dart
  static const String settingsWorkflowsSegment = 'workflows';
  static const String settingsWorkflows = '$settings/$settingsWorkflowsSegment';
  static const String settingsWorkflowsName = 'settingsWorkflows';

  /// One workflow, nested under [settingsWorkflows] so back returns to it.
  static const String settingsWorkflowSegment = ':id';
  static const String settingsWorkflowName = 'settingsWorkflow';

  static String settingsWorkflowLocation(String id) =>
      '$settingsWorkflows/${Uri.encodeComponent(id)}';
```

In `lib/app/router/app_router.dart`, add after the appearance `GoRoute` inside the settings `routes:`:

```dart
              GoRoute(
                path: Routes.settingsWorkflowsSegment,
                name: Routes.settingsWorkflowsName,
                pageBuilder: (context, state) =>
                    _settingsPage(context, state, SettingsSection.workflows),
                routes: [
                  GoRoute(
                    path: Routes.settingsWorkflowSegment,
                    name: Routes.settingsWorkflowName,
                    pageBuilder: (context, state) => _settingsPage(
                      context,
                      state,
                      SettingsSection.workflows,
                      workflowId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
```

and change `_settingsPage` to:

```dart
Page<void> _settingsPage(
  BuildContext context,
  GoRouterState state,
  SettingsSection section, {
  String? workflowId,
}) {
  final child = SettingsPage(section: section, workflowId: workflowId);
  return context.screenSize.isDesktop
      ? NoTransitionPage<void>(
          key: state.pageKey,
          name: state.name,
          child: child,
        )
      : MaterialPage<void>(key: state.pageKey, name: state.name, child: child);
}
```

This does not compile until Step 3 adds `SettingsSection.workflows` and `workflowId`.

- [ ] **Step 3: Write the failing widget tests**

Create `test/features/workflows/presentation/workflows_harness.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/app_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../contacts/fake_people_repository.dart';
import '../fake_workflow_repository.dart';

/// The app signed in as Pauline, gone to [location]: a phone unless [size]
/// says otherwise. With [settle] false it pumps past the route transition
/// only, for a load gated on purpose.
Future<ProviderContainer> openWorkflows(
  WidgetTester tester,
  String location, {
  Size size = const Size(390, 844),
  FakeWorkflowRepository? workflows,
  FakePeopleRepository? people,
  bool settle = true,
}) async {
  final container = await pumpFolo(
    tester,
    size: size,
    workflows: workflows,
    people: people,
    settle: settle,
  );
  container.read(routerProvider).go(location);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
  return container;
}
```

Create `test/features/workflows/presentation/workflows_settings_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/core/ui/folo_top_bar.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/workflows/presentation/workflow_editor.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_workflow_repository.dart';
import 'workflows_harness.dart';

const _failed = "Couldn't save. Check your connection and try again.";

Finder _title(String text) =>
    find.descendant(of: find.byType(FoloTopBar), matching: find.text(text));

Future<void> _openNew(WidgetTester tester) async {
  await tester.ensureVisible(find.text('New workflow'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('New workflow'));
  await tester.pumpAndSettle();
}

Iterable<String> _creates(FakeWorkflowRepository workflows) =>
    workflows.calls.where((call) => call.startsWith('create'));

void main() {
  testWidgets('lists the workflows by stage, the default first', (
    tester,
  ) async {
    await openWorkflows(tester, Routes.settingsWorkflows);

    expect(find.text('PROSPECTS'), findsOneWidget);
    expect(find.text('CUSTOMERS'), findsOneWidget);
    expect(find.text('TEAM'), findsOneWidget);
    // Samples and Getting started have 5 steps; New customer 4.
    expect(find.text('Default · 5 steps'), findsNWidgets(2));
    expect(find.text('Default · 4 steps'), findsOneWidget);
    expect(find.text('4 steps'), findsOneWidget);
    expect(find.text('2 steps'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Samples')).dy,
      lessThan(tester.getTopLeft(find.text('Health professionals')).dy),
    );
  });

  testWidgets('a stage with no workflows has no group', (tester) async {
    await openWorkflows(
      tester,
      Routes.settingsWorkflows,
      workflows: FakeWorkflowRepository(
        FakeWorkflowRepository.samples().where(
          (workflow) => workflow.stage != Stage.team,
        ),
      ),
    );

    expect(find.text('PROSPECTS'), findsOneWidget);
    expect(find.text('TEAM'), findsNothing);
  });

  testWidgets('a spinner while loading', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples())
      ..gate = Completer<void>();
    await openWorkflows(
      tester,
      Routes.settingsWorkflows,
      workflows: workflows,
      settle: false,
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Samples'), findsNothing);

    workflows.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Samples'), findsOneWidget);
  });

  testWidgets('a failed load says so, and Try again reloads', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples())
      ..failWith = PeopleFailure.network;
    await openWorkflows(tester, Routes.settingsWorkflows, workflows: workflows);

    expect(find.text("Couldn't load the workflows"), findsOneWidget);

    workflows.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Samples'), findsOneWidget);
  });

  testWidgets('the Settings row opens the list', (tester) async {
    await openWorkflows(tester, Routes.settings);

    await tester.tap(find.text('Workflows'));
    await tester.pumpAndSettle();

    expect(find.text('Samples'), findsOneWidget);
  });

  testWidgets('New workflow creates at the stage picked, then opens it', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(tester, Routes.settingsWorkflows, workflows: workflows);
    await _openNew(tester);

    await tester.enterText(find.byType(TextFormField), 'Weekend');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Customer'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(workflows.calls, contains('create(customer, Weekend)'));
    expect(find.byType(WorkflowEditor), findsOneWidget);
    expect(_title('Weekend'), findsOneWidget);
  });

  testWidgets('a blank name is refused, and a name is trimmed', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(tester, Routes.settingsWorkflows, workflows: workflows);
    await _openNew(tester);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name.'), findsOneWidget);
    expect(_creates(workflows), isEmpty);

    await tester.enterText(find.byType(TextFormField), '  Weekend  ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    // Prospect is picked unless the user picks another stage.
    expect(_creates(workflows), ['create(prospect, Weekend)']);
  });

  testWidgets('a failed create keeps the dialog and what was typed', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(tester, Routes.settingsWorkflows, workflows: workflows);
    await _openNew(tester);
    workflows.failWith = PeopleFailure.network;

    await tester.enterText(find.byType(TextFormField), 'Weekend');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FormError, _failed), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Weekend'), findsOneWidget);
    expect(find.byType(WorkflowEditor), findsNothing);
  });

  testWidgets('a second tap on Create while creating writes nothing more', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(tester, Routes.settingsWorkflows, workflows: workflows);
    await _openNew(tester);
    await tester.enterText(find.byType(TextFormField), 'Weekend');
    workflows.gate = Completer<void>();

    // No frame between the taps: Create is not rebuilt as disabled yet.
    await tester.tap(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(_creates(workflows), hasLength(1));

    workflows.gate!.complete();
    await tester.pumpAndSettle();
    expect(_creates(workflows), hasLength(1));
    expect(find.byType(WorkflowEditor), findsOneWidget);
  });

  testWidgets('desktop: the list, then the editor, in the pane', (
    tester,
  ) async {
    await openWorkflows(tester, Routes.settings, size: const Size(1440, 900));

    await tester.tap(find.text('Workflows'));
    await tester.pumpAndSettle();
    expect(find.text('Health professionals'), findsOneWidget);
    expect(find.text('PREFERENCES'), findsOneWidget);

    await tester.tap(find.text('Health professionals'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowEditor), findsOneWidget);
    expect(find.text('PREFERENCES'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowEditor), findsNothing);
    expect(find.text('Health professionals'), findsOneWidget);
  });
}
```

Create `test/features/workflows/presentation/workflow_editor_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/core/ui/folo_top_bar.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_workflow_repository.dart';
import 'workflows_harness.dart';

const _failed = "Couldn't save. Check your connection and try again.";

Finder _title(String text) =>
    find.descendant(of: find.byType(FoloTopBar), matching: find.text(text));

String _name(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

Iterable<String> _renames(FakeWorkflowRepository workflows) =>
    workflows.calls.where((call) => call.startsWith('rename'));

Future<void> _typeName(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextField).first, name);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the stage and the name', (tester) async {
    await openWorkflows(tester, Routes.settingsWorkflowLocation('samples'));

    expect(_title('Samples'), findsOneWidget);
    expect(find.text('PROSPECT'), findsOneWidget);
    expect(_name(tester), 'Samples');
  });

  testWidgets('a new name is trimmed, saved and shown', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    await _typeName(tester, '  Tasters  ');

    expect(_renames(workflows), ['rename(samples, Tasters)']);
    expect(_title('Tasters'), findsOneWidget);
    expect(_name(tester), 'Tasters');
  });

  testWidgets('an empty name puts the saved one back without writing', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    await _typeName(tester, '   ');
    expect(_name(tester), 'Samples');

    await _typeName(tester, 'Samples');
    expect(_renames(workflows), isEmpty);
  });

  testWidgets('a failed rename says so and puts the saved name back', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );
    workflows.failWith = PeopleFailure.network;

    await _typeName(tester, 'Tasters');

    expect(find.text(_failed), findsOneWidget);
    expect(_name(tester), 'Samples');
    expect(_title('Samples'), findsOneWidget);
  });

  testWidgets('a bad link says the workflow is not here', (tester) async {
    await openWorkflows(tester, Routes.settingsWorkflowLocation('gone'));

    expect(find.text("This workflow isn't here anymore"), findsOneWidget);

    await tester.tap(find.text('Back to workflows'));
    await tester.pumpAndSettle();
    expect(find.text('Health professionals'), findsOneWidget);
  });

  testWidgets('a workflow deleted elsewhere says so', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final container = await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    // Another device deleted it; this one reloads.
    workflows.store.removeWhere((workflow) => workflow.id == 'samples');
    container.invalidate(workflowsProvider('p@example.com'));
    await tester.pumpAndSettle();

    expect(find.text("This workflow isn't here anymore"), findsOneWidget);
    await tester.tap(find.text('Back to workflows'));
    await tester.pumpAndSettle();
    expect(find.text('Health professionals'), findsOneWidget);
    expect(find.text('Samples'), findsNothing);
  });
}
```

`find.byType(TextField).first` is the name field: Task 5 adds no other text field to the editor, and keeps this `.first` safe if one is ever added below.

Run: `flutter test test/features/workflows/presentation/`
Expected: FAIL to compile (`WorkflowEditor`, `Routes.settingsWorkflows` and the rest do not exist yet).

- [ ] **Step 4: Make the Settings scroll public**

Create `lib/features/settings/presentation/widgets/settings_scroll.dart`. The body is `_Scroll` from `settings_page.dart`, moved, with an optional eyebrow:

```dart
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/core/ui/folo_top_bar.dart';
import 'package:material_ui/material_ui.dart';

/// A Settings screen: its top bar, then [child], centred and scrolling.
class SettingsScroll extends StatelessWidget {
  const SettingsScroll({
    required this.title,
    required this.child,
    this.eyebrow,
    super.key,
  });

  final String title;

  /// Above [title], e.g. a workflow's stage.
  final String? eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final desktop = context.screenSize.isDesktop;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: EdgeInsets.all(desktop ? AppSpacing.xl : AppSpacing.md),
          children: [
            FoloTopBar(title: title, eyebrow: eyebrow, large: desktop),
            child,
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Add the Workflows section to Settings**

In `lib/features/settings/presentation/settings_page.dart`:

1. Delete the `_Scroll` class and replace every `_Scroll(` with `SettingsScroll(`. Add the imports:

```dart
import 'package:folo/features/settings/presentation/widgets/settings_scroll.dart';
import 'package:folo/features/workflows/presentation/workflow_editor.dart';
import 'package:folo/features/workflows/presentation/workflows_settings.dart';
```

Remove `import 'package:folo/core/ui/folo_top_bar.dart';` if `flutter analyze` reports it unused.

2. The enum becomes `enum SettingsSection { account, language, appearance, workflows }`.

3. `SettingsPage` takes the open workflow. Replace the constructor and add the field under `section`:

```dart
  const SettingsPage({this.section, this.workflowId, super.key});
```

```dart
  /// The workflow open in [SettingsSection.workflows]; null shows the list.
  final String? workflowId;
```

4. In `open`, add the case `SettingsSection.workflows => Routes.settingsWorkflows,`.

5. In `build`, the desktop pane becomes `Expanded(child: _Section(section: shown, workflowId: workflowId)),`. The mobile back button's fallback becomes:

```dart
                onPressed: () => backOr(
                  context,
                  current == null
                      ? Routes.today
                      : workflowId == null
                      ? Routes.settings
                      : Routes.settingsWorkflows,
                ),
```

and the mobile body's `_Section(section: current)` becomes `_Section(section: current, workflowId: workflowId)`.

6. Replace `_Section` with:

```dart
class _Section extends StatelessWidget {
  const _Section({required this.section, this.workflowId});

  final SettingsSection section;
  final String? workflowId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (section) {
      SettingsSection.account => SettingsScroll(
        title: l10n.settingsSectionAccount,
        child: const AccountSettings(),
      ),
      SettingsSection.language => SettingsScroll(
        title: l10n.settingsSectionLanguage,
        child: const LanguageSettings(),
      ),
      SettingsSection.appearance => SettingsScroll(
        title: l10n.settingsSectionAppearance,
        child: const AppearanceSettings(),
      ),
      SettingsSection.workflows => switch (workflowId) {
        null => SettingsScroll(
          title: l10n.settingsSectionWorkflows,
          child: const WorkflowsSettings(),
        ),
        // A new id is a new editor: nothing typed carries over.
        final id => _WorkflowPane(
          child: WorkflowEditor(key: ValueKey(id), id: id),
        ),
      },
    };
  }
}

/// On desktop the editor replaces the list in the pane, where the page has
/// no app bar: this one's back returns to the list. Elsewhere the page's
/// own app bar does.
class _WorkflowPane extends StatelessWidget {
  const _WorkflowPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.screenSize.isDesktop) return child;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => backOr(context, Routes.settingsWorkflows),
        ),
      ),
      body: child,
    );
  }
}
```

7. In `_SettingsListState.build`, insert a group right before `SectionHeader(title: l10n.settingsSectionPreferences),`:

```dart
        SettingsGroup(
          children: [
            ListTile(
              selected: selected == SettingsSection.workflows,
              leading: const Icon(Icons.route_rounded),
              title: Text(l10n.settingsSectionWorkflows),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () =>
                  SettingsPage.open(context, SettingsSection.workflows),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
```

- [ ] **Step 6: Write the Workflows list and New workflow**

Create `lib/features/workflows/presentation/workflows_settings.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/core/ui/section_header.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/settings/presentation/widgets/settings_group.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Settings → Workflows, on the signed-in account's workflows.
class WorkflowsSettings extends ConsumerWidget {
  const WorkflowsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflows = workflowsProvider(ref.watch(accountProvider)?.email);
    final state = ref.watch(workflows);
    final list = state.value;
    if (list == null) {
      return state.hasError
          ? WorkflowsLoadError(onRetry: () => ref.invalidate(workflows))
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            );
    }
    return WorkflowsView(
      workflows: list,
      onOpen: (workflow) => openWorkflow(context, workflow.id),
      onNew: () => unawaited(showNewWorkflow(context)),
    );
  }
}

/// The list, fed its data: one group per stage that has workflows, the
/// default first. Also what the preview shows.
class WorkflowsView extends StatelessWidget {
  const WorkflowsView({
    required this.workflows,
    required this.onOpen,
    required this.onNew,
    super.key,
  });

  final List<Workflow> workflows;
  final ValueChanged<Workflow> onOpen;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.workflowsIntro,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final stage in Stage.values)
          if (forStage(workflows, stage) case final group
              when group.isNotEmpty) ...[
            SectionHeader(title: _stageHeader(l10n, stage)),
            SettingsGroup(
              children: [
                for (final workflow in group)
                  ListTile(
                    title: Text(workflow.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.sm,
                      children: [
                        Text(_steps(l10n, workflow)),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: () => onOpen(workflow),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            onPressed: onNew,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.workflowsNew),
          ),
        ),
      ],
    );
  }

  static String _stageHeader(AppLocalizations l10n, Stage stage) =>
      switch (stage) {
        Stage.prospect => l10n.contactsFilterProspects,
        Stage.customer => l10n.contactsFilterCustomers,
        Stage.team => l10n.contactsFilterTeam,
      };

  static String _steps(AppLocalizations l10n, Workflow workflow) {
    final steps = l10n.followWithSteps(workflow.steps.length);
    return workflow.isDefault ? l10n.workflowsDefaultSteps(steps) : steps;
  }
}

/// The workflows did not load. Existing copy: Next step says the same.
class WorkflowsLoadError extends StatelessWidget {
  const WorkflowsLoadError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l10n.nextStepLoadFailed,
        body: l10n.contactsLoadErrorBody,
        actionLabel: l10n.contactsRetry,
        onAction: onRetry,
      ),
    );
  }
}

/// In the pane in place of the list on desktop; elsewhere pushed, so back
/// returns to the list.
void openWorkflow(BuildContext context, String id) {
  final location = Routes.settingsWorkflowLocation(id);
  if (context.screenSize.isDesktop) {
    context.go(location);
  } else {
    context.push(location);
  }
}

/// Name and stage. Create writes, then opens the editor on the new workflow.
Future<void> showNewWorkflow(BuildContext context) async {
  final created = await FoloDialog.show<Workflow>(
    context,
    (_) => const _NewWorkflowForm(),
  );
  if (created != null && context.mounted) openWorkflow(context, created.id);
}

class _NewWorkflowForm extends ConsumerStatefulWidget {
  const _NewWorkflowForm();

  @override
  ConsumerState<_NewWorkflowForm> createState() => _NewWorkflowFormState();
}

class _NewWorkflowFormState extends ConsumerState<_NewWorkflowForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  Stage _stage = Stage.prospect;
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // A second tap can land before the frame that disables Create.
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final created = await editWorkflows(
        ref,
        (workflows) => workflows.create(_stage, _name.text.trim()),
      );
      if (mounted) Navigator.pop(context, created);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;

    return Form(
      key: _form,
      child: FoloDialog(
        title: l10n.workflowsNew,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.workflowsCreate),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.workflowNameRequired
                  : null,
              decoration: InputDecoration(labelText: l10n.workflowName),
            ),
            SectionHeader(title: l10n.workflowsNewStage),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final stage in Stage.values)
                  ChoiceChip(
                    label: Text(stageLabel(l10n, stage)),
                    selected: _stage == stage,
                    onSelected: (_) => setState(() => _stage = stage),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

`SizedBox.square(dimension: 20)` is the spinner size `log_activity_sheet.dart` already uses in a button. If `SettingsPage.open`'s bare `context.push` passes `flutter analyze`, so does this one.

- [ ] **Step 7: Write the editor with its name**

Create `lib/features/workflows/presentation/workflow_editor.dart`. Task 5 replaces this file whole, adding steps, the default switch and Delete:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/settings/presentation/widgets/settings_scroll.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:folo/features/workflows/presentation/workflows_settings.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// One workflow, found in the loaded list (there is no second fetch), wired
/// to saving.
class WorkflowEditor extends ConsumerWidget {
  const WorkflowEditor({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workflows = workflowsProvider(ref.watch(accountProvider)?.email);
    final state = ref.watch(workflows);
    final list = state.value;
    final workflow = list == null ? null : findWorkflow(list, id);

    if (workflow == null) {
      // Still loading, or reloading right after New workflow created it.
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (list == null) {
        return WorkflowsLoadError(onRetry: () => ref.invalidate(workflows));
      }
      // Deleted elsewhere, or a bad link.
      return Center(
        child: EmptyState(
          icon: Icons.route_rounded,
          title: l10n.workflowMissingTitle,
          body: l10n.workflowMissingBody,
          actionLabel: l10n.workflowBackToList,
          onAction: () => context.go(Routes.settingsWorkflows),
        ),
      );
    }

    return SettingsScroll(
      eyebrow: stageLabel(l10n, workflow.stage),
      title: workflow.name,
      child: WorkflowEditorView(
        workflow: workflow,
        onRename: (name) => editWorkflows(
          ref,
          (repository) => repository.rename(workflow.id, name),
        ),
      ),
    );
  }
}

/// What a write in flight disables: the control that started it.
enum _Control { name }

/// The editor, fed the saved workflow and one callback per write; each
/// callback throws `PeopleFailure`. Also what the preview shows.
class WorkflowEditorView extends StatefulWidget {
  const WorkflowEditorView({
    required this.workflow,
    required this.onRename,
    super.key,
  });

  final Workflow workflow;

  /// A trimmed name, different from the saved one.
  final Future<void> Function(String name) onRename;

  @override
  State<WorkflowEditorView> createState() => _WorkflowEditorViewState();
}

class _WorkflowEditorViewState extends State<WorkflowEditorView> {
  late final _name = TextEditingController(text: widget.workflow.name);
  final _nameFocus = FocusNode();
  final Set<_Control> _busy = {};

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) unawaited(_saveName());
    });
  }

  @override
  void didUpdateWidget(WorkflowEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A reload brought a name saved here or elsewhere; never under the
    // user's fingers.
    if (!_nameFocus.hasFocus && widget.workflow.name != _name.text) {
      _name.text = widget.workflow.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// Runs [write] unless [control] is already writing, and says so when it
  /// fails. Returns whether it saved.
  Future<bool> _run(_Control control, Future<void> Function() write) async {
    if (_busy.contains(control)) return false;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy.add(control));
    try {
      await write();
      return true;
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
      return false;
    } finally {
      if (mounted) setState(() => _busy.remove(control));
    }
  }

  Future<void> _saveName() async {
    final saved = widget.workflow.name;
    final name = _name.text.trim();
    // Empty or unchanged: put the saved name back, write nothing.
    if (name.isEmpty || name == saved) {
      _name.text = saved;
      return;
    }
    _name.text = name;
    final ok = await _run(_Control.name, () => widget.onRename(name));
    if (!ok && mounted) _name.text = widget.workflow.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          focusNode: _nameFocus,
          readOnly: _busy.contains(_Control.name),
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: l10n.workflowName),
        ),
      ],
    );
  }
}
```

"Done" on the keyboard unfocuses the field (the `TextField` default), which saves; so does tapping elsewhere. The spec's "input kept" on failure is for sheets and dialogs. Here the saved name comes back, because the title and the list still show it.

- [ ] **Step 8: Run the tests**

Run: `flutter test test/features/workflows/ test/features/settings/`
Expected: PASS. If a mobile test in `settings_page_test.dart` misses a tap because the new group pushed its row below the fold, add `await tester.ensureVisible(<the same finder>); await tester.pumpAndSettle();` before that tap. Change nothing else in it.

- [ ] **Step 9: Commit**

Run the quality gate, then:

```bash
git add lib/app/router lib/features/settings lib/features/workflows lib/l10n/app_en.arb test/features/workflows test/features/settings
git commit -m "feat(workflows): list, New workflow and rename in Settings (#59)"
```

---

### Task 4: The step sheet

**Files:**
- Create: `lib/features/workflows/presentation/step_sheet.dart`
- Modify: `lib/l10n/app_en.arb`
- Create: `test/features/workflows/presentation/step_sheet_test.dart`

**Interfaces:**
- Consumes: `editWorkflows`, `positionAt`, `WorkflowRepository.addStep` / `.updateStep` / `.removeStep` and their fake call strings (Task 2); `FoloDialog`, `FormError`, `peopleFailureCopy`; `pumpFormHarness` (`test/features/contacts/presentation/form_harness.dart`).
- Produces:
  - `typedef StepDraft = ({String label, int days, String? note})`
  - `StepForm({required int number, WorkflowStep? step, required Future<void> Function(StepDraft) onSave, Future<void> Function()? onRemove})`, a pure form that pops itself once a write succeeds
  - `Future<void> showStepSheet(BuildContext context, Workflow workflow, {int? index})`: `index` null adds a step at the end

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`, add a comma after the last entry and insert before the closing `}`:

```json
  "stepTitle": "Step {number}",
  "@stepTitle": {
    "description": "Title of the sheet editing one step of a workflow.",
    "placeholders": {
      "number": { "type": "int" }
    }
  },
  "stepNew": "New step",
  "@stepNew": {
    "description": "Title of the sheet adding a step at the end of a workflow."
  },
  "stepLabel": "What to do",
  "@stepLabel": {
    "description": "Label of a step's text field: the action, e.g. 'Send the samples'."
  },
  "stepLabelRequired": "Enter what to do.",
  "@stepLabelRequired": {
    "description": "Error under stepLabel when it is empty."
  },
  "stepDaysAfterPrevious": "Days after the previous step",
  "@stepDaysAfterPrevious": {
    "description": "Label of the days field, for every step but the first."
  },
  "stepDaysAfterStart": "Days after starting",
  "@stepDaysAfterStart": {
    "description": "Label of the days field for step 1, which counts from the day the person starts the workflow."
  },
  "stepDaysInvalid": "Enter a number from 0 to 365.",
  "@stepDaysInvalid": {
    "description": "Error under the days field when it is empty or above 365."
  },
  "stepDueAfterPrevious": "{days, plural, =0{Comes due the same day you tick step {previous}.} =1{Comes due 1 day after you tick step {previous}.} other{Comes due {days} days after you tick step {previous}.}}",
  "@stepDueAfterPrevious": {
    "description": "Live hint under the days field: when this step comes due. {previous} is the number of the step before.",
    "placeholders": {
      "days": { "type": "int" },
      "previous": { "type": "int" }
    }
  },
  "stepDueAfterStart": "{days, plural, =0{Comes due the same day you start.} =1{Comes due 1 day after you start.} other{Comes due {days} days after you start.}}",
  "@stepDueAfterStart": {
    "description": "Live hint under the days field of step 1.",
    "placeholders": {
      "days": { "type": "int" }
    }
  },
  "stepNote": "Note",
  "@stepNote": {
    "description": "Label of a step's optional note field."
  },
  "stepRemove": "Remove this step",
  "@stepRemove": {
    "description": "Button in the step sheet. No confirmation: people on the step move on, and their history stays."
  }
```

- [ ] **Step 2: Write the failing tests**

Create `test/features/workflows/presentation/step_sheet_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/workflows/presentation/step_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../contacts/fake_people_repository.dart';
import '../../contacts/presentation/form_harness.dart';
import '../fake_workflow_repository.dart';

const _failed = "Couldn't save. Check your connection and try again.";

void main() {
  late FakeWorkflowRepository workflows;

  setUp(() {
    workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
  });

  /// The sheet on Samples: [index] null adds a step.
  Future<void> open(WidgetTester tester, {int? index}) => pumpFormHarness(
    tester,
    people: FakePeopleRepository(),
    workflows: workflows,
    open: (context) =>
        showStepSheet(context, workflows.store.first, index: index),
    result: (_) {},
  );

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Iterable<String> writes(String name) =>
      workflows.calls.where((call) => call.startsWith(name));

  testWidgets('a new step goes at the end, counted from the one before', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('New step'), findsOneWidget);
    expect(find.text('Remove this step'), findsNothing);
    // Samples has 5 steps; a new one is due a day after the fifth.
    expect(find.text('Comes due 1 day after you tick step 5.'), findsOneWidget);

    await tester.enterText(field('What to do'), 'Say thanks');
    await tester.enterText(field('Days after the previous step'), '2');
    await tester.pump();
    expect(
      find.text('Comes due 2 days after you tick step 5.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(writes('addStep'), ['addStep(samples, Say thanks, 2, 6)']);
    expect(find.text('New step'), findsNothing);
  });

  testWidgets('step 1 counts from the start', (tester) async {
    await open(tester, index: 0);

    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('Send a first message'), findsOneWidget);
    expect(field('Days after starting'), findsOneWidget);
    expect(find.text('Comes due the same day you start.'), findsOneWidget);
  });

  testWidgets('an edited step is saved trimmed', (tester) async {
    await open(tester, index: 1);
    expect(find.text('Step 2'), findsOneWidget);

    await tester.enterText(field('What to do'), '  Send the kit  ');
    await tester.enterText(field('Days after the previous step'), '3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(writes('updateStep'), ['updateStep(samples-2, Send the kit, 3)']);
    expect(find.text('Step 2'), findsNothing);
  });

  testWidgets('what to do is required', (tester) async {
    await open(tester);

    await tester.enterText(field('What to do'), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter what to do.'), findsOneWidget);
    expect(writes('addStep'), isEmpty);
  });

  testWidgets('days must be 0 to 365', (tester) async {
    await open(tester, index: 1);
    final days = field('Days after the previous step');

    await tester.enterText(days, '400');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number from 0 to 365.'), findsOneWidget);

    await tester.enterText(days, '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number from 0 to 365.'), findsOneWidget);

    // Only digits can be typed.
    await tester.enterText(days, '-3a');
    expect(
      tester.widget<TextFormField>(days).controller!.text,
      '3',
    );
    expect(writes('updateStep'), isEmpty);
  });

  testWidgets('Remove this step removes it without asking', (tester) async {
    await open(tester, index: 1);

    await tester.tap(find.text('Remove this step'));
    await tester.pumpAndSettle();

    expect(writes('removeStep'), ['removeStep(samples-2)']);
    expect(find.text('Step 2'), findsNothing);
  });

  testWidgets('a second tap on Save while saving writes nothing more', (
    tester,
  ) async {
    await open(tester, index: 1);
    workflows.gate = Completer<void>();

    // No frame between the taps: Save is not rebuilt as disabled yet.
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(writes('updateStep'), hasLength(1));

    workflows.gate!.complete();
    await tester.pumpAndSettle();
    expect(writes('updateStep'), hasLength(1));
  });

  testWidgets('a failed save keeps the sheet and what was typed', (
    tester,
  ) async {
    await open(tester, index: 1);
    workflows.failWith = PeopleFailure.network;

    await tester.enterText(field('What to do'), 'Send the kit');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FormError, _failed), findsOneWidget);
    expect(find.text('Step 2'), findsOneWidget);
    expect(find.text('Send the kit'), findsOneWidget);
  });
}
```

Run: `flutter test test/features/workflows/presentation/step_sheet_test.dart`
Expected: FAIL to compile (`step_sheet.dart` does not exist).

- [ ] **Step 3: Write the sheet**

Create `lib/features/workflows/presentation/step_sheet.dart`:

```dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// What the step sheet saves: a trimmed label, 0 to 365 days, and a trimmed
/// note or null.
typedef StepDraft = ({String label, int days, String? note});

/// Edits the step at [index] of [workflow], or adds one at the end when
/// [index] is null. The sheet reads its own `ref`, so it does not depend on
/// the editor under it staying mounted.
Future<void> showStepSheet(
  BuildContext context,
  Workflow workflow, {
  int? index,
}) {
  final step = index == null ? null : workflow.steps[index];
  return FoloDialog.show<void>(
    context,
    (_) => Consumer(
      builder: (context, ref, _) => StepForm(
        number: (index ?? workflow.steps.length) + 1,
        step: step,
        onSave: (draft) => editWorkflows(
          ref,
          (repository) => step == null
              ? repository.addStep(
                  workflow.id,
                  label: draft.label,
                  days: draft.days,
                  note: draft.note,
                  position: positionAt(workflow.steps, workflow.steps.length),
                )
              : repository.updateStep(
                  step.id,
                  label: draft.label,
                  days: draft.days,
                  note: draft.note,
                ),
        ),
        onRemove: step == null
            ? null
            : () => editWorkflows(
                ref,
                (repository) => repository.removeStep(step.id),
              ),
      ),
    ),
  );
}

/// One step's form, fed its callbacks, which throw `PeopleFailure`. Pops
/// itself once one succeeds; keeps what was typed when one fails. Also what
/// the preview shows.
class StepForm extends StatefulWidget {
  const StepForm({
    required this.number,
    required this.onSave,
    this.step,
    this.onRemove,
    super.key,
  });

  /// From 1. Step 1 counts from the start, the others from the one before.
  final int number;

  /// The step edited; null adds one.
  final WorkflowStep? step;
  final Future<void> Function(StepDraft draft) onSave;

  /// Editing only.
  final Future<void> Function()? onRemove;

  @override
  State<StepForm> createState() => _StepFormState();
}

class _StepFormState extends State<StepForm> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.step?.label);
  // A new step 1 is usually done on the day; a later one the day after.
  late final _days = TextEditingController(
    text: '${widget.step?.days ?? (widget.number == 1 ? 0 : 1)}',
  );
  late final _note = TextEditingController(text: widget.step?.note);
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _label.dispose();
    _days.dispose();
    _note.dispose();
    super.dispose();
  }

  static int? _parseDays(String text) {
    final days = int.tryParse(text);
    return days != null && days >= 0 && days <= 365 ? days : null;
  }

  Future<void> _run(Future<void> Function() write) async {
    // A second tap can land before the frame that disables the buttons.
    if (_saving) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await write();
      if (mounted) Navigator.pop(context);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  void _save() {
    if (_saving || !_form.currentState!.validate()) return;
    final note = _note.text.trim();
    unawaited(
      _run(
        () => widget.onSave((
          label: _label.text.trim(),
          days: int.parse(_days.text),
          note: note.isEmpty ? null : note,
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;
    final remove = widget.onRemove;
    final first = widget.number == 1;
    final days = _parseDays(_days.text);

    return Form(
      key: _form,
      child: FoloDialog(
        title: widget.step == null
            ? l10n.stepNew
            : l10n.stepTitle(widget.number),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(material.saveButtonLabel),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
            TextFormField(
              controller: _label,
              autofocus: widget.step == null,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.stepLabelRequired
                  : null,
              decoration: InputDecoration(labelText: l10n.stepLabel),
            ),
            TextFormField(
              controller: _days,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              // The hint follows what is typed.
              onChanged: (_) => setState(() {}),
              validator: (value) =>
                  _parseDays(value ?? '') == null ? l10n.stepDaysInvalid : null,
              decoration: InputDecoration(
                labelText: first
                    ? l10n.stepDaysAfterStart
                    : l10n.stepDaysAfterPrevious,
                helperText: days == null
                    ? null
                    : first
                    ? l10n.stepDueAfterStart(days)
                    : l10n.stepDueAfterPrevious(days, widget.number - 1),
                helperMaxLines: 2,
              ),
            ),
            TextFormField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.stepNote),
            ),
            if (remove != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _saving ? null : () => unawaited(_run(remove)),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: Text(l10n.stepRemove),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/workflows/presentation/step_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

Run the quality gate, then:

```bash
git add lib/features/workflows/presentation/step_sheet.dart lib/l10n/app_en.arb test/features/workflows/presentation/step_sheet_test.dart
git commit -m "feat(workflows): the step sheet (#59)"
```

---

### Task 5: The full editor — steps, reorder, default, delete

**Files:**
- Modify (replace whole): `lib/features/workflows/presentation/workflow_editor.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `test/features/workflows/presentation/workflow_editor_test.dart` (add tests)

**Interfaces:**
- Consumes: `showStepSheet` (Task 4); `editWorkflows`, `positionAt`, `moveStep` / `setDefault` / `delete` and their fake call strings (Task 2); `WorkflowEditor`, `WorkflowEditorView`, `openWorkflows` (Task 3); `confirmDestructive` (`lib/core/ui/folo_dialog.dart`); `peopleProvider`; `backOr`.
- Produces: `WorkflowEditorView({required workflow, required onRename, required onAddStep, required onOpenStep, required onMove, required onDefault, required onDelete})`. Task 6's preview uses it.

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`, add a comma after the last entry and insert before the closing `}`:

```json
  "workflowSteps": "Steps",
  "@workflowSteps": {
    "description": "Header above a workflow's steps in the editor; shown in capitals."
  },
  "workflowAddStep": "Add a step",
  "@workflowAddStep": {
    "description": "Action beside workflowSteps: adds a step at the end."
  },
  "workflowStepWhenYouStart": "When you start",
  "@workflowStepWhenYouStart": {
    "description": "Under step 1 when it is due the day the person starts the workflow."
  },
  "workflowStepDaysAfter": "{days, plural, =0{Same day} =1{1 day after} other{{days} days after}}",
  "@workflowStepDaysAfter": {
    "description": "Under a step: how long after the step before (after the start, for step 1) it comes due.",
    "placeholders": {
      "days": { "type": "int" }
    }
  },
  "workflowNoSteps": "No steps yet.",
  "@workflowNoSteps": {
    "description": "In place of the steps when a workflow has none."
  },
  "workflowDefaultFor": "{stage, select, prospect{Default for new prospects} customer{Default for new customers} other{Default for new team members}}",
  "@workflowDefaultFor": {
    "description": "Switch in the editor: someone new at this stage starts this workflow. {stage} is prospect, customer or team.",
    "placeholders": {
      "stage": { "type": "String" }
    }
  },
  "workflowFooter": "Each step comes due a number of days after you tick the one before. Changes apply to everyone on this workflow — steps already done stay in their history.",
  "@workflowFooter": {
    "description": "Explanation under the default switch in the editor."
  },
  "workflowDelete": "Delete workflow",
  "@workflowDelete": {
    "description": "Danger row at the bottom of the editor."
  },
  "workflowDeleteTitle": "Delete {name}?",
  "@workflowDeleteTitle": {
    "description": "Title of the confirmation before deleting a workflow. {name} is the workflow's name.",
    "placeholders": {
      "name": { "type": "String" }
    }
  },
  "workflowDeleteBody": "{count, plural, =0{No one follows it.} =1{1 person follows it. They'll have nothing planned; their history stays.} other{{count} people follow it. They'll have nothing planned; their history stays.}}",
  "@workflowDeleteBody": {
    "description": "Body of the confirmation before deleting a workflow: how many people are on it now.",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "workflowDeleteConfirm": "Delete",
  "@workflowDeleteConfirm": {
    "description": "Confirms deleting a workflow."
  }
```

- [ ] **Step 2: Write the failing tests**

In `test/features/workflows/presentation/workflow_editor_test.dart`, add these imports:

```dart
import 'dart:async';

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/workflow_editor.dart';

import '../../contacts/fake_people_repository.dart';
```

(If `flutter analyze` calls the `flutter/semantics.dart` import unnecessary, because `material_ui` already exports the class, delete that import.)

Add these helpers above `main`:

```dart
Person _on(String id, String workflowId) => Person(
  id: id,
  name: 'Person $id',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 3, 4),
  place: (workflowId: workflowId, atPosition: 1, lastTick: today()),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The row of the step labelled [label], as semantics sees it: the node
/// that carries ReorderableListView's Move up / Move down actions.
FinderBase<SemanticsNode> _stepNode(String label) => find.semantics
    .ancestor(
      of: find.semantics.byLabel(RegExp(label)),
      matching: find.semantics.byPredicate(
        (node) =>
            node.getSemanticsData().customSemanticsActionIds?.isNotEmpty ??
            false,
      ),
      matchRoot: true,
    )
    .first;

const _moveDown = CustomSemanticsAction(label: 'Move down');
```

Add these tests inside `main`:

```dart
  testWidgets('each step says when it comes due', (tester) async {
    await openWorkflows(tester, Routes.settingsWorkflowLocation('samples'));

    // Samples: 0, 1, 4, 3, 7.
    expect(find.text('When you start'), findsOneWidget);
    expect(find.text('1 day after'), findsOneWidget);
    expect(find.text('4 days after'), findsOneWidget);
    expect(find.text('3 days after'), findsOneWidget);
    expect(find.text('7 days after'), findsOneWidget);
    expect(find.text('Default for new prospects'), findsOneWidget);
  });

  testWidgets('no steps says so', (tester) async {
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('empty'),
      workflows: FakeWorkflowRepository([
        Workflow(
          id: 'empty',
          stage: Stage.customer,
          name: 'Empty',
          isDefault: false,
          steps: const [],
        ),
      ]),
    );

    expect(find.text('No steps yet.'), findsOneWidget);
    expect(find.text('Default for new customers'), findsOneWidget);
  });

  testWidgets('add a step: it is written, then everyone is reloaded', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final people = FakePeopleRepository();
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
      people: people,
    );
    people.calls.clear();

    await _tapVisible(tester, find.text('Add a step'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What to do'),
      'Say thanks',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Days after the previous step'),
      '2',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(workflows.calls, contains('addStep(samples, Say thanks, 2, 6)'));
    expect(find.text('Say thanks'), findsOneWidget);
    // People's current step and due day may have changed on the server.
    expect(people.calls, ['list()']);
  });

  testWidgets('edit a step, then remove it', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    await _tapVisible(tester, find.text('Send the samples'));
    expect(find.text('Step 2'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What to do'),
      'Send the kit',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Days after the previous step'),
      '3',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(workflows.calls, contains('updateStep(samples-2, Send the kit, 3)'));
    expect(find.text('Send the kit'), findsOneWidget);

    await _tapVisible(tester, find.text('Send the kit'));
    await tester.tap(find.text('Remove this step'));
    await tester.pumpAndSettle();
    expect(workflows.calls, contains('removeStep(samples-2)'));
    expect(find.text('Send the kit'), findsNothing);
  });

  testWidgets('Move down puts a step between its two next ones', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    tester.semantics.customAction(_stepNode('Send a first message'), _moveDown);
    await tester.pumpAndSettle();

    // Between Send the samples (2) and Samples arrived (3).
    expect(workflows.calls, contains('moveStep(samples-1, 2.5)'));
    semantics.dispose();
  });

  testWidgets('dragging a step by its handle moves it', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );
    final handle = find.byIcon(Icons.drag_handle_rounded).first;
    await tester.ensureVisible(handle);
    await tester.pumpAndSettle();
    final row = tester
        .getSize(find.widgetWithText(ListTile, 'Send a first message'))
        .height;

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(Offset(0, row / 2));
    await tester.pump();
    await gesture.moveBy(Offset(0, row));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(workflows.calls, contains('moveStep(samples-1, 2.5)'));
  });

  testWidgets('a move while one is saving is ignored', (tester) async {
    final semantics = tester.ensureSemantics();
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );
    workflows.gate = Completer<void>();

    tester.semantics.customAction(_stepNode('Send a first message'), _moveDown);
    await tester.pump();
    // Positions are still the saved ones: this must not be sent.
    tester.semantics.customAction(_stepNode('Samples arrived'), _moveDown);
    await tester.pump();

    final moves = workflows.calls.where((call) => call.startsWith('moveStep'));
    expect(moves, ['moveStep(samples-1, 2.5)']);

    workflows.gate!.complete();
    await tester.pumpAndSettle();
    expect(
      workflows.calls.where((call) => call.startsWith('moveStep')),
      hasLength(1),
    );
    semantics.dispose();
  });

  testWidgets('the switch makes it the default', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('health'),
      workflows: workflows,
    );

    await _tapVisible(tester, find.byType(SwitchListTile));

    expect(workflows.calls, contains('setDefault(health, true)'));
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
  });

  testWidgets('a failed switch says so and shows the saved value', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('health'),
      workflows: workflows,
    );
    workflows.failWith = PeopleFailure.network;

    await _tapVisible(tester, find.byType(SwitchListTile));

    expect(find.text(_failed), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
  });

  testWidgets('delete says who follows it, then returns to the list', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
      people: FakePeopleRepository([
        _on('p1', 'samples'),
        _on('p2', 'samples'),
        _on('p3', 'health'),
      ]),
    );

    await _tapVisible(tester, find.text('Delete workflow'));
    expect(find.text('Delete Samples?'), findsOneWidget);
    expect(
      find.text(
        "2 people follow it. They'll have nothing planned; their history "
        'stays.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(workflows.calls, contains('delete(samples)'));
    expect(find.byType(WorkflowEditor), findsNothing);
    expect(find.text('Health professionals'), findsOneWidget);
    expect(find.text('Samples'), findsNothing);
  });

  testWidgets('delete with no one on it; Cancel deletes nothing', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('health'),
      workflows: workflows,
      people: FakePeopleRepository([_on('p1', 'samples')]),
    );

    await _tapVisible(tester, find.text('Delete workflow'));
    expect(find.text('No one follows it.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(workflows.calls.where((call) => call.startsWith('delete')), isEmpty);
    expect(find.byType(WorkflowEditor), findsOneWidget);
  });
```

Run: `flutter test test/features/workflows/presentation/workflow_editor_test.dart`
Expected: FAIL. The new tests find no steps, no switch and no Delete row yet. The Task 3 tests still pass.

- [ ] **Step 3: Write the full editor**

Replace the whole of `lib/features/workflows/presentation/workflow_editor.dart` with:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/back.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_typography.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/section_header.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/settings/presentation/widgets/settings_group.dart';
import 'package:folo/features/settings/presentation/widgets/settings_scroll.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/step_sheet.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:folo/features/workflows/presentation/workflows_settings.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// One workflow, found in the loaded list (there is no second fetch), wired
/// to saving.
class WorkflowEditor extends ConsumerWidget {
  const WorkflowEditor({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final owner = ref.watch(accountProvider)?.email;
    final workflows = workflowsProvider(owner);
    final state = ref.watch(workflows);
    final list = state.value;
    final workflow = list == null ? null : findWorkflow(list, id);

    // Keeps the people loaded: Delete counts who follows this workflow, and
    // every write reloads them (see WorkflowsController.edit).
    ref.listen(peopleProvider(owner), (_, _) {});

    if (workflow == null) {
      // Still loading, or reloading right after New workflow created it.
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (list == null) {
        return WorkflowsLoadError(onRetry: () => ref.invalidate(workflows));
      }
      // Deleted elsewhere, or a bad link.
      return Center(
        child: EmptyState(
          icon: Icons.route_rounded,
          title: l10n.workflowMissingTitle,
          body: l10n.workflowMissingBody,
          actionLabel: l10n.workflowBackToList,
          onAction: () => context.go(Routes.settingsWorkflows),
        ),
      );
    }

    return SettingsScroll(
      eyebrow: stageLabel(l10n, workflow.stage),
      title: workflow.name,
      child: WorkflowEditorView(
        workflow: workflow,
        onRename: (name) => editWorkflows(
          ref,
          (repository) => repository.rename(workflow.id, name),
        ),
        onAddStep: () => unawaited(showStepSheet(context, workflow)),
        onOpenStep: (index) =>
            unawaited(showStepSheet(context, workflow, index: index)),
        onMove: (step, position) => editWorkflows(
          ref,
          (repository) => repository.moveStep(step.id, position),
        ),
        onDefault: (on) => editWorkflows(
          ref,
          (repository) => repository.setDefault(workflow.id, on),
        ),
        onDelete: () => _delete(context, ref, workflow),
      ),
    );
  }

  /// Asks first, saying who follows it; then deletes and returns to the list.
  static Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Workflow workflow,
  ) async {
    final l10n = AppLocalizations.of(context);
    final people =
        ref.read(peopleProvider(ref.read(accountProvider)?.email)).value ??
        const [];
    final followers = people
        .where((person) => person.place?.workflowId == workflow.id)
        .length;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.workflowDeleteTitle(workflow.name),
      action: l10n.workflowDeleteConfirm,
      body: l10n.workflowDeleteBody(followers),
    );
    if (!confirmed || !context.mounted) return;
    await editWorkflows(ref, (repository) => repository.delete(workflow.id));
    if (context.mounted) backOr(context, Routes.settingsWorkflows);
  }
}

/// What a write in flight disables: the control that started it.
enum _Control { name, steps, isDefault, delete }

/// The editor, fed the saved workflow and one callback per write; each
/// write callback throws `PeopleFailure`. Nothing is optimistic: a dropped
/// step shows in its saved place until the reload lands. Also what the
/// preview shows.
class WorkflowEditorView extends StatefulWidget {
  const WorkflowEditorView({
    required this.workflow,
    required this.onRename,
    required this.onAddStep,
    required this.onOpenStep,
    required this.onMove,
    required this.onDefault,
    required this.onDelete,
    super.key,
  });

  final Workflow workflow;

  /// A trimmed name, different from the saved one.
  final Future<void> Function(String name) onRename;
  final VoidCallback onAddStep;
  final ValueChanged<int> onOpenStep;

  /// [step] goes to [position], among the others' saved positions.
  final Future<void> Function(WorkflowStep step, num position) onMove;
  final Future<void> Function(bool on) onDefault;

  /// Asks first; does nothing when the user cancels.
  final Future<void> Function() onDelete;

  @override
  State<WorkflowEditorView> createState() => _WorkflowEditorViewState();
}

class _WorkflowEditorViewState extends State<WorkflowEditorView> {
  late final _name = TextEditingController(text: widget.workflow.name);
  final _nameFocus = FocusNode();
  final Set<_Control> _busy = {};

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) unawaited(_saveName());
    });
  }

  @override
  void didUpdateWidget(WorkflowEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A reload brought a name saved here or elsewhere; never under the
    // user's fingers.
    if (!_nameFocus.hasFocus && widget.workflow.name != _name.text) {
      _name.text = widget.workflow.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// Runs [write] unless [control] is already writing, and says so when it
  /// fails. Returns whether it saved.
  Future<bool> _run(_Control control, Future<void> Function() write) async {
    if (_busy.contains(control)) return false;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy.add(control));
    try {
      await write();
      return true;
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
      return false;
    } finally {
      if (mounted) setState(() => _busy.remove(control));
    }
  }

  Future<void> _saveName() async {
    final saved = widget.workflow.name;
    final name = _name.text.trim();
    // Empty or unchanged: put the saved name back, write nothing.
    if (name.isEmpty || name == saved) {
      _name.text = saved;
      return;
    }
    _name.text = name;
    final ok = await _run(_Control.name, () => widget.onRename(name));
    if (!ok && mounted) _name.text = widget.workflow.name;
  }

  /// [from] and [to] are indexes in the saved order, [to] counted once [from]
  /// is out of the list: what `onReorderItem` gives, drag or Move down alike.
  void _reorder(int from, int to) {
    final steps = widget.workflow.steps;
    final rest = [...steps]..removeAt(from);
    unawaited(
      _run(
        _Control.steps,
        () => widget.onMove(steps[from], positionAt(rest, to)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final workflow = widget.workflow;
    final steps = workflow.steps;
    final moving = _busy.contains(_Control.steps);
    final error = theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          focusNode: _nameFocus,
          readOnly: _busy.contains(_Control.name),
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: l10n.workflowName),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: l10n.workflowSteps,
          actionLabel: l10n.workflowAddStep,
          onAction: widget.onAddStep,
        ),
        SettingsGroup(
          children: [
            if (steps.isEmpty)
              ListTile(title: Text(l10n.workflowNoSteps))
            else
              // Also gives each row Move up / Move down semantics actions.
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: steps.length,
                onReorderItem: _reorder,
                itemBuilder: (context, index) {
                  final step = steps[index];
                  return ListTile(
                    key: ValueKey(step.id),
                    leading: _NumberBadge(index + 1),
                    title: Text(step.label),
                    subtitle: Text(
                      index == 0 && step.days == 0
                          ? l10n.workflowStepWhenYouStart
                          : l10n.workflowStepDaysAfter(step.days),
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      enabled: !moving,
                      child: const Icon(Icons.drag_handle_rounded),
                    ),
                    onTap: () => widget.onOpenStep(index),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroup(
          children: [
            SwitchListTile(
              value: workflow.isDefault,
              title: Text(l10n.workflowDefaultFor(workflow.stage.name)),
              onChanged: _busy.contains(_Control.isDefault)
                  ? null
                  : (on) => unawaited(
                      _run(_Control.isDefault, () => widget.onDefault(on)),
                    ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.workflowFooter,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.workflowDelete),
              textColor: error,
              iconColor: error,
              onTap: _busy.contains(_Control.delete)
                  ? null
                  : () => unawaited(_run(_Control.delete, widget.onDelete)),
            ),
          ],
        ),
      ],
    );
  }
}

/// A step's number, in a small circle.
class _NumberBadge extends StatelessWidget {
  const _NumberBadge(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final folo = FoloColors.of(context);
    return Container(
      width: AppSpacing.xl,
      height: AppSpacing.xl,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: folo.primaryMuted,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: AppTypography.label.copyWith(color: folo.primaryText),
      ),
    );
  }
}
```

A dropped step goes back to its saved place until the reload lands. That is the spec's "nothing optimistic", and it is why the busy flag has to ignore a second move: that move would be computed from positions the server has already changed.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/workflows/`
Expected: PASS. If the drag test lands on the wrong index, check that the handle is visible (`ensureVisible`) before changing the offsets. The Move down test is the one that pins the arithmetic.

- [ ] **Step 5: Commit**

Run the quality gate, then:

```bash
git add lib/features/workflows/presentation/workflow_editor.dart lib/l10n/app_en.arb test/features/workflows/presentation/workflow_editor_test.dart
git commit -m "feat(workflows): edit steps, reorder, default and delete (#59)"
```

---

### Task 6: Previews, docs, and the final gate

**Files:**
- Create: `lib/features/workflows/presentation/workflows_preview.dart`
- Modify: `test/previews_test.dart`
- Modify: `docs/design/screens.md`
- Modify: `docs/architecture.md`

**Interfaces:**
- Consumes: `WorkflowsView`, `WorkflowEditorView`, `StepForm`, `SettingsScroll`, `stageLabel`.
- Produces: `workflowsListLight`, `workflowEditorLight`, `workflowStepLight`; golden names `workflows_list_light`, `workflow_editor_light`, `workflow_step_light`.

- [ ] **Step 1: Write the previews**

Create `lib/features/workflows/presentation/workflows_preview.dart`:

```dart
import 'package:flutter/widget_previews.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/settings/presentation/widgets/settings_scroll.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/step_sheet.dart';
import 'package:folo/features/workflows/presentation/workflow_editor.dart';
import 'package:folo/features/workflows/presentation/workflows_settings.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:folo/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Settings → Workflows, for `flutter widget-preview start`.
///
/// The sample workflows live here and only here. Nothing in the app imports
/// this file.
@Preview(group: 'Workflows', name: 'List — light', size: Size(390, 844))
Widget workflowsListLight() => _app(
  Builder(
    builder: (context) => SettingsScroll(
      title: AppLocalizations.of(context).settingsSectionWorkflows,
      child: WorkflowsView(workflows: _workflows, onOpen: (_) {}, onNew: () {}),
    ),
  ),
);

@Preview(group: 'Workflows', name: 'Editor — light', size: Size(390, 844))
Widget workflowEditorLight() => _app(
  Builder(
    builder: (context) => SettingsScroll(
      eyebrow: stageLabel(AppLocalizations.of(context), _samples.stage),
      title: _samples.name,
      child: WorkflowEditorView(
        workflow: _samples,
        onRename: (_) async {},
        onAddStep: () {},
        onOpenStep: (_) {},
        onMove: (_, _) async {},
        onDefault: (_) async {},
        onDelete: () async {},
      ),
    ),
  ),
);

@Preview(group: 'Workflows', name: 'Step — light', size: Size(390, 844))
Widget workflowStepLight() => _app(
  Align(
    alignment: Alignment.bottomCenter,
    child: StepForm(
      number: 2,
      step: _samples.steps[1],
      onSave: (_) async {},
      onRemove: () async {},
    ),
  ),
);

Workflow _workflow(
  String id,
  Stage stage,
  String name,
  List<(String, int)> steps, {
  bool isDefault = false,
}) => Workflow(
  id: id,
  stage: stage,
  name: name,
  isDefault: isDefault,
  steps: [
    for (final (index, (label, days)) in steps.indexed)
      WorkflowStep(
        id: '$id-$index',
        position: index + 1,
        label: label,
        days: days,
      ),
  ],
);

final _samples = _workflow('samples', Stage.prospect, 'Samples', [
  ('Send a first message', 0),
  ('Send the samples', 1),
  ('Samples arrived', 4),
  ('Ask how the samples went', 3),
  ('Follow up', 7),
], isDefault: true);

final _workflows = [
  _samples,
  _workflow('health', Stage.prospect, 'Health professionals', [
    ('Introduce yourself', 0),
    ('Share a product sheet', 2),
    ('Offer a sample kit', 5),
    ('Follow up', 7),
  ]),
  _workflow('new-customer', Stage.customer, 'New customer', [
    ('Thank them for the order', 0),
    ('Order arrived', 5),
    ('Check in on the products', 14),
    ('Suggest a refill routine', 21),
  ], isDefault: true),
  _workflow('getting-started', Stage.team, 'Getting started', [
    ('Welcome call', 0),
    ('Unboxing call', 5),
    ('First training', 3),
    ('First goal together', 7),
    ('Two-week check-in', 14),
  ], isDefault: true),
];

Widget _app(Widget body) => MaterialApp(
  debugShowCheckedModeBanner: false,
  // The preview is its own app: without the delegates, any component that
  // reads AppLocalizations throws here.
  localizationsDelegates: localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.light,
  home: Scaffold(body: SafeArea(child: body)),
);
```

- [ ] **Step 2: Register them with the golden test**

In `test/previews_test.dart`, add `import 'package:folo/features/workflows/presentation/workflows_preview.dart';`, and add to the map after the `contacts_desktop_light` entry:

```dart
    'workflows_list_light': (const Size(390, 844), workflowsListLight),
    'workflow_editor_light': (const Size(390, 844), workflowEditorLight),
    'workflow_step_light': (const Size(390, 844), workflowStepLight),
```

Run: `flutter test test/previews_test.dart`
Expected: PASS on macOS (it renders, and pixels are compared on Linux only). Do not run `--update-goldens`, and never commit a PNG.

- [ ] **Step 3: Document the screens**

In `docs/design/screens.md`, insert right before `## Dark mode`:

```markdown
## 7. Settings → Workflows

A row "Workflows" in its own group above Preferences. On desktop the list and
the editor open in the Settings pane (the editor replaces the list, and its
back arrow returns to it); elsewhere each is pushed.

**List** — top bar "Workflows" → intro ("What you usually do with someone,
step by step. Folo puts the next step on Today when it comes due.") → one
group per stage that has workflows (PROSPECTS, CUSTOMERS, TEAM), the default
first, each row trailing "Default · 5 steps" or "4 steps" and a chevron → a
tonal `New workflow` button. New workflow is a dialog (a bottom sheet on a
phone): Name, STAGE chips with Prospect picked, Cancel / Create; Create opens
the editor on it.

**Editor** — the stage as eyebrow, the name as title → Name field, saved when
it loses focus → STEPS with `Add a step`: a numbered row per step, "When you
start" or "3 days after", a drag handle, Move up / Move down for screen
readers → "Default for new prospects" switch → a footer on how steps come due
→ a red "Delete workflow" row, which asks first and says how many people
follow it. Opened after it was deleted elsewhere: "This workflow isn't here
anymore" and `Back to workflows`.

**Step** — "Step 2" or "New step": What to do, Days after the previous step
("Days after starting" for step 1, 0 to 365) with a live "Comes due 3 days
after you tick step 1." hint, an optional Note, and `Remove this step` without
a confirmation: people on it move on and their history stays.

Nothing is optimistic. A control is disabled while its write is in flight; a
failure says "Couldn't save. Check your connection and try again." — inline
in a dialog, which keeps what was typed, and as a snack bar in the editor,
which shows the saved state again.
```

- [ ] **Step 4: Document the seeding rule**

In `docs/architecture.md`, add this bullet right after the one that starts "A rule every reader must agree on lives in Postgres":

```markdown
- Default workflows are seeded once per account, ever (#59). `seed_workflows`
  writes a `workflow_seeded` row the first time and no-ops whenever that row
  exists, even after the user has deleted every workflow. The device asks on
  every workflows load and keeps no memory of having asked; the server
  decides.
```

- [ ] **Step 5: The final gate**

Run, from the repo root:

```bash
dart format .
flutter analyze
flutter test
supabase test db
```

Expected: `flutter analyze` prints "No issues found!"; every test passes. `supabase test db` needs the local stack (`supabase db start`, with Docker); if there is none, say so in the report and leave the check to CI's `migrations` job. **Do not run `supabase db push`.**

Check the copy one last time: `grep -niE 'recruit|\blead\b|\bleads\b|downline|upline|\brank' lib/l10n/app_en.arb` must print nothing that this branch added.

- [ ] **Step 6: Commit**

```bash
git add lib/features/workflows/presentation/workflows_preview.dart test/previews_test.dart docs/design/screens.md docs/architecture.md
git commit -m "docs(workflows): previews, screens and the seeding rule (#59)"
```

- [ ] **Step 7: Hand over the two things only the user does**

Report these, and do nothing about them:

1. **`supabase db push`**, then the backfill check query at the end of Task 1.
2. **Goldens.** CI's `verify` job fails on `workflows_list_light`, `workflow_editor_light` and `workflow_step_light` until their PNGs exist. Once the user agrees to push the branch, follow README → *Golden tests* to have CI generate them. Never commit a PNG made locally.

---

## Self-Review

**Spec coverage.**
- §1 Database: marker, backfill, `seed_workflows` and `set_default` are Task 1. Every pgTAP case in §5 is in Task 1 too. The backfill is the exception: it runs at migration time, which pgTAP cannot replay, so it gets an invariant test plus the manual query for after `db push`.
- §2 Device data and domain: `positionAt`, the eight writes, seed on every build, `edit` and the fake are Task 2.
- §3 Screens:
  - routes, the section, the Settings row, the list, New workflow, name editing and the missing state are Task 3;
  - the step sheet is Task 4;
  - steps, reorder, Move semantics, the switch, the footer and Delete are Task 5;
  - "writes in flight" is `_saving` (Tasks 3 and 4) and `_Control` (Tasks 3 and 5).
- §4 Docs and §5 Goldens are Task 6.
- §5 Widget: every listed case has a named test. "Every write reloads people" is pinned once, through the controller (Task 2), and once through the screen (Task 5, add a step).

**Placeholder scan.** No TBD, TODO or "similar to Task N". Every code step shows the whole code. The one conditional instruction left is Task 5's `flutter/semantics.dart` import, which depends on what `material_ui` exports; the plan says what to do either way.

**Type consistency.**
- `editWorkflows<T>(WidgetRef, write)` is used by `_NewWorkflowForm` (T = `Workflow`), `showStepSheet` and `WorkflowEditor` (T = `void`).
- `positionAt(steps, index)` gets the full list in `showStepSheet` (index = length) and the list minus the moved step in `_reorder`.
- `StepDraft` fields match `addStep` / `updateStep` named parameters.
- `WorkflowEditorView`'s callbacks match the preview's no-ops.
- `SettingsSection.workflows` is handled in `open`, `_Section` and the router.
- Fake call strings in tests match Task 2's `_record` formats.

**Review Focus check.** 1: Task 3 and Task 4 double-tap tests, no frame between taps. 2: Task 4 days test, 400, empty and non-digits. 3: Task 3 dialog and editor tests. 4: Task 3 deleted-elsewhere test, store emptied plus invalidate. 5: Task 5 gated Move down twice.
