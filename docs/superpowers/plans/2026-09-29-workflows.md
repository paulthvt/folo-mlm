# Workflows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Workflows for every person: the `NEXT STEP` card (tick, done, How did it end, paused, nothing planned), Pause/Resume, FOLLOW WITH on Change stage, the Change workflow sheet, and the `step` history kind.

**Architecture:** Postgres holds `workflow` and `workflow_step` under RLS, a person's place (`workflow_id`, sparse `at_position`, `last_tick`, `paused_at`), and two `security invoker` RPCs: `seed_workflows` (default workflows, once per user, starts existing people) and `complete_step` (history entry and move, in one transaction). Dart owns the rules as pure functions in `lib/features/workflows/domain/progress.dart`. A new `workflowsProvider` (family on account email) lists and seeds; `PeopleController` gains the place-changing methods; the contact detail gets a `NextStepSection`.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3.4 (no codegen), supabase_flutter, material_ui / cupertino_ui, pgTAP via `supabase test db`.

**Spec:** `docs/superpowers/specs/2026-09-29-workflows-design.md`

## Global Constraints

- Branch `feature/57-workflows` (exists, spec committed). One PR, body has `Closes #57`. Conventional Commits.
- Import `package:material_ui/material_ui.dart`, never `flutter/material.dart`. `package:folo/...` imports only.
- Colours, spacing, radii only from `Theme.of(context).colorScheme`, `FoloColors.of(context)`, `AppSpacing.*`, `AppRadii.*`. Text styles from `Theme.of(context).textTheme` / `AppTypography`.
- Branch layout on `context.screenSize` (`isMobile` / `isDesktop`), never on pixel widths.
- Copy: EN only, in `lib/l10n/app_en.arb`, each key with a `description`. **Never touch `app_fr.arb`.** Vocabulary prospect / customer / team; never "prospecting", "recruit", "lead", "upline", "downline", "rank", "leaderboard". Copy never guesses a contact's pronouns: the name, "them" or "their".
- Pickers: `CupertinoDatePicker` on `!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS`, `showDatePicker` elsewhere — only through `pickDay` in `lib/core/ui/pick_day.dart`.
- No new dependency.
- Schema changes only through `supabase/migrations/` (`supabase migration new`). Never the dashboard, never `supabase db push` from here: the user pushes after merge, from their own terminal, VPN off.
- "Today" is decided on the device: always `today()` from `lib/core/ui/pick_day.dart` (local midnight), never `current_date` in a query the app relies on.
- Every async controller write checks `ref.mounted` before touching state or invalidating (`_change` already does).
- Goldens: the contact previews change (the card is added to them). Never commit locally made goldens; regenerate through CI (README → *Golden tests*).
- Before claiming a task done: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`. Task 1 instead: `supabase db reset && supabase db lint --fail-on error && supabase test db` (Docker is available).

## Rulings made while planning (deviations from the spec's wording)

- The NEXT STEP card reuses `ActionItem` with a new optional `title`, not a new `core/ui/` component: `docs/design/screens.md` already calls it "one ActionItem", and the shape is identical. Its preview is the existing contact previews, which now show the card.
- `Person` carries the three place columns as one record, `WorkflowPlace? place` (all three set or none), plus `pausedAt`.
- `start()` returns a `WorkflowPlace` (it includes the workflow id). Stage/workflow choices travel as `typedef FollowWith = ({Workflow workflow, DateTime firstDue})`, null meaning "Nothing for now".
- Changing the workflow clears `paused_at`: picking what comes next is the opposite of pausing.
- `progressOf`: paused wins, even with no workflow (the card shows "Paused since" and Resume).
- Saving Change workflow always starts the picked workflow from step 1, even when it is the current one: the sheet is a restart, not an edit.

## Review Focus

1. Tick tapped twice before the server answers: the step must complete once, not skip the next step — Task 8 test (tick hidden while in flight).
2. The person's workflow is not in the list (deleted on another device, list not reloaded): the card shows "Nothing planned", nothing throws — Task 3 test.
3. The book rebuilt (pull to refresh, sign-out) while a tick is in flight: no throw, no write to a dead state — Task 5 test.
4. A first-step date in the past must be impossible in FOLLOW WITH: the picker's first day is today — Task 7 test.
5. Log something never offers Step as a kind — Task 5 test.

## Files

| File | Responsibility |
| --- | --- |
| `supabase/migrations/<ts>_workflows.sql` | tables, person columns, RLS, RPCs, trigger update |
| `supabase/tests/workflow_test.sql` | pgTAP for the above |
| `lib/core/ui/pick_day.dart` | `today()`, `first` bound |
| `lib/core/ui/action_item.dart` | optional `title` |
| `lib/features/contacts/domain/person.dart` | `WorkflowPlace`, `place`, `pausedAt` |
| `lib/features/contacts/domain/activity.dart` | `ActivityKind.step`, `byUser` |
| `lib/features/contacts/data/people_repository.dart` | place mapping, `dayColumn`, new writes |
| `lib/features/contacts/data/activity_repository.dart` | uses `dayColumn` |
| `lib/features/workflows/domain/workflow.dart` | `Workflow`, `WorkflowStep`, `FollowWith`, lookups |
| `lib/features/workflows/domain/progress.dart` | progress, `nextPosition`, `start`, dates |
| `lib/features/workflows/data/workflow_repository.dart` | `workflow` tables, seed RPC |
| `lib/features/workflows/presentation/workflows_controller.dart` | `workflowsProvider` |
| `lib/features/contacts/presentation/people_controller.dart` | place-changing methods |
| `lib/features/contacts/presentation/people_copy.dart` | due line, paused subtitle, step kind |
| `lib/features/contacts/presentation/next_step_section.dart` | `NextStepCard` (pure), `NextStepSection` |
| `lib/features/contacts/presentation/follow_with_field.dart` | the follow-with block |
| `lib/features/contacts/presentation/change_stage_sheet.dart` | follow-with + "workflow ends" |
| `lib/features/contacts/presentation/change_workflow_sheet.dart` | Change workflow |
| `lib/features/contacts/presentation/contact_details.dart` | card slot, ⋯ rows |
| `lib/features/contacts/presentation/contact_page.dart` | wiring |
| `lib/features/contacts/presentation/contacts_page.dart` | loads workflows early |
| `lib/features/contacts/presentation/add_person_sheet.dart` | default workflow |
| `lib/features/contacts/presentation/contact_list.dart` | paused subtitle |
| `lib/features/contacts/presentation/log_activity_sheet.dart` | kind filter, `today()` |
| `lib/features/contacts/presentation/contacts_preview.dart` | card in previews |
| `test/features/workflows/fake_workflow_repository.dart` | in-memory fake + samples |
| `test/app/app_harness.dart`, `test/features/contacts/presentation/form_harness.dart` | workflow override |

---

### Task 1: The database — workflows, a person's place, the RPCs

**Files:**
- Create: `supabase/migrations/<timestamp>_workflows.sql` (via `supabase migration new workflows`)
- Create: `supabase/tests/workflow_test.sql`

**Interfaces:**
- Produces: tables `workflow(id, owner_id, stage, name, is_default, created_at, updated_at)` and `workflow_step(id, owner_id, workflow_id, position numeric, label, days, note, created_at, updated_at)`; columns `person.workflow_id uuid`, `person.at_position numeric`, `person.last_tick date`, `person.paused_at timestamptz`; enum value `activity_kind 'step'`; RPC `seed_workflows(p_lang text, p_today date) returns void`; RPC `complete_step(p_person uuid, p_step uuid, p_next_position numeric, p_on date) returns public.person`. Later tasks use these exact names.

- [ ] **Step 1: Write the failing pgTAP test**

Create `supabase/tests/workflow_test.sql`:

```sql
-- Workflows: each user's own, seeded once, a person's place moved by
-- complete_step, and cleaned up by deletes and stage changes.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

-- As A.
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Sarah', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a2', 'Claire', 'customer');

select lives_ok(
  $$ select public.seed_workflows('en', '2026-09-29') $$,
  'the first seed runs'
);
select lives_ok(
  $$ select public.seed_workflows('en', '2026-09-29') $$,
  'a second seed runs'
);
select is(
  (select count(*)::int from public.workflow), 5,
  'seeding twice inserts the five workflows once'
);
select is(
  (select count(*)::int from public.workflow where is_default), 3,
  'one default per stage'
);
select is(
  (select count(*)::int from public.workflow_step), 20,
  'the steps come along'
);
select results_eq(
  $$ select w.name, p.at_position, p.last_tick
     from public.person p join public.workflow w on w.id = p.workflow_id
     where p.id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values ('Samples'::text, 1::numeric, '2026-09-29'::date) $$,
  'the seed starts an existing person on their stage''s default'
);
select throws_ok(
  $$ insert into public.workflow (stage, name, is_default)
     values ('prospect', 'Another', true) $$,
  '23505', null,
  'a stage has at most one default'
);

-- A workflow with a known id, for the foreign key tests as B.
insert into public.workflow (id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'team', 'Own');

select lives_ok(
  $$ select public.complete_step(
       '00000000-0000-0000-0000-0000000000a1',
       (select s.id from public.workflow_step s
          join public.workflow w on w.id = s.workflow_id
          where w.name = 'Samples' and s.position = 1),
       2, '2026-09-30') $$,
  'complete_step runs'
);
select is(
  (select text from public.activity where kind = 'step'),
  'Send a first message',
  'complete_step writes one step entry with the label'
);
select results_eq(
  $$ select at_position, last_tick from public.person
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values (2::numeric, '2026-09-30'::date) $$,
  'complete_step moves the person'
);
select throws_ok(
  $$ select public.complete_step(
       '00000000-0000-0000-0000-0000000000a1',
       (select s.id from public.workflow_step s
          join public.workflow w on w.id = s.workflow_id
          where w.name = 'Health professionals' and s.position = 1),
       2, '2026-09-30') $$,
  'P0002', null,
  'complete_step refuses a step of another workflow'
);

update public.person set paused_at = now()
  where id = '00000000-0000-0000-0000-0000000000a1';
update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';

select is(
  (select paused_at from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'), null,
  'a stage change clears paused_at'
);

-- As B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';

select is(
  (select count(*)::int from public.workflow), 0,
  'another user sees none of the workflows'
);
select is(
  (select count(*)::int from public.workflow_step), 0,
  'another user sees none of the steps'
);
update public.workflow set name = 'Stolen';
delete from public.workflow;
select throws_ok(
  $$ insert into public.workflow_step (workflow_id, position, label, days)
     values ('00000000-0000-0000-0000-0000000000f1', 1, 'Mine', 0) $$,
  '23503', null,
  'a step cannot point at another user''s workflow'
);
select throws_ok(
  $$ insert into public.person (name, stage, workflow_id)
     values ('Bea', 'team', '00000000-0000-0000-0000-0000000000f1') $$,
  '23503', null,
  'a person cannot point at another user''s workflow'
);
select public.seed_workflows('fr', '2026-09-29');
select is(
  (select count(*)::int from public.workflow where name = 'Échantillons'), 1,
  'the seed speaks French when asked'
);

-- Back as A.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select is(
  (select count(*)::int from public.workflow where name <> 'Stolen'), 6,
  'another user cannot update or delete the workflows'
);

delete from public.workflow where name = 'New customer';

select is(
  (select count(*)::int from public.person
    where id = '00000000-0000-0000-0000-0000000000a2'
      and workflow_id is null), 1,
  'deleting a workflow sets its people''s workflow_id to null'
);

-- As anon.
set local role anon;
set local request.jwt.claims = '{"role": "anon"}';

select throws_ok(
  'select * from public.workflow', '42501', null,
  'anon cannot read workflows'
);
select throws_ok(
  'select * from public.workflow_step', '42501', null,
  'anon cannot read steps'
);
select throws_ok(
  $$ select public.seed_workflows('en', '2026-09-29') $$, '42501', null,
  'anon cannot seed'
);

reset role;

select table_privs_are(
  'public', 'workflow', 'authenticated',
  ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'authenticated has only SELECT, INSERT, UPDATE, DELETE on workflow'
);
select table_privs_are(
  'public', 'workflow_step', 'authenticated',
  ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'authenticated has only SELECT, INSERT, UPDATE, DELETE on workflow_step'
);

select * from finish();
rollback;
```

The line `select public.seed_workflows('fr', ...)` as B returns one empty row; it is not a test and pg_prove ignores it (same as a bare `select`). If `supabase test db` complains, wrap it in `select lives_ok(...)` and raise `plan` to 25.

- [ ] **Step 2: Run it to verify it fails**

Run: `supabase db reset && supabase test db`
Expected: FAIL — `relation "public.workflow" does not exist` / function missing.

- [ ] **Step 3: Write the migration**

Run `supabase migration new workflows`, then fill the created file:

```sql
-- Workflows (#57): each user's own lists of steps, a person's place in one,
-- and pausing. Rules live in Dart (lib/features/workflows/domain/progress.dart);
-- the database keeps them consistent and does the two multi-row writes.

alter type public.activity_kind add value 'step';

create table public.workflow (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  stage public.person_stage not null,
  name text not null check (length(trim(name)) > 0),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Target of the composite foreign keys below.
  unique (id, owner_id)
);

-- One default per stage.
create unique index workflow_default_idx
  on public.workflow (owner_id, stage) where is_default;

create table public.workflow_step (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  workflow_id uuid not null,
  -- Sparse: an inserted step takes the midpoint, so no other position moves.
  position numeric not null,
  label text not null check (length(trim(label)) > 0),
  days int not null check (days >= 0),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete cascade,
  unique (workflow_id, position)
);

create index workflow_step_workflow_id_owner_id_idx
  on public.workflow_step (workflow_id, owner_id);

alter table public.person
  add column workflow_id uuid,
  add column at_position numeric,
  add column last_tick date,
  add column paused_at timestamptz,
  add foreign key (workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (workflow_id);

create index person_workflow_id_idx on public.person (workflow_id);

create trigger workflow_set_updated_at before update on public.workflow
  for each row execute function public.set_updated_at();
create trigger workflow_step_set_updated_at before update on public.workflow_step
  for each row execute function public.set_updated_at();

alter table public.workflow enable row level security;
alter table public.workflow_step enable row level security;

create policy workflow_select_own on public.workflow
  for select to authenticated using (owner_id = (select auth.uid()));
create policy workflow_insert_own on public.workflow
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy workflow_update_own on public.workflow
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy workflow_delete_own on public.workflow
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy workflow_step_select_own on public.workflow_step
  for select to authenticated using (owner_id = (select auth.uid()));
create policy workflow_step_insert_own on public.workflow_step
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy workflow_step_update_own on public.workflow_step
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy workflow_step_delete_own on public.workflow_step
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.workflow, public.workflow_step from anon, authenticated;
grant select, insert, update, delete
  on public.workflow, public.workflow_step to authenticated;

-- A stage change also ends a pause. Same function as #56, one line more.
create or replace function public.person_stage_changed() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.stage_since = now();
  new.paused_at = null;
  if new.stage <> 'prospect' then
    new.prospect_status = null;
  end if;
  insert into public.activity (owner_id, person_id, kind, stage)
    values (new.owner_id, new.id, 'stage', new.stage);
  return new;
end $$;

-- The default workflows (spec §2.1), once per user, in English or French;
-- then everyone without a workflow starts their stage's default. plpgsql so
-- the new 'step' value is not resolved while this migration's transaction
-- is still open.
create function public.seed_workflows(p_lang text, p_today date) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  fr constant boolean := p_lang = 'fr';
  w record;
  new_id uuid;
begin
  -- Two devices seeding at once: the second waits, then finds the first's.
  perform pg_advisory_xact_lock(hashtext((select auth.uid())::text));
  if exists (select 1 from public.workflow) then
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
    set workflow_id = w.id, at_position = 1, last_tick = p_today
    from public.workflow w
    where w.stage = p.stage and w.is_default and p.workflow_id is null;
end $$;

-- Ticks a step: the history entry, with the label as it reads today, and the
-- person's new place, in one transaction. Dart computes p_next_position.
create function public.complete_step(
  p_person uuid, p_step uuid, p_next_position numeric, p_on date
) returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  step_label text;
  moved public.person;
begin
  select s.label into step_label
    from public.workflow_step s
    join public.person p on p.workflow_id = s.workflow_id
    where s.id = p_step and p.id = p_person;
  if step_label is null then
    raise exception 'step % is not on the workflow of person %', p_step, p_person
      using errcode = 'P0002';
  end if;

  insert into public.activity (person_id, kind, text, happened_on)
    values (p_person, 'step', step_label, p_on);
  update public.person
    set at_position = p_next_position, last_tick = p_on
    where id = p_person
    returning * into moved;
  return moved;
end $$;

revoke execute on function public.seed_workflows(text, date) from public, anon;
revoke execute on function public.complete_step(uuid, uuid, numeric, date)
  from public, anon;
grant execute on function public.seed_workflows(text, date) to authenticated;
grant execute on function public.complete_step(uuid, uuid, numeric, date)
  to authenticated;
```

- [ ] **Step 4: Run the database checks**

Run: `supabase db reset && supabase db lint --fail-on error && supabase test db`
Expected: all tests pass, `activity_test.sql` and `person_rls_test.sql` included. If `alter type ... add value` fails inside the migration's transaction, move it to its own migration file created first (`supabase migration new step_kind`), then reset again.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_workflows.sql supabase/tests/workflow_test.sql
git commit -m "feat(db): workflows, a person's place, seed and complete_step (#57)"
```

---
### Task 2: A person's place — `Person`, `PeopleRepository`, the fake

**Files:**
- Modify: `lib/core/ui/pick_day.dart` (add `today()`)
- Modify: `lib/features/contacts/domain/person.dart`
- Modify: `lib/features/contacts/data/people_repository.dart`
- Modify: `lib/features/contacts/data/activity_repository.dart` (drop `_dayColumn`, use `dayColumn`)
- Modify: `lib/features/contacts/presentation/log_activity_sheet.dart` (drop `_today`, use `today()`)
- Modify: `test/features/contacts/fake_people_repository.dart`
- Test: `test/features/contacts/data/people_repository_test.dart`

**Interfaces:**
- Consumes: the Task 1 columns `workflow_id`, `at_position`, `last_tick`, `paused_at`, RPC `complete_step`.
- Produces:
  - `DateTime today()` in `pick_day.dart` (local midnight).
  - `typedef WorkflowPlace = ({String workflowId, num atPosition, DateTime lastTick});` in `person.dart`.
  - `Person.place` (`WorkflowPlace?`), `Person.pausedAt` (`DateTime?`); both constructor params optional; `withStatus` keeps them.
  - `String dayColumn(DateTime day)`, `Map<String, dynamic> placeToRow(WorkflowPlace? place)` in `people_repository.dart`.
  - `PeopleRepository`: `add(PersonDraft draft, {WorkflowPlace? place})`, `setStage(String id, Stage stage, {WorkflowPlace? place})` (always writes the place; null clears it), `setPlace(String id, WorkflowPlace? place)` (also clears `paused_at`), `pause(String id, DateTime at, {required bool notNow})`, `resume(String id, DateTime today)`, `completeStep(String personId, String stepId, num nextPosition, DateTime on)` — each returns `Future<Person>`.
  - Fake calls strings: `add(<name>)`, `setStage(<id>, <stage>)`, `setPlace(<id>, <workflowId|none>)`, `pause(<id>)`, `resume(<id>)`, `completeStep(<id>, <stepId>)`.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/contacts/data/people_repository_test.dart` (inside `main`; add imports if missing):

```dart
  group('a person\'s place', () {
    Map<String, dynamic> row([Map<String, dynamic> extra = const {}]) => {
      'id': 'p1',
      'name': 'Sarah',
      'stage': 'prospect',
      'stage_since': '2026-09-01T10:00:00Z',
      ...extra,
    };

    test('reads the workflow fields, last_tick as a local day', () {
      final person = personFromRow(
        row({
          'workflow_id': 'w1',
          'at_position': 2.5,
          'last_tick': '2026-09-28',
          'paused_at': '2026-09-29T08:00:00Z',
        }),
      );

      expect(person.place?.workflowId, 'w1');
      expect(person.place?.atPosition, 2.5);
      expect(person.place?.lastTick, DateTime(2026, 9, 28));
      expect(person.pausedAt, DateTime.utc(2026, 9, 29, 8));
    });

    test('no workflow is no place, and a half-written one too', () {
      expect(personFromRow(row()).place, isNull);
      expect(
        personFromRow(row({'workflow_id': null, 'at_position': 1})).place,
        isNull,
      );
      expect(personFromRow(row()).pausedAt, isNull);
    });

    test('writes a place as three columns, and null as three nulls', () {
      expect(
        placeToRow((
          workflowId: 'w1',
          atPosition: 3,
          lastTick: DateTime(2026, 1, 5),
        )),
        {'workflow_id': 'w1', 'at_position': 3, 'last_tick': '2026-01-05'},
      );
      expect(placeToRow(null), {
        'workflow_id': null,
        'at_position': null,
        'last_tick': null,
      });
    });

    test('withStatus keeps the place and the pause', () {
      final person = personFromRow(
        row({
          'workflow_id': 'w1',
          'at_position': 1,
          'last_tick': '2026-09-28',
          'paused_at': '2026-09-29T08:00:00Z',
        }),
      ).withStatus(ProspectStatus.thinking);

      expect(person.place?.workflowId, 'w1');
      expect(person.pausedAt, isNotNull);
    });
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/contacts/data/people_repository_test.dart`
Expected: FAIL — `place` / `placeToRow` not defined.

- [ ] **Step 3: Implement**

`lib/core/ui/pick_day.dart`, after the imports:

```dart
/// The device's today, as local midnight: "today" is decided on the device,
/// never by the server (#48).
DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
```

`lib/features/contacts/presentation/log_activity_sheet.dart`: delete `_today()` and replace both uses with `today()` (already imported through `pick_day.dart`).

`lib/features/contacts/domain/person.dart`: add above `class Person`:

```dart
/// Where someone is in a workflow (#57). The current step is the first whose
/// position is at least [atPosition], due its days after [lastTick]. All three
/// are set together or not at all.
typedef WorkflowPlace = ({String workflowId, num atPosition, DateTime lastTick});
```

Add to the constructor `this.place, this.pausedAt,` (after `this.notes`), the fields:

```dart
  /// Null when they follow no workflow.
  final WorkflowPlace? place;

  /// Set while paused: the NEXT STEP card rests, the place is kept.
  final DateTime? pausedAt;
```

and `place: place, pausedAt: pausedAt,` in `withStatus`.

`lib/features/contacts/data/people_repository.dart`: replace the body of `update` and `setStage` with a shared `_write`, and add the new writes:

```dart
  Future<Person> add(PersonDraft draft, {WorkflowPlace? place}) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .insert({...draftToRow(draft), ...placeToRow(place)})
            .select()
            .single();
        return personFromRow(row);
      });

  Future<Person> update(Person person) =>
      _write(person.id, personToRow(person));

  Future<void> delete(String id) =>
      guardPeople(() => _client.from(_table).delete().eq('id', id));

  /// Writes the stage and the workflow that follows it, in one update; a null
  /// [place] is "nothing for now". The database sets [Person.stageSince],
  /// clears a leaving prospect's status and any pause, and records the change
  /// in the history; the returned person is the row as it left it.
  Future<Person> setStage(String id, Stage stage, {WorkflowPlace? place}) =>
      _write(id, {'stage': stage.name, ...placeToRow(place)});

  /// Change workflow. Picking what comes next also ends a pause.
  Future<Person> setPlace(String id, WorkflowPlace? place) =>
      _write(id, {...placeToRow(place), 'paused_at': null});

  /// [notNow] also sets a prospect's status to Not now.
  Future<Person> pause(String id, DateTime at, {required bool notNow}) =>
      _write(id, {
        'paused_at': at.toUtc().toIso8601String(),
        if (notNow) 'prospect_status': _statusColumn[ProspectStatus.notNow],
      });

  /// The same step comes back, due counted from [today].
  Future<Person> resume(String id, DateTime today) =>
      _write(id, {'paused_at': null, 'last_tick': dayColumn(today)});

  /// The history entry and the move, in one transaction on the server.
  Future<Person> completeStep(
    String personId,
    String stepId,
    num nextPosition,
    DateTime on,
  ) => guardPeople(() async {
    final row = await _client.rpc(
      'complete_step',
      params: {
        'p_person': personId,
        'p_step': stepId,
        'p_next_position': nextPosition,
        'p_on': dayColumn(on),
      },
    );
    return personFromRow(row as Map<String, dynamic>);
  });

  Future<Person> _write(String id, Map<String, dynamic> values) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .update(values)
            .eq('id', id)
            .select()
            .single();
        return personFromRow(row);
      });
```

In `personFromRow`, add after `stageSince`:

```dart
    place: switch ((row['workflow_id'], row['at_position'], row['last_tick'])) {
      (final String id, final num at, final String tick) => (
        workflowId: id,
        atPosition: at,
        // A bare date parses as local midnight, which is what a day is here.
        lastTick: DateTime.parse(tick),
      ),
      _ => null,
    },
    pausedAt: switch (row['paused_at']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
```

Update `personToRow`'s doc: "everything the user can edit, except the stage and the workflow fields". Add at the end of the file:

```dart
Map<String, dynamic> placeToRow(WorkflowPlace? place) => {
  'workflow_id': place?.workflowId,
  'at_position': place?.atPosition,
  'last_tick': place == null ? null : dayColumn(place.lastTick),
};

/// `yyyy-MM-dd`, what a `date` column takes; no locale involved.
String dayColumn(DateTime day) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}
```

`lib/features/contacts/data/activity_repository.dart`: delete `_dayColumn` and call `dayColumn` (it already imports `people_repository.dart`).

- [ ] **Step 4: Update the fake**

Replace in `test/features/contacts/fake_people_repository.dart` everything from `@override Future<Person> add` to the end of the class with:

```dart
  @override
  Future<Person> add(PersonDraft draft, {WorkflowPlace? place}) async {
    await _record('add(${draft.name})');
    final person = Person(
      id: 'new-${_next++}',
      name: draft.name.trim(),
      stage: draft.stage,
      stageSince: DateTime.utc(2026, 9, 28),
      phone: draft.phone,
      email: draft.email,
      instagram: draft.instagram,
      place: place,
    );
    store[person.id] = person;
    return person;
  }

  @override
  Future<Person> update(Person person) async {
    await _record('update(${person.id})');
    // The real update writes neither the stage nor the workflow fields.
    final stored = store[person.id]!;
    final saved = Person(
      id: person.id,
      name: person.name,
      stage: stored.stage,
      stageSince: stored.stageSince,
      prospectStatus: stored.stage == Stage.prospect
          ? person.prospectStatus
          : null,
      phone: person.phone,
      email: person.email,
      instagram: person.instagram,
      needs: person.needs,
      products: person.products,
      profession: person.profession,
      address: person.address,
      notes: person.notes,
      place: stored.place,
      pausedAt: stored.pausedAt,
    );
    store[person.id] = saved;
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    await _record('delete($id)');
    store.remove(id);
  }

  /// What the database does on a stage change: a new [Person.stageSince], no
  /// status outside prospects, no pause, and an entry in the history.
  @override
  Future<Person> setStage(String id, Stage stage, {WorkflowPlace? place}) async {
    await _record('setStage($id, ${stage.name})');
    final before = store[id]!;
    final moved = _with(
      before,
      stage: stage,
      stageSince: DateTime.utc(2026, 9, 28),
      status: before.prospectStatus,
      place: place,
      pausedAt: null,
    );
    activities?.recordStage(id, stage);
    return moved;
  }

  @override
  Future<Person> setPlace(String id, WorkflowPlace? place) async {
    await _record('setPlace($id, ${place?.workflowId ?? 'none'})');
    final before = store[id]!;
    return _with(before, place: place, pausedAt: null);
  }

  @override
  Future<Person> pause(String id, DateTime at, {required bool notNow}) async {
    await _record('pause($id)');
    final before = store[id]!;
    return _with(
      before,
      status: notNow ? ProspectStatus.notNow : before.prospectStatus,
      place: before.place,
      pausedAt: at,
    );
  }

  @override
  Future<Person> resume(String id, DateTime today) async {
    await _record('resume($id)');
    final before = store[id]!;
    final place = before.place;
    return _with(
      before,
      place: place == null
          ? null
          : (
              workflowId: place.workflowId,
              atPosition: place.atPosition,
              lastTick: today,
            ),
      pausedAt: null,
    );
  }

  @override
  Future<Person> completeStep(
    String personId,
    String stepId,
    num nextPosition,
    DateTime on,
  ) async {
    await _record('completeStep($personId, $stepId)');
    final before = store[personId]!;
    return _with(
      before,
      place: (
        workflowId: before.place!.workflowId,
        atPosition: nextPosition,
        lastTick: on,
      ),
      pausedAt: before.pausedAt,
    );
  }

  /// [before] with the given fields replaced, stored and returned. Stage and
  /// status default to [before]'s; a status never survives outside prospects.
  Person _with(
    Person before, {
    Stage? stage,
    DateTime? stageSince,
    ProspectStatus? status,
    required WorkflowPlace? place,
    required DateTime? pausedAt,
  }) {
    final newStage = stage ?? before.stage;
    final person = Person(
      id: before.id,
      name: before.name,
      stage: newStage,
      stageSince: stageSince ?? before.stageSince,
      prospectStatus: newStage == Stage.prospect
          ? status ?? before.prospectStatus
          : null,
      phone: before.phone,
      email: before.email,
      instagram: before.instagram,
      needs: before.needs,
      products: before.products,
      profession: before.profession,
      address: before.address,
      notes: before.notes,
      place: place,
      pausedAt: pausedAt,
    );
    store[person.id] = person;
    return person;
  }
}
```

- [ ] **Step 5: Run the checks**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all tests pass (existing `add`/`setStage` callers compile: the new parameters are optional).

- [ ] **Step 6: Commit**

```bash
git add lib/core/ui/pick_day.dart lib/features/contacts test/features/contacts
git commit -m "feat(contacts): a person's place in a workflow, and the writes that move it (#57)"
```

---

### Task 3: The workflows domain — progress and the edit rules

**Files:**
- Create: `lib/features/workflows/domain/workflow.dart`
- Create: `lib/features/workflows/domain/progress.dart`
- Test: `test/features/workflows/domain/progress_test.dart`

**Interfaces:**
- Consumes: `Person`, `Stage`, `WorkflowPlace` (Task 2).
- Produces:
  - `class WorkflowStep({required String id, required num position, required String label, required int days, String? note})`.
  - `class Workflow({required String id, required Stage stage, required String name, required bool isDefault, required List<WorkflowStep> steps})`, `steps` sorted by position, unmodifiable.
  - `typedef FollowWith = ({Workflow workflow, DateTime firstDue});` — null means "Nothing for now".
  - `Workflow? findWorkflow(List<Workflow> workflows, String? id)`, `Workflow? defaultFor(List<Workflow> workflows, Stage stage)`, `List<Workflow> forStage(List<Workflow> workflows, Stage stage)` (default first, then by name).
  - `sealed class WorkflowProgress`; `Paused(DateTime since)`; `Done(Workflow workflow)`; `OnStep({required Workflow workflow, required WorkflowStep step, required int index, required int total, required DateTime due})`.
  - `WorkflowProgress? progressOf(Person person, Workflow? workflow)`, `num nextPosition(Workflow workflow, WorkflowStep current)`, `WorkflowPlace start(Workflow workflow, {required DateTime firstDue})`, `DateTime firstDueDefault(Workflow workflow, DateTime today)`, `DateTime addDays(DateTime day, int days)`, `int daysBetween(DateTime from, DateTime to)`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/workflows/domain/progress_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

WorkflowStep _step(num position, String label, int days, {String? note}) =>
    WorkflowStep(
      id: 's$position',
      position: position,
      label: label,
      days: days,
      note: note,
    );

Workflow _samples([List<WorkflowStep>? steps]) => Workflow(
  id: 'w1',
  stage: Stage.prospect,
  name: 'Samples',
  isDefault: true,
  steps:
      steps ??
      [
        _step(1, 'Send a first message', 0),
        _step(2, 'Send the samples', 1),
        _step(3, 'Samples arrived', 4),
      ],
);

Person _on(num atPosition, {DateTime? lastTick, DateTime? pausedAt}) => Person(
  id: 'p1',
  name: 'Sarah',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 9, 1),
  place: (
    workflowId: 'w1',
    atPosition: atPosition,
    lastTick: lastTick ?? DateTime(2026, 9, 28),
  ),
  pausedAt: pausedAt,
);

void main() {
  test('the current step is the first at or after the position', () {
    final progress = progressOf(_on(2), _samples()) as OnStep;

    expect(progress.step.label, 'Send the samples');
    expect(progress.index, 2);
    expect(progress.total, 3);
    expect(progress.due, DateTime(2026, 9, 29));
  });

  test('steps come sorted by position whatever the order given', () {
    final workflow = _samples([_step(3, 'C', 0), _step(1, 'A', 0)]);

    expect([for (final s in workflow.steps) s.label], ['A', 'C']);
  });

  test('days changed: the due date follows at once', () {
    final workflow = _samples([
      _step(1, 'Send a first message', 0),
      _step(2, 'Send the samples', 5),
    ]);

    expect((progressOf(_on(2), workflow) as OnStep).due, DateTime(2026, 10, 3));
  });

  test('current step removed: the next one becomes current', () {
    final workflow = _samples([
      _step(1, 'Send a first message', 0),
      _step(3, 'Samples arrived', 4),
    ]);

    expect(
      (progressOf(_on(2), workflow) as OnStep).step.label,
      'Samples arrived',
    );
  });

  test('a step inserted before the current one is skipped', () {
    final workflow = _samples([
      _step(1, 'Send a first message', 0),
      _step(1.5, 'Inserted', 2),
      _step(2, 'Send the samples', 1),
    ]);

    final progress = progressOf(_on(2), workflow) as OnStep;
    expect(progress.step.label, 'Send the samples');
    expect(progress.index, 3);
  });

  test('a rename shows at once', () {
    final workflow = _samples([_step(1, 'Say hello', 0)]);

    expect((progressOf(_on(1), workflow) as OnStep).step.label, 'Say hello');
  });

  test('past the last step is done; a workflow with no steps too', () {
    expect(progressOf(_on(4), _samples()), isA<Done>());
    expect(progressOf(_on(1), _samples(const [])), isA<Done>());
  });

  test('paused wins over everything, even no workflow', () {
    final since = DateTime.utc(2026, 7, 12);

    expect(progressOf(_on(2, pausedAt: since), _samples()), isA<Paused>());
    final nobody = Person(
      id: 'p2',
      name: 'Claire',
      stage: Stage.customer,
      stageSince: DateTime.utc(2026, 9, 1),
      pausedAt: since,
    );
    expect((progressOf(nobody, null) as Paused).since, since);
  });

  test('no workflow, or one that is not in the list, is no progress', () {
    final nobody = Person(
      id: 'p2',
      name: 'Claire',
      stage: Stage.customer,
      stageSince: DateTime.utc(2026, 9, 1),
    );
    expect(progressOf(nobody, _samples()), isNull);
    // Deleted on another device: the person still points at it.
    expect(progressOf(_on(2), null), isNull);
    expect(progressOf(_on(2), findWorkflow(const [], 'w1')), isNull);
  });

  test('resumed on a finished workflow, it is still done', () {
    expect(progressOf(_on(4, lastTick: DateTime(2026, 10, 1)), _samples()),
        isA<Done>());
  });

  test('nextPosition: the next step, or one past the last', () {
    final workflow = _samples();

    expect(nextPosition(workflow, workflow.steps[0]), 2);
    expect(nextPosition(workflow, workflow.steps[2]), 4);
    expect(
      progressOf(_on(nextPosition(workflow, workflow.steps[2])), workflow),
      isA<Done>(),
    );
  });

  test('start puts the first step on the chosen day', () {
    final workflow = _samples([_step(1, 'Welcome call', 3)]);

    final place = start(workflow, firstDue: DateTime(2026, 10, 2));

    expect(place.workflowId, 'w1');
    expect(place.atPosition, 1);
    expect(place.lastTick, DateTime(2026, 9, 29));
    expect(firstDueDefault(workflow, DateTime(2026, 9, 29)),
        DateTime(2026, 10, 2));
  });

  test('days are calendar days, across a clock change', () {
    // Paris moves its clocks back on 25 October 2026.
    expect(daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
    expect(addDays(DateTime(2026, 10, 24), 2), DateTime(2026, 10, 26));
  });

  test('forStage: the default first, then by name', () {
    final workflows = [
      Workflow(id: 'b', stage: Stage.customer, name: 'B', isDefault: false, steps: const []),
      Workflow(id: 'z', stage: Stage.customer, name: 'Z', isDefault: true, steps: const []),
      _samples(),
    ];

    expect([for (final w in forStage(workflows, Stage.customer)) w.id], ['z', 'b']);
    expect(defaultFor(workflows, Stage.customer)?.id, 'z');
    expect(defaultFor(workflows, Stage.team), isNull);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/workflows/domain/progress_test.dart`
Expected: FAIL — the files don't exist.

- [ ] **Step 3: Implement**

Create `lib/features/workflows/domain/workflow.dart`:

```dart
import 'package:folo/features/contacts/domain/person.dart';

/// One step: [days] after the previous one (after the start, for the first).
class WorkflowStep {
  const WorkflowStep({
    required this.id,
    required this.position,
    required this.label,
    required this.days,
    this.note,
  });

  final String id;

  /// Sparse: an inserted step takes the midpoint, so no other one moves.
  final num position;
  final String label;
  final int days;
  final String? note;
}

/// A user's list of steps for one stage. Their own data once seeded.
class Workflow {
  Workflow({
    required this.id,
    required this.stage,
    required this.name,
    required this.isDefault,
    required List<WorkflowStep> steps,
  }) : steps = List.unmodifiable(
         [...steps]..sort((a, b) => a.position.compareTo(b.position)),
       );

  final String id;
  final Stage stage;
  final String name;

  /// The one someone new at [stage] starts.
  final bool isDefault;

  /// Sorted by position.
  final List<WorkflowStep> steps;
}

/// What Change stage and Change workflow pick; null is "Nothing for now".
typedef FollowWith = ({Workflow workflow, DateTime firstDue});

Workflow? findWorkflow(List<Workflow> workflows, String? id) =>
    workflows.where((workflow) => workflow.id == id).firstOrNull;

Workflow? defaultFor(List<Workflow> workflows, Stage stage) => workflows
    .where((workflow) => workflow.stage == stage && workflow.isDefault)
    .firstOrNull;

/// The choices for [stage]: the default first, then by name.
List<Workflow> forStage(List<Workflow> workflows, Stage stage) =>
    [...workflows.where((workflow) => workflow.stage == stage)]..sort(
      (a, b) => a.isDefault != b.isDefault
          ? (a.isDefault ? -1 : 1)
          : a.name.compareTo(b.name),
    );
```

Create `lib/features/workflows/domain/progress.dart`:

```dart
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

/// Where a person stands in their workflow, as the NEXT STEP card shows it.
sealed class WorkflowProgress {
  const WorkflowProgress();
}

final class Paused extends WorkflowProgress {
  const Paused(this.since);

  final DateTime since;
}

final class Done extends WorkflowProgress {
  const Done(this.workflow);

  final Workflow workflow;
}

final class OnStep extends WorkflowProgress {
  const OnStep({
    required this.workflow,
    required this.step,
    required this.index,
    required this.total,
    required this.due,
  });

  final Workflow workflow;
  final WorkflowStep step;

  /// 1-based, for "3 of 5".
  final int index;
  final int total;
  final DateTime due;
}

/// Found by position, not by step id, so edits apply at once: changed days
/// move the due date, a removed current step hands over to the next, a step
/// inserted before the current one is skipped.
///
/// Null when the person follows no workflow, or one missing from the list
/// (deleted elsewhere). Paused wins over everything.
WorkflowProgress? progressOf(Person person, Workflow? workflow) {
  if (person.pausedAt case final since?) return Paused(since);
  final place = person.place;
  if (place == null || workflow == null || workflow.id != place.workflowId) {
    return null;
  }
  final steps = workflow.steps;
  final index = steps.indexWhere((step) => step.position >= place.atPosition);
  if (index == -1) return Done(workflow);
  final step = steps[index];
  return OnStep(
    workflow: workflow,
    step: step,
    index: index + 1,
    total: steps.length,
    due: addDays(place.lastTick, step.days),
  );
}

/// Where ticking [current] leads: the next step, or one past the last (done).
num nextPosition(Workflow workflow, WorkflowStep current) {
  final steps = workflow.steps;
  final index = steps.indexWhere((step) => step.id == current.id);
  return index + 1 < steps.length
      ? steps[index + 1].position
      : current.position + 1;
}

/// Starts [workflow] with its first step due on [firstDue].
WorkflowPlace start(Workflow workflow, {required DateTime firstDue}) {
  final first = workflow.steps.firstOrNull;
  return (
    workflowId: workflow.id,
    atPosition: first?.position ?? 0,
    lastTick: addDays(firstDue, -(first?.days ?? 0)),
  );
}

/// The first step's day when nobody picks one.
DateTime firstDueDefault(Workflow workflow, DateTime today) =>
    addDays(today, workflow.steps.firstOrNull?.days ?? 0);

/// Calendar days, so a clock change never shifts a day.
DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
```

- [ ] **Step 4: Run the checks**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/workflows/domain test/features/workflows/domain
git commit -m "feat(workflows): progress, next position and start, with the edit rules (#57)"
```

---

### Task 4: `WorkflowRepository`, `workflowsProvider`, the fake and the harnesses

**Files:**
- Create: `lib/features/workflows/data/workflow_repository.dart`
- Create: `lib/features/workflows/presentation/workflows_controller.dart`
- Create: `test/features/workflows/fake_workflow_repository.dart`
- Modify: `test/app/app_harness.dart`, `test/features/contacts/presentation/form_harness.dart`
- Test: `test/features/workflows/data/workflow_repository_test.dart`, `test/features/workflows/presentation/workflows_controller_test.dart`

**Interfaces:**
- Consumes: `Workflow`, `WorkflowStep` (Task 3); `guardPeople`, `dayColumn` (Task 2); `peopleProvider`, `accountProvider`.
- Produces:
  - `WorkflowRepository`: `Future<List<Workflow>> list()`, `Future<void> seed(String lang, DateTime today)`; `workflowRepositoryProvider`; `Workflow workflowFromRow(Map<String, dynamic> row)`.
  - `workflowsProvider = AsyncNotifierProvider.family<WorkflowsController, List<Workflow>, String?>`, keyed on the account email; `[]` when signed out.
  - `String seedLanguage(String? accountLocale)`.
  - Test fake `FakeWorkflowRepository([Iterable<Workflow>])` with `store`, `calls` (`list()`, `seed(<lang>)`), `failWith`, `gate`, and `static List<Workflow> samples()`: ids `samples` (prospect, default, steps `samples-1`…`samples-5`, positions 1–5, EN labels and days of spec §2.1), `health` (prospect, 4), `new-customer` (customer, default, 4), `refill` (customer, 2), `getting-started` (team, default, 5).
  - Harness params `FakeWorkflowRepository? workflows` on `pumpFolo` and `pumpFormHarness`, defaulting to one preloaded with `samples()` (so no test seeds unless it asks to).

- [ ] **Step 1: Create the fake**

`test/features/workflows/fake_workflow_repository.dart`:

```dart
import 'dart:async';

import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/workflows/data/workflow_repository.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

/// In-memory workflows that record calls, and fail or stall on demand.
class FakeWorkflowRepository implements WorkflowRepository {
  FakeWorkflowRepository([Iterable<Workflow> workflows = const []]) {
    store.addAll(workflows);
  }

  final List<Workflow> store = [];

  /// One entry per call, e.g. `seed(en)`.
  final List<String> calls = <String>[];

  /// Thrown by calls started while set. Use a `PeopleFailure`.
  Object? failWith;

  /// Calls started while set wait on it.
  Completer<void>? gate;

  Future<void> _record(String call) async {
    calls.add(call);
    final failure = failWith;
    final wait = gate;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
  }

  @override
  Future<List<Workflow>> list() async {
    await _record('list()');
    return [...store];
  }

  /// Like the RPC: a no-op once there are workflows. It does not start
  /// people; tests that need a place set it on the person.
  @override
  Future<void> seed(String lang, DateTime today) async {
    await _record('seed($lang)');
    if (store.isEmpty) store.addAll(samples());
  }

  /// The English defaults of spec §2.1.
  static List<Workflow> samples() => [
    _workflow('samples', Stage.prospect, 'Samples', isDefault: true, [
      ('Send a first message', 0),
      ('Send the samples', 1),
      ('Samples arrived', 4),
      ('Ask how the samples went', 3),
      ('Follow up', 7),
    ]),
    _workflow('health', Stage.prospect, 'Health professionals', [
      ('Introduce yourself', 0),
      ('Share a product sheet', 2),
      ('Offer a sample kit', 5),
      ('Follow up', 7),
    ]),
    _workflow('new-customer', Stage.customer, 'New customer', isDefault: true, [
      ('Thank them for the order', 0),
      ('Order arrived', 5),
      ('Check in on the products', 14),
      ('Suggest a refill routine', 21),
    ]),
    _workflow('refill', Stage.customer, 'Refill check-in', [
      ('Ask how supplies are going', 25),
      ('Help with the next order', 3),
    ]),
    _workflow('getting-started', Stage.team, 'Getting started', isDefault: true, [
      ('Welcome call', 0),
      ('Unboxing call', 5),
      ('First training', 3),
      ('First goal together', 7),
      ('Two-week check-in', 14),
    ]),
  ];

  static Workflow _workflow(
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
          id: '$id-${index + 1}',
          position: index + 1,
          label: label,
          days: days,
        ),
    ],
  );
}
```

- [ ] **Step 2: Write the failing tests**

`test/features/workflows/data/workflow_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/workflows/data/workflow_repository.dart';

void main() {
  Map<String, dynamic> row({String stage = 'prospect'}) => {
    'id': 'w1',
    'stage': stage,
    'name': 'Samples',
    'is_default': true,
    'workflow_step': [
      {'id': 's2', 'position': 2.5, 'label': 'Send the samples', 'days': 1, 'note': null},
      {'id': 's1', 'position': 1, 'label': 'Send a first message', 'days': 0, 'note': 'Keep it short'},
    ],
  };

  test('reads a workflow with its steps, sorted, positions as numbers', () {
    final workflow = workflowFromRow(row());

    expect(workflow.stage, Stage.prospect);
    expect(workflow.isDefault, isTrue);
    expect([for (final s in workflow.steps) s.id], ['s1', 's2']);
    expect(workflow.steps.last.position, 2.5);
    expect(workflow.steps.first.note, 'Keep it short');
  });

  test('an unknown stage is an unknown failure', () {
    expect(() => workflowFromRow(row(stage: 'vip')),
        throwsA(PeopleFailure.unknown));
  });
}
```

`test/features/workflows/presentation/workflows_controller_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/account.dart';
import 'package:folo/features/contacts/data/activity_repository.dart';
import 'package:folo/features/contacts/data/people_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/workflows/data/workflow_repository.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';

import '../../auth/fake_auth_repository.dart';
import '../../contacts/fake_activity_repository.dart';
import '../../contacts/fake_people_repository.dart';
import '../fake_workflow_repository.dart';

typedef _World = ({
  ProviderContainer container,
  FakeWorkflowRepository workflows,
  FakePeopleRepository people,
});

_World _world(FakeWorkflowRepository workflows, {String? locale}) {
  final auth = FakeAuthRepository()
    ..session = true
    ..account = Account(
      firstName: 'Pauline',
      email: 'p@example.com',
      locale: locale,
    );
  addTearDown(auth.dispose);
  final people = FakePeopleRepository();
  final container = ProviderContainer.test(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      peopleRepositoryProvider.overrideWithValue(people),
      activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
      workflowRepositoryProvider.overrideWithValue(workflows),
    ],
  );
  return (container: container, workflows: workflows, people: people);
}

void main() {
  test('a seeded account lists and does not seed', () async {
    final world = _world(FakeWorkflowRepository(FakeWorkflowRepository.samples()));

    final list = await world.container.read(
      workflowsProvider('p@example.com').future,
    );

    expect(list, hasLength(5));
    expect(world.workflows.calls, ['list()']);
  });

  test('an empty account seeds once, lists again, reloads the book', () async {
    final world = _world(FakeWorkflowRepository(), locale: 'fr');
    final book = peopleProvider('p@example.com');
    world.container.listen(book, (_, _) {});
    await world.container.read(book.future);

    final list = await world.container.read(
      workflowsProvider('p@example.com').future,
    );
    await world.container.read(book.future);

    expect(list, hasLength(5));
    expect(world.workflows.calls, ['list()', 'seed(fr)', 'list()']);
    // The seed started people on a workflow: the book is fetched again.
    expect(world.people.calls, ['list()', 'list()']);
  });

  test('signed out is no workflows and no call', () async {
    final world = _world(FakeWorkflowRepository());

    expect(await world.container.read(workflowsProvider(null).future), isEmpty);
    expect(world.workflows.calls, isEmpty);
  });

  test('a failed seed is an error, and a retry seeds again', () async {
    final workflows = FakeWorkflowRepository()..failWith = PeopleFailure.network;
    final world = _world(workflows);
    final provider = workflowsProvider('p@example.com');
    world.container.listen(provider, (_, _) {});

    await expectLater(
      world.container.read(provider.future),
      throwsA(PeopleFailure.network),
    );
    workflows.failWith = null;
    world.container.invalidate(provider);

    expect(await world.container.read(provider.future), hasLength(5));
  });

  test('the seed language: French only for French', () {
    expect(seedLanguage('fr'), 'fr');
    expect(seedLanguage('en'), 'en');
    expect(seedLanguage('de'), 'en');
  });

  test('disposed while seeding: no throw', () async {
    final workflows = FakeWorkflowRepository()..gate = Completer<void>();
    final world = _world(workflows);
    final sub = world.container.listen(
      workflowsProvider('p@example.com'),
      (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);

    sub.close();
    world.container.dispose();
    workflows.gate!.complete();
    await Future<void>.delayed(Duration.zero);
  });
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/workflows`
Expected: FAIL — `workflow_repository.dart` / `workflows_controller.dart` missing.

- [ ] **Step 4: Implement**

`lib/features/workflows/data/workflow_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/core/supabase/supabase_provider.dart';
import 'package:folo/features/contacts/data/people_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `workflow` and `workflow_step` tables. Every method throws
/// [PeopleFailure] and nothing else. RLS scopes everything to the user.
class WorkflowRepository {
  WorkflowRepository(this._client);

  final SupabaseClient _client;

  Future<List<Workflow>> list() => guardPeople(() async {
    final rows = await _client.from('workflow').select('*, workflow_step(*)');
    return rows.map(workflowFromRow).toList();
  });

  /// The default workflows in [lang]; a no-op once the user has any. Also
  /// starts everyone without a workflow on their stage's default.
  Future<void> seed(String lang, DateTime today) => guardPeople(() async {
    await _client.rpc(
      'seed_workflows',
      params: {'p_lang': lang, 'p_today': dayColumn(today)},
    );
  });
}

final workflowRepositoryProvider = Provider<WorkflowRepository>(
  (ref) => WorkflowRepository(ref.watch(supabaseClientProvider)),
);

Workflow workflowFromRow(Map<String, dynamic> row) => Workflow(
  id: row['id'] as String,
  stage:
      Stage.values.asNameMap()[row['stage']] ?? (throw PeopleFailure.unknown),
  name: row['name'] as String,
  isDefault: row['is_default'] as bool,
  steps: [
    for (final step in (row['workflow_step'] as List).cast<Map<String, dynamic>>())
      WorkflowStep(
        id: step['id'] as String,
        position: step['position'] as num,
        label: step['label'] as String,
        days: step['days'] as int,
        note: step['note'] as String?,
      ),
  ],
);
```

`lib/features/workflows/presentation/workflows_controller.dart`:

```dart
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/workflows/data/workflow_repository.dart';
import 'package:folo/features/workflows/domain/workflow.dart';

/// One account's workflows, `workflowsProvider(account?.email)`. Keyed by
/// account for the same reason as `peopleProvider`. The first load of an
/// account with none seeds the defaults.
///
/// No automatic retry: a failed load shows its error with a Retry button.
final workflowsProvider =
    AsyncNotifierProvider.family<WorkflowsController, List<Workflow>, String?>(
      WorkflowsController.new,
      retry: (error, _) => null,
    );

class WorkflowsController extends AsyncNotifier<List<Workflow>> {
  WorkflowsController(this.owner);

  /// The email of the account; null when signed out.
  final String? owner;

  @override
  Future<List<Workflow>> build() async {
    final repository = ref.watch(workflowRepositoryProvider);
    if (owner == null) return const [];
    final workflows = await repository.list();
    if (workflows.isNotEmpty) return workflows;

    await repository.seed(
      seedLanguage(ref.read(accountProvider)?.locale),
      today(),
    );
    final seeded = await repository.list();
    // The seed started people on a workflow.
    if (ref.mounted) ref.invalidate(peopleProvider(owner));
    return seeded;
  }
}

/// The app's language when the account has none: French or English, the two
/// the defaults are written in. Workflows are never translated afterwards.
String seedLanguage(String? accountLocale) =>
    (accountLocale ?? PlatformDispatcher.instance.locale.languageCode) == 'fr'
    ? 'fr'
    : 'en';
```

If `Account` has no `locale` constructor parameter with that name, read `lib/features/auth/domain/account.dart` and use what is there (it has `final String? locale;`).

- [ ] **Step 5: Override the repository in every harness**

In `test/app/app_harness.dart` and `test/features/contacts/presentation/form_harness.dart`: add the parameter `FakeWorkflowRepository? workflows,` and the override

```dart
        workflowRepositoryProvider.overrideWithValue(
          workflows ?? FakeWorkflowRepository(FakeWorkflowRepository.samples()),
        ),
```

with imports `package:folo/features/workflows/data/workflow_repository.dart` and the fake (`'../features/workflows/fake_workflow_repository.dart'` from `test/app/`, `'../../workflows/fake_workflow_repository.dart'` from `test/features/contacts/presentation/`). `people_controller_test.dart` needs no override: `PeopleController` never reads the workflows.

- [ ] **Step 6: Run the checks**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/workflows test/features/workflows test/app test/features/contacts
git commit -m "feat(workflows): list and seed each account's workflows (#57)"
```

---

### Task 5: `PeopleController` moves people through workflows; the `step` kind

**Files:**
- Modify: `lib/features/contacts/presentation/people_controller.dart`
- Modify: `lib/features/contacts/domain/activity.dart`
- Modify: `lib/features/contacts/data/activity_repository.dart:67`
- Modify: `lib/features/contacts/presentation/people_copy.dart` (`kindLabel`)
- Modify: `lib/features/contacts/presentation/log_activity_sheet.dart`
- Modify: `lib/features/contacts/presentation/add_person_sheet.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/contacts/presentation/people_controller_test.dart`, `test/features/contacts/presentation/log_activity_sheet_test.dart`, `test/features/contacts/presentation/add_person_sheet_test.dart`

**Interfaces:**
- Consumes: the `PeopleRepository` writes and `WorkflowPlace` (Task 2); `Workflow`, `FollowWith`, `defaultFor`, `OnStep`, `nextPosition`, `start`, `firstDueDefault` (Task 3); `workflowsProvider` (Task 4); `today()` (Task 2).
- Produces, on `PeopleController`:
  - `Future<Person> add(PersonDraft draft, {Workflow? workflow, required DateTime today})` — started on [workflow] with `firstDueDefault`; null: no workflow.
  - `Future<void> moveTo(Person person, Stage stage, {FollowWith? follow})` — null `follow` is "Nothing for now".
  - `Future<void> setWorkflow(Person person, FollowWith? follow)`.
  - `Future<void> completeStep(Person person, OnStep progress, DateTime today)` — invalidates `historyProvider(person.id)`.
  - `Future<void> pause(Person person)`, `Future<void> resume(Person person, DateTime today)`.
  - Every one waits for the server, replaces the person, and on failure rethrows with `state` untouched.
- Produces: `ActivityKind.step`; `bool ActivityKind.byUser` (false for `stage` and `step`); l10n key `activityKindStep` "Step".

- [ ] **Step 1: Write the failing controller tests**

Append to `main()` in `people_controller_test.dart`, with the imports `package:folo/features/workflows/domain/progress.dart`, `package:folo/features/workflows/domain/workflow.dart` and `'../../workflows/fake_workflow_repository.dart'`:

```dart
  final samples = FakeWorkflowRepository.samples().first;
  final customer = FakeWorkflowRepository.samples()[2];
  final day = DateTime(2026, 9, 28);
  WorkflowPlace at(num position, {String workflowId = 'samples'}) =>
      (workflowId: workflowId, atPosition: position, lastTick: day);
  Person onSamples(num position, {DateTime? pausedAt}) => Person(
    id: 'p1',
    name: 'Marie',
    stage: Stage.prospect,
    stageSince: DateTime.utc(2026, 3, 4),
    place: at(position),
    pausedAt: pausedAt,
  );

  test('add starts the given workflow, due its first step today', () async {
    final world = _world([]);
    final book = _book(world.container);
    await world.container.read(book.future);

    final added = await world.container.read(book.notifier).add((
      name: 'Bruno',
      stage: Stage.prospect,
      phone: null,
      email: null,
      instagram: null,
    ), workflow: samples, today: day);

    expect(added.place, at(1));
  });

  test('add with no workflow starts none', () async {
    final world = _world([]);
    final book = _book(world.container);
    await world.container.read(book.future);

    final added = await world.container.read(book.notifier).add((
      name: 'Bruno',
      stage: Stage.prospect,
      phone: null,
      email: null,
      instagram: null,
    ), today: day);

    expect(added.place, isNull);
  });

  test('moveTo writes the stage and what follows in one call', () async {
    final world = _world([onSamples(3)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;

    await world.container.read(book.notifier).moveTo(
      marie,
      Stage.customer,
      follow: (workflow: customer, firstDue: DateTime(2026, 10, 1)),
    );

    final moved = world.container.read(book).value!.single;
    expect(moved.stage, Stage.customer);
    expect(moved.place, (
      workflowId: 'new-customer',
      atPosition: 1,
      lastTick: DateTime(2026, 10, 1),
    ));
    expect(world.people.calls.last, 'setStage(p1, customer)');
  });

  test('moveTo with nothing to follow ends the workflow', () async {
    final world = _world([onSamples(3)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;

    await world.container.read(book.notifier).moveTo(marie, Stage.team);

    expect(world.container.read(book).value!.single.place, isNull);
  });

  test('setWorkflow changes the workflow and ends a pause', () async {
    final world = _world([onSamples(3, pausedAt: DateTime.utc(2026, 7, 12))]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;
    final health = FakeWorkflowRepository.samples()[1];

    await world.container.read(book.notifier).setWorkflow(
      marie,
      (workflow: health, firstDue: day),
    );

    final changed = world.container.read(book).value!.single;
    expect(changed.place?.workflowId, 'health');
    expect(changed.pausedAt, isNull);
  });

  test('setWorkflow to nothing clears the place', () async {
    final world = _world([onSamples(3)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;

    await world.container.read(book.notifier).setWorkflow(marie, null);

    expect(world.container.read(book).value!.single.place, isNull);
    expect(world.people.calls.last, 'setPlace(p1, none)');
  });

  test('completeStep moves to the next step and reloads the history', () async {
    final world = _world([onSamples(2)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    world.container.listen(historyProvider('p1'), (_, _) {});
    await world.container.read(historyProvider('p1').future);
    final marie = world.container.read(book).value!.single;
    final progress = progressOf(marie, samples)! as OnStep;

    await world.container.read(book.notifier).completeStep(
      marie,
      progress,
      DateTime(2026, 9, 30),
    );

    final moved = world.container.read(book).value!.single;
    expect(moved.place, (
      workflowId: 'samples',
      atPosition: 3,
      lastTick: DateTime(2026, 9, 30),
    ));
    expect(world.people.calls.last, 'completeStep(p1, samples-2)');
    await world.container.read(historyProvider('p1').future);
    expect(world.activities.calls, ['list(p1)', 'list(p1)']);
  });

  test('pause marks a prospect Not now; resume counts from today', () async {
    final world = _world([onSamples(2)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final notifier = world.container.read(book.notifier);

    await notifier.pause(world.container.read(book).value!.single);
    final paused = world.container.read(book).value!.single;
    expect(paused.pausedAt, isNotNull);
    expect(paused.prospectStatus, ProspectStatus.notNow);

    await notifier.resume(paused, DateTime(2026, 10, 5));
    final resumed = world.container.read(book).value!.single;
    expect(resumed.pausedAt, isNull);
    expect(resumed.place?.atPosition, 2);
    expect(resumed.place?.lastTick, DateTime(2026, 10, 5));
  });

  test('pause leaves a customer with no status', () async {
    final world = _world([
      Person(
        id: 'c1',
        name: 'Claire',
        stage: Stage.customer,
        stageSince: DateTime.utc(2026, 3, 4),
        place: at(1, workflowId: 'new-customer'),
      ),
    ]);
    final book = _book(world.container);
    await world.container.read(book.future);

    await world.container
        .read(book.notifier)
        .pause(world.container.read(book).value!.single);

    final paused = world.container.read(book).value!.single;
    expect(paused.pausedAt, isNotNull);
    expect(paused.prospectStatus, isNull);
  });

  test('a failed write rethrows and changes nothing', () async {
    final world = _world([onSamples(2)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final notifier = world.container.read(book.notifier);
    final marie = world.container.read(book).value!.single;
    final progress = progressOf(marie, samples)! as OnStep;
    world.people.failWith = PeopleFailure.network;

    for (final write in <Future<void> Function()>[
      () => notifier.completeStep(marie, progress, day),
      () => notifier.pause(marie),
      () => notifier.resume(marie, day),
      () => notifier.setWorkflow(marie, null),
      () => notifier.moveTo(marie, Stage.customer),
      () => notifier.add((
        name: 'Bruno',
        stage: Stage.prospect,
        phone: null,
        email: null,
        instagram: null,
      ), workflow: samples, today: day),
    ]) {
      await expectLater(write(), throwsA(PeopleFailure.network));
    }
    // Person has no ==: the very same instance is still there.
    expect(world.container.read(book).value!.single, same(marie));
  });

  test('the book rebuilt while a step completes: no throw', () async {
    final world = _world([onSamples(2)]);
    final book = _book(world.container);
    world.container.listen(book, (_, _) {});
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;
    final progress = progressOf(marie, samples)! as OnStep;
    world.people.gate = Completer<void>();

    final ticking = world.container
        .read(book.notifier)
        .completeStep(marie, progress, day);
    world.container.invalidate(book);
    world.people.gate!.complete();

    await ticking;
    final reloaded = await world.container.read(book.future);
    expect(reloaded.single.id, 'p1');
  });
```

In the existing `add keeps the list sorted` test, add `today: DateTime(2026, 9, 28)` after the draft record.

- [ ] **Step 2: Write the failing Log sheet test**

Append to `main()` in `log_activity_sheet_test.dart` (its `open(tester)` helper pumps the sheet for Claire):

```dart
  testWidgets('Step is never offered: the app writes those', (tester) async {
    await open(tester);

    expect(find.widgetWithText(ChoiceChip, 'Step'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Note'), findsOneWidget);
  });
```

- [ ] **Step 3: Write the failing Add sheet test**

Append to `main()` in `add_person_sheet_test.dart` (it has `open(tester)`, `field(label)` and a `people` fake; the harness preloads the sample workflows):

```dart
  testWidgets('someone new starts their stage\'s default workflow', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field('Name'), 'Bruno Petit');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(people.store.values.single.place?.workflowId, 'samples');
  });
```

- [ ] **Step 4: Run them to verify they fail**

Run: `flutter test test/features/contacts/presentation/people_controller_test.dart test/features/contacts/presentation/log_activity_sheet_test.dart test/features/contacts/presentation/add_person_sheet_test.dart`
Expected: compile errors — `today:` / `follow:` / `completeStep` undefined.

- [ ] **Step 5: The `step` kind**

`lib/features/contacts/domain/activity.dart`:

```dart
/// What an entry records. [stage] entries are written by the database when a
/// person changes stage, [step] entries when a workflow step is ticked; the
/// user writes the others.
enum ActivityKind {
  note,
  call,
  message,
  order,
  meeting,
  stage,
  step;

  /// Offered in Log something.
  bool get byUser => this != stage && this != step;
}
```

The `Activity` assert stays as is: a step entry has text (the step's label) and no stage.

`activity_repository.dart:67`: the assert becomes `draft.kind.byUser,`.

`people_copy.dart` `kindLabel`: add `ActivityKind.step => l10n.activityKindStep,`.

`log_activity_sheet.dart`: the chip loop becomes

```dart
                for (final kind in ActivityKind.values)
                  if (kind.byUser)
                    ChoiceChip(
                      label: Text(kindLabel(l10n, kind)!),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
```

and the private `_today()` is deleted in favour of `today()` from `pick_day.dart` (three call sites; the local `final today = _today();` becomes `final now = today();` and its two uses follow).

`app_en.arb`, after `@activityKindMeeting`:

```json
  "activityKindStep": "Step",
  "@activityKindStep": {
    "description": "Kind of history entry: a workflow step the user marked done. The entry's title is the step's name."
  },
```

Run `flutter gen-l10n` if the build does not regenerate on its own (`flutter test` does).

- [ ] **Step 6: The controller**

In `people_controller.dart`, replace `add` and `moveTo`, and add the rest after `moveTo`; imports `package:folo/features/workflows/domain/progress.dart` and `package:folo/features/workflows/domain/workflow.dart`:

```dart
  /// Starts [workflow], its first step due counted from [today]. No workflow
  /// (none seeded yet): starts none.
  Future<Person> add(
    PersonDraft draft, {
    Workflow? workflow,
    required DateTime today,
  }) async {
    final person = await _repository.add(
      draft,
      place: workflow == null
          ? null
          : start(workflow, firstDue: firstDueDefault(workflow, today)),
    );
    _change((people) => [...people, person]);
    return person;
  }

  /// Waits for the server, which decides [Person.stageSince] and the status,
  /// and writes the history entry that is then reloaded. [follow] travels in
  /// the same update; null is "Nothing for now". A failure rethrows and
  /// changes nothing.
  Future<void> moveTo(Person person, Stage stage, {FollowWith? follow}) async {
    _replace(
      await _repository.setStage(person.id, stage, place: _placeFor(follow)),
    );
    if (ref.mounted) ref.invalidate(historyProvider(person.id));
  }

  /// Change workflow; null is "Nothing for now".
  Future<void> setWorkflow(Person person, FollowWith? follow) async {
    _replace(await _repository.setPlace(person.id, _placeFor(follow)));
  }

  /// Ticks [progress]'s step on [today]: a history entry, and the next step.
  Future<void> completeStep(
    Person person,
    OnStep progress,
    DateTime today,
  ) async {
    _replace(
      await _repository.completeStep(
        person.id,
        progress.step.id,
        nextPosition(progress.workflow, progress.step),
        today,
      ),
    );
    if (ref.mounted) ref.invalidate(historyProvider(person.id));
  }

  /// Hides the next step; a prospect also becomes Not now.
  Future<void> pause(Person person) async {
    _replace(
      await _repository.pause(
        person.id,
        DateTime.now(),
        notNow: person.stage == Stage.prospect,
      ),
    );
  }

  /// The same step comes back, due counted from [today].
  Future<void> resume(Person person, DateTime today) async {
    _replace(await _repository.resume(person.id, today));
  }

  static WorkflowPlace? _placeFor(FollowWith? follow) => follow == null
      ? null
      : start(follow.workflow, firstDue: follow.firstDue);
```

`_replace` already returns early once unmounted, which is what keeps the rebuilt-book test from throwing.

- [ ] **Step 7: The Add sheet passes the default**

In `add_person_sheet.dart` `_submit`, with imports `package:folo/core/ui/pick_day.dart`, `package:folo/features/workflows/domain/workflow.dart` and `package:folo/features/workflows/presentation/workflows_controller.dart`:

```dart
      final owner = ref.read(accountProvider)?.email;
      final people = peopleProvider(owner);
      final workflows = ref.read(workflowsProvider(owner)).value ?? const [];
      final person = await ref.read(people.notifier).add((
        name: _name.text.trim(),
        stage: _stage,
        phone: value(ChannelKind.phone),
        email: value(ChannelKind.email),
        instagram: value(ChannelKind.instagram),
      ), workflow: defaultFor(workflows, _stage), today: today());
```

and at the top of `build`:

```dart
    // Loads the workflows, so the default is there by the time Add is tapped.
    ref.watch(workflowsProvider(ref.watch(accountProvider)?.email));
```

- [ ] **Step 8: Run the checks**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all pass. `people_copy_test`'s "every kind but stage has a label" still holds.

- [ ] **Step 9: Commit**

```bash
git add lib test
git commit -m "feat(contacts): tick, pause, resume and change a person's workflow (#57)"
```

---

### Task 6: The words — strings, the due line and the paused subtitle

**Files:**
- Modify: `lib/l10n/app_en.arb` (append before the closing `}`; never touch `app_fr.arb`)
- Modify: `lib/features/contacts/presentation/people_copy.dart`
- Modify: `lib/features/contacts/presentation/contact_list.dart:143`
- Test: `test/features/contacts/presentation/people_copy_test.dart`, `test/features/contacts/presentation/contact_list_test.dart`

**Interfaces:**
- Consumes: `daysBetween` (Task 3); `Person.pausedAt` (Task 2).
- Produces:
  - `String dueLabel(AppLocalizations l10n, DateTime due, DateTime today)`.
  - `String? contactSubtitle(AppLocalizations l10n, Person person)` (was `contactSubtitle(Person)`).
  - The l10n getters and methods listed in Step 3; Tasks 7 and 8 use these exact names.

- [ ] **Step 1: Write the failing copy tests**

Append to `main()` in `people_copy_test.dart`:

```dart
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
```

- [ ] **Step 2: Write the failing list test**

Append to `main()` in `contact_list_test.dart` (its `_pump(tester, people: …)` pumps a bare `ContactList`):

```dart
  testWidgets('a paused prospect reads Not now · paused in July', (
    tester,
  ) async {
    await _pump(tester, people: [
      Person(
        id: 'p1',
        name: 'Sarah Martin',
        stage: Stage.prospect,
        prospectStatus: ProspectStatus.notNow,
        stageSince: DateTime.utc(2026, 3, 4),
        pausedAt: DateTime(2026, 7, 12),
      ),
    ]);

    expect(find.text('Not now · paused in July'), findsOneWidget);
  });
```

- [ ] **Step 3: Add the strings**

Append to `app_en.arb`, before the final `}` (add a comma after the last existing entry):

```json
  "nextStepTitle": "Next step",
  "@nextStepTitle": {
    "description": "Header of the card on a contact that shows the next thing to do with them in their workflow. Shown uppercased."
  },
  "nextStepProgress": "{workflow} · {index} of {total}",
  "@nextStepProgress": {
    "description": "Trailing text of the Next step header: the workflow's name and which step this is, e.g. 'Samples · 3 of 5'.",
    "placeholders": {
      "workflow": { "type": "String" },
      "index": { "type": "int" },
      "total": { "type": "int" }
    }
  },
  "nextStepDueToday": "Due today",
  "@nextStepDueToday": {
    "description": "When the next step is due: today."
  },
  "nextStepDueTomorrow": "Due tomorrow",
  "@nextStepDueTomorrow": {
    "description": "When the next step is due: tomorrow."
  },
  "nextStepDueInDays": "Due in {days} days",
  "@nextStepDueInDays": {
    "description": "When the next step is due, 2 to 6 days from now.",
    "placeholders": {
      "days": { "type": "int" }
    }
  },
  "nextStepDueOn": "Due {day}",
  "@nextStepDueOn": {
    "description": "When the next step is due, a week or more from now, e.g. 'Due October 2'.",
    "placeholders": {
      "day": { "type": "DateTime", "format": "MMMMd" }
    }
  },
  "nextStepLate": "{days, plural, =1{1 day late} other{{days} days late}}",
  "@nextStepLate": {
    "description": "The next step's due day has passed, by this many days.",
    "placeholders": {
      "days": { "type": "int" }
    }
  },
  "nextStepWithNote": "{due} — {note}",
  "@nextStepWithNote": {
    "description": "Second line of the next step: when it is due, then the note the user wrote on the step.",
    "placeholders": {
      "due": { "type": "String" },
      "note": { "type": "String" }
    }
  },
  "nextStepMarkDone": "Mark “{step}” done",
  "@nextStepMarkDone": {
    "description": "Screen-reader label of the round button that marks the next step as done.",
    "placeholders": {
      "step": { "type": "String" }
    }
  },
  "nextStepDoneTitle": "{workflow} — done",
  "@nextStepDoneTitle": {
    "description": "Header of the card once every step of the workflow is done. Shown uppercased.",
    "placeholders": {
      "workflow": { "type": "String" }
    }
  },
  "nextStepHowDidItEnd": "How did it end with {name}?",
  "@nextStepHowDidItEnd": {
    "description": "Title of the card once a prospect's workflow is done: asks what came of it. The name is the person's first name.",
    "placeholders": {
      "name": { "type": "String" }
    }
  },
  "nextStepAllDoneProspect": "{count, plural, =1{The step is done. Their notes and history stay whatever you pick.} other{All {count} steps are done. Their notes and history stay whatever you pick.}}",
  "@nextStepAllDoneProspect": {
    "description": "Body of the card once a prospect's workflow is done, above 'Became a customer' and 'Not now'. 'Their' is the person; never a gendered pronoun.",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "nextStepBecameCustomer": "Became a customer",
  "@nextStepBecameCustomer": {
    "description": "Button on the done card of a prospect: opens the move to customers."
  },
  "nextStepAllDoneWith": "{count, plural, =1{The step is done with {name}.} other{All {count} steps are done with {name}.}}",
  "@nextStepAllDoneWith": {
    "description": "Body of the card once a customer's or team member's workflow is done. The name is the person's first name.",
    "placeholders": {
      "count": { "type": "int" },
      "name": { "type": "String" }
    }
  },
  "nextStepFollowWith": "Follow with…",
  "@nextStepFollowWith": {
    "description": "Button that opens the choice of the workflow to follow next."
  },
  "nextStepPausedSince": "Paused since {day}",
  "@nextStepPausedSince": {
    "description": "Card on a paused contact: the day it was paused, e.g. 'Paused since July 12'. Above a Resume button.",
    "placeholders": {
      "day": { "type": "DateTime", "format": "MMMMd" }
    }
  },
  "nextStepNothingPlanned": "Nothing planned",
  "@nextStepNothingPlanned": {
    "description": "Card on a contact who follows no workflow."
  },
  "nextStepLoadFailed": "Couldn't load the workflows",
  "@nextStepLoadFailed": {
    "description": "Error inside the Next step card when the workflows failed to load; a Try again button follows."
  },
  "followWithTitle": "Follow with",
  "@followWithTitle": {
    "description": "Label above the choice of the workflow to follow, in Change stage and Change workflow."
  },
  "followWithSteps": "{count, plural, =1{1 step} other{{count} steps}}",
  "@followWithSteps": {
    "description": "How many steps a workflow has, under its name in the choice.",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "followWithSuggestedSteps": "Suggested · {steps}",
  "@followWithSuggestedSteps": {
    "description": "Under the stage's default workflow in the choice: 'Suggested · 4 steps'. {steps} is the step count text.",
    "placeholders": {
      "steps": { "type": "String" }
    }
  },
  "followWithNothing": "Nothing for now",
  "@followWithNothing": {
    "description": "Last option of the choice: follow no workflow."
  },
  "changeStageWorkflowEnds": "The {workflow} workflow ends here.",
  "@changeStageWorkflowEnds": {
    "description": "Added to the Change stage body when the person was following a workflow.",
    "placeholders": {
      "workflow": { "type": "String" }
    }
  },
  "changeWorkflowTitle": "Change {name}'s workflow",
  "@changeWorkflowTitle": {
    "description": "Title of the sheet that picks another workflow for a person. The name is their first name.",
    "placeholders": {
      "name": { "type": "String" }
    }
  },
  "contactChangeWorkflow": "Change workflow",
  "@contactChangeWorkflow": {
    "description": "Row in a contact's More menu; the current workflow's name follows it."
  },
  "contactPause": "Pause — not now",
  "@contactPause": {
    "description": "Row in a contact's More menu: hides their next step until resumed."
  },
  "contactResume": "Resume",
  "@contactResume": {
    "description": "Row in a paused contact's More menu, and button on their Paused card: brings the next step back."
  },
  "contactPaused": "Paused in {month}",
  "@contactPaused": {
    "description": "Second line of a paused person in the contacts list, e.g. 'Paused in July'.",
    "placeholders": {
      "month": { "type": "DateTime", "format": "MMMM" }
    }
  },
  "contactPausedNotNow": "Not now · paused in {month}",
  "@contactPausedNotNow": {
    "description": "Second line of a paused prospect whose status is Not now, e.g. 'Not now · paused in July'.",
    "placeholders": {
      "month": { "type": "DateTime", "format": "MMMM" }
    }
  }
```

`MMMM` alone is the standalone month; if gen-l10n rejects it as a named format, use `"format": "LLLL"` with `"isCustomDateFormat": "true"`.

- [ ] **Step 4: The copy helpers**

In `people_copy.dart`, replace `contactSubtitle` and add `dueLabel`; import `package:folo/features/workflows/domain/progress.dart`:

```dart
/// The second line of a person's row: paused, else what they do, else what
/// they need.
String? contactSubtitle(AppLocalizations l10n, Person person) =>
    switch (person.pausedAt?.toLocal()) {
      final since? when person.prospectStatus == ProspectStatus.notNow =>
        l10n.contactPausedNotNow(since),
      final since? => l10n.contactPaused(since),
      null => person.profession ?? person.needs,
    };

/// When a step is due, counted in calendar days from [today].
String dueLabel(AppLocalizations l10n, DateTime due, DateTime today) =>
    switch (daysBetween(today, due)) {
      < 0 && final late => l10n.nextStepLate(-late),
      0 => l10n.nextStepDueToday,
      1 => l10n.nextStepDueTomorrow,
      <= 6 && final days => l10n.nextStepDueInDays(days),
      _ => l10n.nextStepDueOn(due),
    };
```

`contact_list.dart:143`: `subtitle: contactSubtitle(l10n, person),` (`l10n` is already in scope).

- [ ] **Step 5: Run the checks**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all pass.

- [ ] **Step 6: Commit**

```bash
git add lib test
git commit -m "feat(workflows): the words for next steps, pauses and follow-ups (#57)"
```

---

### Task 7: FOLLOW WITH — the block, Change stage and Change workflow

**Files:**
- Modify: `lib/core/ui/pick_day.dart`
- Create: `lib/features/contacts/presentation/follow_with_field.dart`
- Modify: `lib/features/contacts/presentation/change_stage_sheet.dart`
- Create: `lib/features/contacts/presentation/change_workflow_sheet.dart`
- Test: `test/features/contacts/presentation/follow_with_field_test.dart`, `test/features/contacts/presentation/change_stage_sheet_test.dart`, `test/features/contacts/presentation/change_workflow_sheet_test.dart`

**Interfaces:**
- Consumes: `Workflow`, `FollowWith`, `forStage`, `findWorkflow`, `defaultFor`, `firstDueDefault`, `addDays` (Task 3); `workflowsProvider` (Task 4); `PeopleController.moveTo(…, follow:)`, `setWorkflow` (Task 5); strings `followWith*`, `changeStageWorkflowEnds`, `changeWorkflowTitle` (Task 6); `dayLabel`, `firstName`, `peopleFailureCopy`, `logWhenToday` (existing).
- Produces:
  - `pickDay(context, {required DateTime initial, DateTime? first, required DateTime last})`.
  - `class FollowWithField({required List<Workflow> workflows, required FollowWith? value, required DateTime today, required ValueChanged<FollowWith?> onChanged})` — controlled; [workflows] already narrowed to one stage.
  - `Future<void> showChangeWorkflow(BuildContext context, Person person)`.

- [ ] **Step 1: Write the failing block tests**

`test/features/contacts/presentation/follow_with_field_test.dart`:

```dart
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
    await pump(
      tester,
      initial: (workflow: samples, firstDue: today()),
    );

    expect(find.text('Suggested · 5 steps'), findsOneWidget);
    expect(find.text('4 steps'), findsOneWidget);
    expect(find.text('Nothing for now'), findsOneWidget);
    expect(
      tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'samples',
    );
    // The date field is labelled with the first step.
    expect(find.text('Send a first message'), findsOneWidget);
  });

  testWidgets('another workflow starts due its own first step', (
    tester,
  ) async {
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
```

- [ ] **Step 2: Write the failing sheet tests**

Append to `main()` in `change_stage_sheet_test.dart` (its `open(tester, person, stage)` builds a fresh `people` fake; the harness preloads the sample workflows):

```dart
  testWidgets('follows with the new stage\'s default', (tester) async {
    await open(tester, _sarah(), Stage.customer);

    expect(find.text('Suggested · 4 steps'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Move to customers'));
    await tester.pumpAndSettle();

    expect(people.store['p1']!.place?.workflowId, 'new-customer');
  });

  testWidgets('Nothing for now moves with no workflow', (tester) async {
    await open(tester, _sarah(), Stage.team);

    await tester.tap(find.text('Nothing for now'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Move to team'));
    await tester.pumpAndSettle();

    expect(people.store['p1']!.stage, Stage.team);
    expect(people.store['p1']!.place, isNull);
  });

  testWidgets('says the current workflow ends', (tester) async {
    await open(
      tester,
      Person(
        id: 'p1',
        name: 'Sarah Martin',
        stage: Stage.prospect,
        stageSince: DateTime.utc(2026, 3, 4),
        place: (
          workflowId: 'samples',
          atPosition: 2,
          lastTick: DateTime(2026, 9, 28),
        ),
      ),
      Stage.customer,
    );

    expect(
      find.text(
        'Everything you noted stays with them. The Samples workflow ends here.',
      ),
      findsOneWidget,
    );
  });
```

`test/features/contacts/presentation/change_workflow_sheet_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/change_workflow_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_people_repository.dart';
import 'form_harness.dart';

Person _sarah({WorkflowPlace? place}) => Person(
  id: 'p1',
  name: 'Sarah Martin',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 3, 4),
  place: place,
);

void main() {
  late FakePeopleRepository people;

  Future<void> open(WidgetTester tester, Person person) {
    people = FakePeopleRepository([person]);
    return pumpFormHarness(
      tester,
      people: people,
      open: (context) => showChangeWorkflow(context, person),
      result: (_) {},
    );
  }

  testWidgets('the current workflow is selected; Save changes it', (
    tester,
  ) async {
    await open(
      tester,
      _sarah(
        place: (
          workflowId: 'health',
          atPosition: 2,
          lastTick: DateTime(2026, 9, 28),
        ),
      ),
    );

    expect(find.text("Change Sarah's workflow"), findsOneWidget);
    expect(
      tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'health',
    );
    await tester.tap(find.text('Samples'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('setPlace(p1, samples)'));
    expect(find.text("Change Sarah's workflow"), findsNothing);
  });

  testWidgets('no workflow: the default is selected', (tester) async {
    await open(tester, _sarah());

    expect(
      tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'samples',
    );
  });

  testWidgets('a failure stays open and says why', (tester) async {
    await open(tester, _sarah());
    people.failWith = PeopleFailure.network;

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(FormError), findsOneWidget);
    expect(find.text("Change Sarah's workflow"), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/contacts/presentation/follow_with_field_test.dart test/features/contacts/presentation/change_stage_sheet_test.dart test/features/contacts/presentation/change_workflow_sheet_test.dart`
Expected: compile errors — `follow_with_field.dart` / `change_workflow_sheet.dart` missing.

- [ ] **Step 4: `pickDay` gets a first day**

In `pick_day.dart`: add `DateTime? first` to `pickDay` (named, after `initial`) and to `_Wheel`; `showDatePicker` gets `firstDate: first ?? DateTime(1900)`, `CupertinoDatePicker` gets `minimumDate: widget.first`. The doc comment becomes "A calendar day between [first] and [last], as local midnight; …".

- [ ] **Step 5: The block**

`lib/features/contacts/presentation/follow_with_field.dart`:

```dart
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/core/ui/section_header.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// What follows: one of a stage's workflows and its first step's day, or
/// nothing. Controlled — the sheet holds [value].
class FollowWithField extends StatelessWidget {
  const FollowWithField({
    required this.workflows,
    required this.value,
    required this.today,
    required this.onChanged,
    super.key,
  });

  /// One stage's, default first (`forStage`).
  final List<Workflow> workflows;

  /// Null is "Nothing for now".
  final FollowWith? value;
  final DateTime today;
  final ValueChanged<FollowWith?> onChanged;

  // The radio value of "Nothing for now"; ids are uuids, never empty.
  static const _nothing = '';

  Future<void> _pickDay(BuildContext context, FollowWith follow) async {
    final day = await pickDay(
      context,
      initial: follow.firstDue,
      first: today,
      // ponytail: two years out is far enough for a first step; widen if asked.
      last: addDays(today, 730),
    );
    if (day != null) onChanged((workflow: follow.workflow, firstDue: day));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final follow = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.followWithTitle),
        RadioGroup<String>(
          groupValue: follow?.workflow.id ?? _nothing,
          onChanged: (id) => onChanged(switch (findWorkflow(workflows, id)) {
            final workflow? => (
              workflow: workflow,
              firstDue: firstDueDefault(workflow, today),
            ),
            null => null,
          }),
          child: Column(
            children: [
              for (final workflow in workflows)
                RadioListTile<String>(
                  value: workflow.id,
                  contentPadding: EdgeInsets.zero,
                  title: Text(workflow.name),
                  subtitle: Text(
                    workflow.isDefault
                        ? l10n.followWithSuggestedSteps(
                            l10n.followWithSteps(workflow.steps.length),
                          )
                        : l10n.followWithSteps(workflow.steps.length),
                  ),
                ),
              RadioListTile<String>(
                value: _nothing,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.followWithNothing),
              ),
            ],
          ),
        ),
        if (follow != null) ...[
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: () => _pickDay(context, follow),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText:
                    follow.workflow.steps.firstOrNull?.label ??
                    follow.workflow.name,
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              child: Text(
                follow.firstDue == today
                    ? l10n.logWhenToday(today)
                    : dayLabel(l10n, follow.firstDue, today),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
```

If `RadioGroup` is not exported by `package:material_ui/material_ui.dart`, it comes from `package:flutter/widgets.dart` (it is a widgets-layer class); `RadioListTile` without `groupValue` needs Flutter ≥ 3.35, which the project uses.

- [ ] **Step 6: Change stage**

In `change_stage_sheet.dart`, imports `package:folo/core/ui/pick_day.dart`, `package:folo/features/contacts/presentation/follow_with_field.dart`, `package:folo/features/workflows/domain/progress.dart`, `package:folo/features/workflows/domain/workflow.dart`, `package:folo/features/workflows/presentation/workflows_controller.dart`, `package:folo/app/theme/app_spacing.dart`. In the state:

```dart
  /// What the user picked; null until they pick, so the default can arrive
  /// with the workflows. The record tells "picked nothing" from "not yet".
  ({FollowWith? follow})? _picked;

  FollowWith? _follow(List<Workflow> workflows, DateTime today) {
    if (_picked case (:final follow)) return follow;
    final suggested = defaultFor(workflows, widget.stage);
    return suggested == null
        ? null
        : (workflow: suggested, firstDue: firstDueDefault(suggested, today));
  }
```

`_move` takes the value: `Future<void> _move(FollowWith? follow)` and calls `.moveTo(widget.person, widget.stage, follow: follow)`. In `build`:

```dart
    final owner = ref.watch(accountProvider)?.email;
    final workflows = ref.watch(workflowsProvider(owner)).value ?? const [];
    final now = today();
    final follow = _follow(workflows, now);
    final ending = findWorkflow(workflows, widget.person.place?.workflowId);
    final body = clearsStatus ? l10n.changeStageBodyCleared : l10n.changeStageBody;
```

`FoloDialog` gets `body: ending == null ? body : '$body ${l10n.changeStageWorkflowEnds(ending.name)}'`, the Move button `onPressed: _saving ? null : () => _move(follow)`, and

```dart
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.ms,
        children: [
          if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
          FollowWithField(
            workflows: forStage(workflows, widget.stage),
            value: follow,
            today: now,
            onChanged: (next) => setState(() => _picked = (follow: next)),
          ),
        ],
      ),
```

Workflows still loading or failed: the block offers only "Nothing for now"; moving then starts none. The card offers "Follow with…" afterwards.

- [ ] **Step 7: Change workflow**

`lib/features/contacts/presentation/change_workflow_sheet.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/folo_dialog.dart';
import 'package:folo/core/ui/form_error.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/people_failure.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/follow_with_field.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Picks what [person] follows next: a sheet on mobile, a dialog elsewhere.
/// Saving starts the picked workflow from its first step, even the current
/// one. Closes once saved.
Future<void> showChangeWorkflow(BuildContext context, Person person) =>
    FoloDialog.show<void>(context, (_) => _ChangeWorkflow(person));

class _ChangeWorkflow extends ConsumerStatefulWidget {
  const _ChangeWorkflow(this.person);

  final Person person;

  @override
  ConsumerState<_ChangeWorkflow> createState() => _ChangeWorkflowState();
}

class _ChangeWorkflowState extends ConsumerState<_ChangeWorkflow> {
  /// Null until the user picks; see Change stage.
  ({FollowWith? follow})? _picked;
  bool _saving = false;
  PeopleFailure? _failure;

  FollowWith? _follow(List<Workflow> workflows, DateTime today) {
    if (_picked case (:final follow)) return follow;
    final suggested =
        findWorkflow(workflows, widget.person.place?.workflowId) ??
        defaultFor(workflows, widget.person.stage);
    return suggested == null
        ? null
        : (workflow: suggested, firstDue: firstDueDefault(suggested, today));
  }

  Future<void> _save(FollowWith? follow) async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(peopleProvider(ref.read(accountProvider)?.email).notifier)
          .setWorkflow(widget.person, follow);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;
    final owner = ref.watch(accountProvider)?.email;
    final workflows = ref.watch(workflowsProvider(owner)).value ?? const [];
    final now = today();
    final follow = _follow(workflows, now);

    return FoloDialog(
      title: l10n.changeWorkflowTitle(firstName(widget.person)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(follow),
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
          FollowWithField(
            workflows: forStage(workflows, widget.person.stage),
            value: follow,
            today: now,
            onChanged: (next) => setState(() => _picked = (follow: next)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Run the checks**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all pass. The existing Change stage tests still find their titles and bodies: a person with no workflow gets no extra sentence.

- [ ] **Step 9: Commit**

```bash
git add lib test
git commit -m "feat(workflows): pick what follows in Change stage and Change workflow (#57)"
```

---

### Task 8: The NEXT STEP card, the ⋯ rows, and the wiring

**Files:**
- Modify: `lib/core/ui/action_item.dart`
- Create: `lib/features/contacts/presentation/next_step_section.dart`
- Modify: `lib/features/contacts/presentation/contact_details.dart`
- Modify: `lib/features/contacts/presentation/contact_page.dart`
- Modify: `lib/features/contacts/presentation/contacts_page.dart`
- Modify: `lib/features/contacts/presentation/contacts_preview.dart`
- Test: `test/features/contacts/presentation/next_step_card_test.dart`, `test/features/contacts/presentation/contact_details_test.dart`, `test/features/contacts/presentation/contacts_page_test.dart`

**Interfaces:**
- Consumes: `WorkflowProgress`, `OnStep`, `Done`, `Paused`, `progressOf`, `findWorkflow` (Task 3); `workflowsProvider` (Task 4); `PeopleController.completeStep`, `pause`, `resume` (Task 5); `dueLabel` and the `nextStep*`/`contact*` strings (Task 6); `showChangeWorkflow` (Task 7); `showChangeStage`, `firstName`, `peopleFailureCopy`, `today()` (existing / Task 2).
- Produces:
  - `ActionItem.title` (`String?`): shown instead of [name]; the avatar still reads [name].
  - `class NextStepCard({required Person person, required WorkflowProgress? progress, required DateTime today, required ValueChanged<OnStep> onTick, required VoidCallback onResume, required VoidCallback onNotNow, required VoidCallback onFollowWith, required VoidCallback onBecameCustomer, bool busy = false})` — pure.
  - `class NextStepSection({required Person person})` — reads the workflows, writes through `PeopleController`.
  - `Future<void> writePeople(BuildContext context, WidgetRef ref, Future<void> Function(PeopleController people) write)` in `contacts_page.dart`: runs a write, SnackBar on `PeopleFailure`.
  - `ContactDetails` gains `required VoidCallback onChangeWorkflow`, `required VoidCallback onPause`, `required VoidCallback onResume`, `String? workflowName`, `Widget? nextStep`.

- [ ] **Step 1: Write the failing card tests**

`test/features/contacts/presentation/next_step_card_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/next_step_section.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:folo/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../workflows/fake_workflow_repository.dart';

final _today = DateTime(2026, 9, 29);
final _samples = FakeWorkflowRepository.samples().first;
final _newCustomer = FakeWorkflowRepository.samples()[2];

Person _sarah({Stage stage = Stage.prospect}) => Person(
  id: 'p1',
  name: 'Sarah Martin',
  stage: stage,
  stageSince: DateTime.utc(2026, 3, 4),
);

class _Calls {
  final ticks = <OnStep>[];
  var resumes = 0;
  var notNows = 0;
  var followWiths = 0;
  var becameCustomers = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  WorkflowProgress? progress, {
  Person? person,
  bool busy = false,
}) async {
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: NextStepCard(
          person: person ?? _sarah(),
          progress: progress,
          today: _today,
          busy: busy,
          onTick: calls.ticks.add,
          onResume: () => calls.resumes++,
          onNotNow: () => calls.notNows++,
          onFollowWith: () => calls.followWiths++,
          onBecameCustomer: () => calls.becameCustomers++,
        ),
      ),
    ),
  );
  return calls;
}

void main() {
  OnStep onStep(int index, DateTime due) => OnStep(
    workflow: _samples,
    step: _samples.steps[index - 1],
    index: index,
    total: 5,
    due: due,
  );

  testWidgets('on a step: its name, where it is, when it is due', (
    tester,
  ) async {
    final calls = await _pump(tester, onStep(4, _today));

    expect(find.text('NEXT STEP'), findsOneWidget);
    expect(find.text('Samples · 4 of 5'), findsOneWidget);
    expect(find.text('Ask how the samples went'), findsOneWidget);
    expect(find.text('Due today'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark “Ask how the samples went” done'));

    expect(calls.ticks.single.step.id, 'samples-4');
  });

  testWidgets('late, with the step\'s note', (tester) async {
    final step = OnStep(
      workflow: _samples,
      step: const WorkflowStep(
        id: 'samples-1',
        position: 1,
        label: 'Send a first message',
        days: 0,
        note: 'Keep it short',
      ),
      index: 1,
      total: 5,
      due: _today.subtract(const Duration(days: 3)),
    );
    await _pump(tester, step);

    expect(find.text('3 days late — Keep it short'), findsOneWidget);
  });

  testWidgets('busy: no tick button, so a second tap can\'t skip a step', (
    tester,
  ) async {
    await _pump(tester, onStep(2, _today), busy: true);

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('a prospect done: how did it end, two ways on', (tester) async {
    final calls = await _pump(tester, Done(_samples));

    expect(find.text('SAMPLES — DONE'), findsOneWidget);
    expect(find.text('How did it end with Sarah?'), findsOneWidget);
    expect(
      find.text(
        'All 5 steps are done. Their notes and history stay whatever you pick.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Became a customer'));
    await tester.tap(find.text('Not now'));

    expect(calls.becameCustomers, 1);
    expect(calls.notNows, 1);
  });

  testWidgets('a customer done: follow with something else', (tester) async {
    final calls = await _pump(
      tester,
      Done(_newCustomer),
      person: _sarah(stage: Stage.customer),
    );

    expect(find.text('NEW CUSTOMER — DONE'), findsOneWidget);
    expect(find.text('All 4 steps are done with Sarah.'), findsOneWidget);
    await tester.tap(find.text('Follow with…'));

    expect(calls.followWiths, 1);
  });

  testWidgets('paused: since when, and Resume', (tester) async {
    final calls = await _pump(tester, Paused(DateTime(2026, 7, 12, 10)));

    expect(find.text('Paused since July 12'), findsOneWidget);
    await tester.tap(find.text('Resume'));

    expect(calls.resumes, 1);
  });

  testWidgets('no workflow: nothing planned, follow with', (tester) async {
    final calls = await _pump(tester, null);

    expect(find.text('Nothing planned'), findsOneWidget);
    await tester.tap(find.text('Follow with…'));

    expect(calls.followWiths, 1);
  });
}
```

The card reads `progress.step`, not the workflow's list, so a hand-built step with a note is enough.

- [ ] **Step 2: Write the failing details tests**

In `contact_details_test.dart`: `_Calls` gains `var workflowChanges = 0; var pauses = 0; var resumes = 0;`; `_pump` gains `String? workflowName` and passes `onChangeWorkflow: () => calls.workflowChanges++, onPause: () => calls.pauses++, onResume: () => calls.resumes++, workflowName: workflowName`. `_person` gains `DateTime? pausedAt` passed to `Person`. Append:

```dart
  testWidgets('⋯: Change workflow names the current one, then Pause', (
    tester,
  ) async {
    final calls = await _pump(tester, _person(), workflowName: 'Samples');

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Samples'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    await tester.tap(find.text('Pause — not now'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change workflow'));
    await tester.pumpAndSettle();

    expect(calls.pauses, 1);
    expect(calls.workflowChanges, 1);
  });

  testWidgets('mobile ⋯, paused: Resume instead of Pause', (tester) async {
    final calls = await _pump(
      tester,
      _person(pausedAt: DateTime.utc(2026, 7, 12)),
      size: const Size(390, 844),
    );

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Pause — not now'), findsNothing);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(calls.resumes, 1);
  });
```

- [ ] **Step 3: Write the failing page tests**

In `contacts_page_test.dart`: import `package:folo/core/ui/pick_day.dart`, `package:folo/features/contacts/presentation/next_step_section.dart` and `'../../workflows/fake_workflow_repository.dart'`; `openContacts` and `openMarie` gain `FakeWorkflowRepository? workflows`, passed to `pumpFolo(…, workflows: workflows)`. Add at the top level:

```dart
Person _marieOn(num position, {DateTime? pausedAt}) => Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: Stage.prospect,
  phone: '06 12 34 56 78',
  stageSince: DateTime.utc(2026, 3, 4),
  place: (workflowId: 'samples', atPosition: position, lastTick: today()),
  pausedAt: pausedAt,
);
```

and append to `main()`:

```dart
  const markFirst = 'Mark “Send a first message” done';
  const couldNotSave = "Couldn't save. Check your connection and try again.";

  testWidgets('ticking a step moves the card on and logs it', (tester) async {
    people.store['p1'] = _marieOn(1);
    await openMarie(tester);

    expect(find.text('Samples · 1 of 5'), findsOneWidget);
    await tester.tap(find.byTooltip(markFirst));
    await tester.pumpAndSettle();

    expect(find.text('Send the samples'), findsOneWidget);
    expect(find.text('Samples · 2 of 5'), findsOneWidget);
    expect(people.calls, contains('completeStep(p1, samples-1)'));
  });

  testWidgets('a tick in flight hides the button: one step, not two', (
    tester,
  ) async {
    people.store['p1'] = _marieOn(1);
    await openMarie(tester);
    people.gate = Completer<void>();

    await tester.tap(find.byTooltip(markFirst));
    await tester.pump();
    expect(find.byTooltip(markFirst), findsNothing);
    people.gate!.complete();
    people.gate = null;
    await tester.pumpAndSettle();

    expect(
      people.calls.where((call) => call.startsWith('completeStep')),
      hasLength(1),
    );
  });

  testWidgets('a failed tick says so and keeps the step', (tester) async {
    people.store['p1'] = _marieOn(1);
    await openMarie(tester);
    people.failWith = PeopleFailure.network;

    await tester.tap(find.byTooltip(markFirst));
    await tester.pumpAndSettle();

    expect(find.text(couldNotSave), findsOneWidget);
    expect(find.text('Send a first message'), findsOneWidget);
  });

  testWidgets('Pause from ⋯ shows the paused card; Resume brings it back', (
    tester,
  ) async {
    people.store['p1'] = _marieOn(2);
    await openMarie(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause — not now'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Paused since'), findsOneWidget);
    expect(people.store['p1']!.prospectStatus, ProspectStatus.notNow);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Send the samples'), findsOneWidget);
  });

  testWidgets('done: Became a customer opens the move to customers', (
    tester,
  ) async {
    people.store['p1'] = _marieOn(6);
    await openMarie(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Became a customer'));
    await tester.pumpAndSettle();

    expect(find.text('Marie is now a customer'), findsOneWidget);
  });

  testWidgets('Change workflow from ⋯ opens the sheet', (tester) async {
    people.store['p1'] = _marieOn(2);
    await openMarie(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change workflow'));
    await tester.pumpAndSettle();

    expect(find.text("Change Marie's workflow"), findsOneWidget);
  });

  testWidgets('workflows loading: a spinner in the card, the page works', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples())
      ..gate = Completer<void>();
    people.store['p1'] = _marieOn(1);
    await openContacts(tester, workflows: workflows);
    await tester.tap(find.text('Marie Dupont'));
    // The spinner never settles: pump the route transition by hand.
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
  });

  testWidgets('workflows failed: the card says so, Try again loads them', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples())
      ..failWith = PeopleFailure.network;
    people.store['p1'] = _marieOn(1);
    await openMarie(tester, workflows: workflows);

    expect(find.text("Couldn't load the workflows"), findsOneWidget);
    workflows.failWith = null;
    await tester.tap(
      find.descendant(
        of: find.byType(NextStepSection),
        matching: find.text('Try again'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Send a first message'), findsOneWidget);
  });
```

`openContacts` pumps with `pumpAndSettle`; with a gated workflow repository the Contacts list itself shows no spinner (it only listens to the workflows), so it settles.

- [ ] **Step 4: Run them to verify they fail**

Run: `flutter test test/features/contacts/presentation`
Expected: compile errors — `next_step_section.dart` missing, `ContactDetails` has no `onPause`.

- [ ] **Step 5: `ActionItem` takes a title**

In `action_item.dart`: add `this.title,` to the constructor after `required this.reason,`, the field

```dart
  /// The first line; defaults to [name]. The avatar always reads [name].
  final String? title;
```

and `Text(title ?? name, style: theme.textTheme.titleMedium),`.

- [ ] **Step 6: The shared write helper**

In `contacts_page.dart`, after `refreshPeople`:

```dart
/// Runs a write on the signed-in book; a failure is a SnackBar, and the book
/// stays as it was.
Future<void> writePeople(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(PeopleController people) write,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    await write(
      ref.read(peopleProvider(ref.read(accountProvider)?.email).notifier),
    );
  } on PeopleFailure catch (failure) {
    messenger.showSnackBar(
      SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
    );
  }
}
```

and in `ContactsPage.build`, after `final book = …`:

```dart
    // Starts loading the workflows (and seeds them the first time) as soon
    // as Contacts opens, so a person's card rarely waits.
    ref.listen(workflowsProvider(ref.watch(accountProvider)?.email), (_, _) {});
```

(import `package:folo/features/workflows/presentation/workflows_controller.dart`; `people_copy.dart` is already imported for `peopleFailureCopy` — add it if not).

- [ ] **Step 7: The card and its section**

`lib/features/contacts/presentation/next_step_section.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/ui/action_item.dart';
import 'package:folo/core/ui/pick_day.dart';
import 'package:folo/core/ui/section_header.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/contacts/domain/person.dart';
import 'package:folo/features/contacts/presentation/change_stage_sheet.dart';
import 'package:folo/features/contacts/presentation/change_workflow_sheet.dart';
import 'package:folo/features/contacts/presentation/contacts_page.dart';
import 'package:folo/features/contacts/presentation/people_controller.dart';
import 'package:folo/features/contacts/presentation/people_copy.dart';
import 'package:folo/features/workflows/domain/progress.dart';
import 'package:folo/features/workflows/domain/workflow.dart';
import 'package:folo/features/workflows/presentation/workflows_controller.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// `NEXT STEP` on a contact: what to do next in their workflow, or what comes
/// after it. Reads the workflows and saves through the book.
class NextStepSection extends ConsumerStatefulWidget {
  const NextStepSection({required this.person, super.key});

  final Person person;

  @override
  ConsumerState<NextStepSection> createState() => _NextStepSectionState();
}

class _NextStepSectionState extends ConsumerState<NextStepSection> {
  /// A write is in flight: its buttons are gone or disabled, so a second tap
  /// can't tick the next step too.
  bool _busy = false;

  Future<void> _run(Future<void> Function(PeopleController people) write) async {
    setState(() => _busy = true);
    await writePeople(context, ref, write);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final provider = workflowsProvider(ref.watch(accountProvider)?.email);
    final workflows = ref.watch(provider);
    final list = workflows.value;
    // Paused needs no workflow; everything else waits for them.
    if (list == null && person.pausedAt == null) {
      return _Waiting(
        failed: workflows.hasError,
        onRetry: () => ref.invalidate(provider),
      );
    }

    return NextStepCard(
      person: person,
      progress: progressOf(
        person,
        findWorkflow(list ?? const [], person.place?.workflowId),
      ),
      today: today(),
      busy: _busy,
      onTick: (step) =>
          unawaited(_run((people) => people.completeStep(person, step, today()))),
      onResume: () =>
          unawaited(_run((people) => people.resume(person, today()))),
      onNotNow: () => unawaited(_run((people) => people.pause(person))),
      onFollowWith: () => unawaited(showChangeWorkflow(context, person)),
      onBecameCustomer: () =>
          unawaited(showChangeStage(context, person, Stage.customer)),
    );
  }
}

/// The card while the workflows load, or once they failed to.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Panel(
      header: l10n.nextStepTitle,
      body: failed ? l10n.nextStepLoadFailed : null,
      actions: [
        if (failed)
          TextButton(onPressed: onRetry, child: Text(l10n.contactsRetry))
        else
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

/// The card itself, in each of its states. A pure view.
class NextStepCard extends StatelessWidget {
  const NextStepCard({
    required this.person,
    required this.progress,
    required this.today,
    required this.onTick,
    required this.onResume,
    required this.onNotNow,
    required this.onFollowWith,
    required this.onBecameCustomer,
    this.busy = false,
    super.key,
  });

  final Person person;

  /// Null: no workflow.
  final WorkflowProgress? progress;
  final DateTime today;
  final ValueChanged<OnStep> onTick;
  final VoidCallback onResume;

  /// "Not now" on a finished prospect: pauses them.
  final VoidCallback onNotNow;
  final VoidCallback onFollowWith;
  final VoidCallback onBecameCustomer;

  /// A write is in flight: no tick, buttons disabled.
  final bool busy;

  VoidCallback? _unlessBusy(VoidCallback action) => busy ? null : action;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = firstName(person);
    final followWith = OutlinedButton(
      onPressed: onFollowWith,
      child: Text(l10n.nextStepFollowWith),
    );

    return switch (progress) {
      final OnStep on => _step(l10n, on),
      Done(:final workflow) when person.stage == Stage.prospect => _Panel(
        header: l10n.nextStepDoneTitle(workflow.name),
        title: l10n.nextStepHowDidItEnd(name),
        body: l10n.nextStepAllDoneProspect(workflow.steps.length),
        actions: [
          FilledButton(
            onPressed: _unlessBusy(onBecameCustomer),
            child: Text(l10n.nextStepBecameCustomer),
          ),
          OutlinedButton(
            onPressed: _unlessBusy(onNotNow),
            child: Text(l10n.statusNotNow),
          ),
        ],
      ),
      Done(:final workflow) => _Panel(
        header: l10n.nextStepDoneTitle(workflow.name),
        body: l10n.nextStepAllDoneWith(workflow.steps.length, name),
        actions: [followWith],
      ),
      Paused(:final since) => _Panel(
        header: l10n.nextStepTitle,
        body: l10n.nextStepPausedSince(since.toLocal()),
        actions: [
          OutlinedButton(
            onPressed: _unlessBusy(onResume),
            child: Text(l10n.contactResume),
          ),
        ],
      ),
      null => _Panel(
        header: l10n.nextStepTitle,
        body: l10n.nextStepNothingPlanned,
        actions: [followWith],
      ),
    };
  }

  Widget _step(AppLocalizations l10n, OnStep on) {
    final due = dueLabel(l10n, on.due, today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.nextStepTitle,
          actionLabel: l10n.nextStepProgress(
            on.workflow.name,
            on.index,
            on.total,
          ),
        ),
        ActionItem(
          name: person.name,
          title: on.step.label,
          reason: switch (on.step.note) {
            final note? => l10n.nextStepWithNote(due, note),
            null => due,
          },
          onResolve: busy ? null : () => onTick(on),
          resolveLabel: l10n.nextStepMarkDone(on.step.label),
        ),
      ],
    );
  }
}

/// A header, then a card with an optional title, a line, and its buttons.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.header,
    required this.actions,
    this.title,
    this.body,
  });

  final String header;
  final String? title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = title;
    final text = body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: header),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                if (heading != null)
                  Text(heading, style: theme.textTheme.titleMedium),
                if (text != null)
                  Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: FoloColors.of(context).textMuted,
                    ),
                  ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```


- [ ] **Step 8: `ContactDetails`**

In `contact_details.dart`:

- `typedef _Action = ({String label, IconData icon, VoidCallback onTap, String? trailing});` — the existing records gain `trailing: null`.
- Constructor: `required this.onChangeWorkflow, required this.onPause, required this.onResume,` after `onMove`, and `this.workflowName, this.nextStep,` before `this.history`. Fields:

```dart
  final VoidCallback onChangeWorkflow;
  final VoidCallback onPause;
  final VoidCallback onResume;

  /// The current workflow's name, shown beside Change workflow in ⋯.
  final String? workflowName;

  /// The `NEXT STEP` section, between where it stands and what you know.
  final Widget? nextStep;
```

- Delete the doc line "`NEXT STEP` is not here yet: it arrives whole with #57.", and the class comment reads "One person: who they are, how to reach them, where it stands, what's next, what you know."
- In `_actions`, after the Move rows:

```dart
    (
      label: l10n.contactChangeWorkflow,
      icon: Icons.alt_route_rounded,
      onTap: onChangeWorkflow,
      trailing: workflowName,
    ),
    if (person.pausedAt == null)
      (
        label: l10n.contactPause,
        icon: Icons.pause_circle_outline_rounded,
        onTap: onPause,
        trailing: null,
      )
    else
      (
        label: l10n.contactResume,
        icon: Icons.play_circle_outline_rounded,
        onTap: onResume,
        trailing: null,
      ),
```

- The popup item child becomes

```dart
          PopupMenuItem(
            value: action.onTap,
            child: Row(
              spacing: AppSpacing.md,
              children: [
                Expanded(child: Text(action.label)),
                if (action.trailing case final trailing?)
                  Text(
                    trailing,
                    style: TextStyle(color: FoloColors.of(context).textMuted),
                  ),
              ],
            ),
          ),
```

  and `_MoreSheet`'s `tile` gets `trailing: switch (action.trailing) { final text? => Text(text, style: TextStyle(color: FoloColors.of(context).textMuted)), null => null },` (import `app_colors.dart` is already there).
- In `build`, after the WHERE IT STANDS block and before `const SizedBox(height: AppSpacing.lg), SectionHeader(title: l10n.contactSectionWhatYouKnow …`:

```dart
          if (nextStep case final nextStep?) ...[
            const SizedBox(height: AppSpacing.lg),
            nextStep,
          ],
```

- [ ] **Step 9: Wire the pane**

In `ContactPane.build` (`contact_page.dart`), imports `package:folo/core/ui/pick_day.dart`, `package:folo/features/contacts/presentation/change_workflow_sheet.dart`, `package:folo/features/contacts/presentation/next_step_section.dart`, `package:folo/features/workflows/domain/workflow.dart`, `package:folo/features/workflows/presentation/workflows_controller.dart`:

```dart
    final owner = ref.watch(accountProvider)?.email;
    final workflows = workflowsProvider(owner);
    final workflowName = findWorkflow(
      ref.watch(workflows).value ?? const [],
      person.place?.workflowId,
    )?.name;
```

(after the missing-person check; `book` above already uses the same email) and the `ContactDetails` call gains

```dart
      onChangeWorkflow: () => unawaited(showChangeWorkflow(context, person)),
      onPause: () => unawaited(
        writePeople(context, ref, (people) => people.pause(person)),
      ),
      onResume: () => unawaited(
        writePeople(context, ref, (people) => people.resume(person, today())),
      ),
      workflowName: workflowName,
      nextStep: NextStepSection(key: ValueKey(person.id), person: person),
```

`onRefresh` also reloads the workflows: add `ref.invalidate(workflows);` next to the history invalidation. `_setStatus` becomes a call to `writePeople(context, ref, (people) => people.setStatus(person, status))` — same behaviour, one copy of the SnackBar code.

- [ ] **Step 10: The preview shows the card**

In `contacts_preview.dart`, imports `package:folo/features/contacts/presentation/next_step_section.dart`, `package:folo/features/workflows/domain/progress.dart` and `package:folo/features/workflows/domain/workflow.dart`:

```dart
final _samples = Workflow(
  id: 'w1',
  stage: Stage.prospect,
  name: 'Samples',
  isDefault: true,
  steps: [
    for (final (index, (label, days)) in [
      ('Send a first message', 0),
      ('Send the samples', 1),
      ('Samples arrived', 4),
      ('Ask how the samples went', 3),
      ('Follow up', 7),
    ].indexed)
      WorkflowStep(
        id: 's${index + 1}',
        position: index + 1,
        label: label,
        days: days,
      ),
  ],
);

// A fixed day, so the golden never changes with the calendar.
final _previewToday = DateTime(2026, 9, 29);
```

and `_details()` passes

```dart
  onChangeWorkflow: () {},
  onPause: () {},
  onResume: () {},
  workflowName: _samples.name,
  nextStep: NextStepCard(
    person: _sample.first,
    progress: OnStep(
      workflow: _samples,
      step: _samples.steps[3],
      index: 4,
      total: 5,
      due: _previewToday,
    ),
    today: _previewToday,
    onTick: (_) {},
    onResume: () {},
    onNotNow: () {},
    onFollowWith: () {},
    onBecameCustomer: () {},
  ),
```

- [ ] **Step 11: Run the checks**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!"; all pass except the goldens `contact_mobile_light`, `contact_mobile_dark` and `contacts_desktop_light`, which now show the card. Do not regenerate them locally.

- [ ] **Step 12: Commit, then regenerate the goldens through CI**

```bash
git add lib test
git commit -m "feat(contacts): the next step card, pause and change workflow in ⋯ (#57)"
git push -u origin feature/57-workflows
gh workflow run CI --ref feature/57-workflows -f update-goldens=true
```

Wait for the run (`gh run watch`), download the artifact (`gh run download <run-id> -n goldens -D test/goldens`), check the three images show the card, then:

```bash
git add test/goldens
git commit -m "test: goldens with the next step card (#57)"
```

Pushing the feature branch is fine (it is not shared); anything that merges waits for the user.

---

### Task 9: The card states in the screens doc, then the PR

**Files:**
- Modify: `docs/design/screens.md` (§3 Contact detail)

**Interfaces:**
- Consumes: everything above, merged on the branch; goldens from Task 8 Step 12.
- Produces: the PR closing #57.

- [ ] **Step 1: Document the card**

In `docs/design/screens.md`, after the §3 paragraph ending "…the name is already the largest thing on the screen (principle #2).", add:

```markdown
**`NEXT STEP`** sits between `WHERE IT STANDS` and `WHAT YOU KNOW`, on mobile and
in the desktop pane. It follows the person's workflow, one step at a time:

| State | Header | Card |
| --- | --- | --- |
| On a step | `NEXT STEP` · "Samples · 3 of 5" | The step as title; "Due today" / "Due in 3 days" / "2 days late", then the step's note; a round tick |
| Done, prospect | `SAMPLES — DONE` | "How did it end with Sarah?" — `Became a customer`, `Not now` (pauses) |
| Done, customer or team | `NEW CUSTOMER — DONE` | "All 4 steps are done with Claire." — `Follow with…` |
| Paused | `NEXT STEP` | "Paused since July 12" — `Resume` |
| No workflow | `NEXT STEP` | "Nothing planned" — `Follow with…` |
| Loading / failed | `NEXT STEP` | A small spinner / "Couldn't load the workflows" — `Try again` |

A tick completes the step today and waits for the server; on failure a SnackBar,
and the card stays. There are no progress bars or streaks: the count "3 of 5"
is where you are, not a score.

The ⋯ menu adds `Change workflow` (the current one's name trailing) and
`Pause — not now`, or `Resume` while paused. Change stage and Change workflow
share the FOLLOW WITH block: the stage's workflows, "Nothing for now", and the
first step's day.
```

- [ ] **Step 2: Commit**

```bash
git add docs/design/screens.md
git commit -m "docs: the next step card in the screens doc (#57)"
```

- [ ] **Step 3: The whole suite, once more**

Run: `dart format --set-exit-if-changed . && flutter analyze && flutter test`
Expected: no format changes, "No issues found!", all tests pass (goldens included, from CI). Run `supabase test db` if the local stack is up; otherwise CI runs the pgTAP tests.

- [ ] **Step 4: Open the PR — only once the user says so**

Ask the user before pushing for review. Then:

```bash
git push
gh pr create --base main --title "feat: workflows — next step, pause, follow with (#57)" --body "$(cat <<'BODY'
## Ticket

Closes #57

## What & why

Each account gets five workflows (seeded once, EN or FR). A person follows one:
the NEXT STEP card on their page shows the step, when it's due, and ticks it.
Pause / Resume and Change workflow sit in ⋯; Change stage picks what follows.
Step ticks land in the history as `Step` entries.

After the merge, run `supabase db push` from your own terminal (VPN off): until
then the hosted app fails on the new columns.

## Screenshots

Goldens: `contact_mobile_light`, `contact_mobile_dark`, `contacts_desktop_light`.

## Checklist

- [x] `dart format .`, `flutter analyze`, `flutter test` all pass locally
- [x] Theme values come from `colorScheme` / `AppSpacing` / `AppRadii` — nothing hard-coded
- [x] No new dependency, or the reason is in the `pubspec.yaml` comment next to it
- [x] Goldens regenerated on Linux if they changed (see `.github/workflows/ci.yaml`)
- [x] Linked issue exists on the board and the branch is named `<type>/<issue>-<slug>`
BODY
)"
```

- [ ] **Step 5: Figma, done by the controller (not a subagent)**

In `102:2196`: "Her notes" becomes "Their notes". On every NEXT STEP card in the Contacts page (`99:1295`, `99:1429`, `97:1491`), the second line becomes the due line ("Due today", "Due in 3 days"). Screenshot once after.

